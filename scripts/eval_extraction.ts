// T-024: mengukur akurasi ekstraksi cerita → kategori (PRD Metrik Sukses) dengan data/eval/stories.jsonl.
// Memakai extractVisit + generateJson yang sama persis dengan Edge Function `visit`; prompt tidak diubah di sini.
//
//   deno run -A scripts/eval_extraction.ts               evaluasi sungguhan (butuh GEMINI_EVAL_API_KEY)
//   deno run -A scripts/eval_extraction.ts --self-check  tanpa Gemini: jawaban = label, hasil harus 100%
//
// Kuota: sengaja HANYA memakai GEMINI_EVAL_API_KEY (API key di proyek Google terpisah), supaya evaluasi
// tidak menghabiskan kuota harian GEMINI_API_KEY yang dipakai aplikasi saat demo.
import { type Answers, extractVisit } from "../supabase/functions/_shared/extract.ts";
import { generateJson } from "../supabase/functions/_shared/gemini.ts";
import { DOMAIN_KEYS, DOMAINS, type DomainKey, type Level, RED_FLAGS, type RedFlag } from "../supabase/functions/_shared/rubric.ts";
import type { VisitResult } from "../supabase/functions/_shared/status.ts";

type Story = {
  id: string;
  bahasa: string;
  answers: Answers;
  expected: Record<DomainKey, Level>;
  expected_red_flags: RedFlag[];
};

const DELAY_MS = 5_000; // ±12 panggilan/menit, di bawah batas per menit free tier
const ROOT = new URL("../", import.meta.url);
const selfCheck = Deno.args.includes("--self-check");

const stories: Story[] = (await Deno.readTextFile(new URL("data/eval/stories.jsonl", ROOT)))
  .split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));

const env = Object.fromEntries(
  (await Deno.readTextFile(new URL(".env.local", ROOT))).split("\n").filter((l) => l.includes("="))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim()]),
);
const apiKey = env.GEMINI_EVAL_API_KEY;
const model = env.GEMINI_EVAL_MODEL || env.GEMINI_MODEL;
if (!selfCheck && !apiKey) {
  console.error("GEMINI_EVAL_API_KEY belum diisi di .env.local (sengaja tidak memakai key demo).");
  Deno.exit(1);
}

// Nama/alamat contoh untuk stripPII: dataset tidak memuat nama lansia sungguhan.
const ELDER = { name: "Ibu Contoh Evaluasi", address: "Jl. Contoh No. 1" };
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Satu panggilan Gemini. 429 per menit/503 → tunggu lalu ulangi. 429 harian → lempar DailyQuota. */
class DailyQuota extends Error {}
async function generate(request: unknown): Promise<unknown> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await generateJson(request, fetch, { apiKey, model });
    } catch (e) {
      const msg = String(e);
      if (msg.includes("PerDay")) throw new DailyQuota(msg);
      const retryable = msg.includes("(429)") || msg.includes("(503)") || msg.includes("TimeoutError");
      if (!retryable || attempt >= 4) throw e;
      const wait = Number(msg.match(/"retryDelay":\s*"(\d+)s"/)?.[1] ?? 20) * 1000;
      console.log(`  …${msg.match(/\((\d{3})\)/)?.[1] ?? "timeout"}, tunggu ${wait / 1000} detik lalu ulangi (${attempt}/3)`);
      await sleep(wait);
    }
  }
}

/** Hasil palsu untuk --self-check: persis sama dengan label. */
function asResult(s: Story): VisitResult {
  const r = {} as VisitResult;
  for (const k of DOMAIN_KEYS) r[k] = { level: s.expected[k], evidence: "" };
  r.red_flags = s.expected_red_flags.map((flag) => ({ flag, evidence: "" }));
  return r;
}

const perDomain = Object.fromEntries(DOMAIN_KEYS.map((k) => [k, { ok: 0, total: 0 }])) as Record<DomainKey, { ok: number; total: number }>;
let flagExpected = 0, flagHit = 0, falseAlarm = 0, done = 0;
const wrong: string[] = [];
const errors: string[] = [];
const label = (k: DomainKey, l: Level) => (l === null ? "tidak disebut" : DOMAINS[k].labels[l]);

console.log(`${selfCheck ? "SELF-CHECK (tanpa Gemini)" : `Model ${model}`} · ${stories.length} cerita\n`);
for (const [i, s] of stories.entries()) {
  let got: VisitResult;
  try {
    got = selfCheck ? asResult(s) : await extractVisit(s.answers, ELDER, generate);
  } catch (e) {
    if (e instanceof DailyQuota) {
      console.log(`\nKuota harian habis di ${s.id}; berhenti. Hasil di bawah hanya untuk ${done} cerita.`);
      break;
    }
    errors.push(`${s.id}: ${String(e).slice(0, 120)}`);
    continue;
  }
  done++;
  const mistakes: string[] = [];
  for (const k of DOMAIN_KEYS) {
    const want = s.expected[k], have = got[k]?.level ?? null;
    perDomain[k].total++;
    if (want === have) perDomain[k].ok++;
    else mistakes.push(`${DOMAINS[k].name}: label "${label(k, want)}", AI "${label(k, have)}"`);
  }
  const gotFlags = new Set(got.red_flags.map((f) => f.flag));
  for (const f of s.expected_red_flags) {
    flagExpected++;
    if (gotFlags.has(f)) flagHit++;
    else mistakes.push(`tanda bahaya terlewat: ${RED_FLAGS[f]}`);
  }
  for (const f of gotFlags) {
    if (!s.expected_red_flags.includes(f)) {
      falseAlarm++;
      mistakes.push(`alarm palsu: ${RED_FLAGS[f]}`);
    }
  }
  if (mistakes.length) wrong.push(`${s.id} (${s.bahasa}): ${mistakes.join("; ")}`);
  console.log(`${s.id} ${mistakes.length ? `✗ ${mistakes.length} selisih` : "✓"}`);
  if (!selfCheck && i < stories.length - 1) await sleep(DELAY_MS);
}

const pct = (a: number, b: number) => (b ? `${((100 * a) / b).toFixed(1)}%` : "-");
const okAll = DOMAIN_KEYS.reduce((n, k) => n + perDomain[k].ok, 0);
const totalAll = DOMAIN_KEYS.reduce((n, k) => n + perDomain[k].total, 0);

console.log(`\n== Hasil (${new Date().toLocaleDateString("sv-SE", { timeZone: "Asia/Jakarta" })}, ${selfCheck ? "self-check" : model}, ${done}/${stories.length} cerita) ==`);
console.log("Akurasi per domain:");
for (const k of DOMAIN_KEYS) {
  console.log(`  ${DOMAINS[k].name.padEnd(20)} ${pct(perDomain[k].ok, perDomain[k].total).padStart(6)}  (${perDomain[k].ok}/${perDomain[k].total})`);
}
console.log(`Akurasi keseluruhan:    ${pct(okAll, totalAll)}  (${okAll}/${totalAll} kategori)`);
console.log(`Recall tanda bahaya:    ${pct(flagHit, flagExpected)}  (${flagHit}/${flagExpected}), alarm palsu: ${falseAlarm}`);
if (wrong.length) console.log(`\nCerita dengan selisih (${wrong.length}):\n  ${wrong.join("\n  ")}`);
if (errors.length) console.log(`\nGagal dipanggil (${errors.length}):\n  ${errors.join("\n  ")}`);
