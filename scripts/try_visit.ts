// Cek T-010: Edge Function `visit` sungguhan (extract → confirm), 400, dan 403.
// Jalankan dari root: deno run -A scripts/try_visit.ts
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { DOMAIN_KEYS } from "../supabase/functions/_shared/rubric.ts";
// Bandingkan isi, bukan teks: jsonb di PostgreSQL tidak menyimpan urutan kunci objek.
import { equal } from "jsr:@std/assert@1/equal";

const env = Object.fromEntries(
  Deno.readTextFileSync(".env.local").split("\n")
    .filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, "")]),
);
const opts = { auth: { persistSession: false } };
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, opts);
const SRI = "e0000000-0000-0000-0000-000000000001";
const RELAWAN1 = "c0000000-0000-0000-0000-000000000001";

let failed = 0;
function check(name: string, ok: boolean, detail = "") {
  console.log(`${ok ? "LULUS" : "GAGAL"}  ${name}${ok || !detail ? "" : `  (${detail})`}`);
  if (!ok) failed++;
}

async function login(email: string): Promise<{ c: SupabaseClient; token: string }> {
  const c = createClient(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY, opts);
  const { data, error } = await c.auth.signInWithPassword({ email, password: "demo1234" });
  if (error) throw new Error(`login ${email}: ${error.message}`);
  return { c, token: data.session.access_token };
}

/** Memanggil fungsi langsung lewat fetch supaya status HTTP terbaca jelas. */
async function call(token: string, body: unknown) {
  const res = await fetch(`${env.SUPABASE_URL}/functions/v1/visit`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, apikey: env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

const r1 = await login("relawan1@demo.id");
const r2 = await login("relawan2@demo.id");

const { data: before } = await admin.from("elders").select("status, status_reason").eq("id", SRI).single();
const { data: visit, error: insErr } = await r1.c.from("visits").insert({
  elder_id: SRI,
  volunteer_id: RELAWAN1,
  answers: {
    makan: "Bu Sri makan siang setengah piring saja, katanya kurang selera.",
    obat: "Obat pagi sudah diminum, saya lihat bungkusnya.",
    gerak: "Kemarin sore Ibu Sri jatuh di kamar mandi, lututnya memar.",
    harian: "Masih mandi dan berpakaian sendiri.",
    ingatan: "Ngobrol nyambung, masih ingat nama cucunya.",
    hati: "Agak murung karena lututnya sakit.",
    lain: "Tetangga di Jl. Cik Di Tiro membantu belanja.",
  },
}).select("id").single();
if (insErr) throw insErr;

try {
  // 400: body tidak valid.
  for (const [name, body] of [
    ["action tidak dikenal", { action: "hapus", visit_id: visit.id }],
    ["visit_id bukan uuid", { action: "extract", visit_id: "123" }],
    ["confirm tanpa final_result", { action: "confirm", visit_id: visit.id }],
    ["confirm dengan level 5", {
      action: "confirm", visit_id: visit.id,
      final_result: { ...Object.fromEntries(DOMAIN_KEYS.map((k) => [k, { level: 5, evidence: "" }])), red_flags: [] },
    }],
  ] as const) {
    const { status } = await call(r1.token, body);
    check(`400 untuk ${name}`, status === 400, `status ${status}`);
  }

  // 403: relawan 2 bukan pasangan Ibu Sri.
  {
    const { status } = await call(r2.token, { action: "extract", visit_id: visit.id });
    check("403 untuk relawan 2 (extract)", status === 403, `status ${status}`);
    const { status: s2 } = await call(r2.token, { action: "confirm", visit_id: visit.id, final_result: {} });
    check("403/400 untuk relawan 2 (confirm) tidak mengubah apa pun", s2 === 403 || s2 === 400, `status ${s2}`);
  }
  {
    const { status } = await call("bukan-token", { action: "extract", visit_id: visit.id });
    check("401 tanpa login yang sah", status === 401, `status ${status}`);
  }

  // extract
  const t0 = performance.now();
  const { status, json } = await call(r1.token, { action: "extract", visit_id: visit.id });
  const secs = (performance.now() - t0) / 1000;
  const ai = json?.ai_result;
  check(`extract 200 dalam < 10 detik (${secs.toFixed(1)} dtk)`, status === 200 && secs < 10, `status ${status} ${JSON.stringify(json)}`);
  check("extract mengembalikan 7 domain", !!ai && DOMAIN_KEYS.every((k) => k in ai) && DOMAIN_KEYS.length === 7, JSON.stringify(ai));
  check("Gemini mendeteksi tanda bahaya jatuh", ai?.red_flags?.some((f: { flag: string }) => f.flag === "jatuh"), JSON.stringify(ai?.red_flags));
  check("bukti tidak memuat nama atau alamat lansia", !/sri|cik di tiro/i.test(JSON.stringify(ai)), JSON.stringify(ai));
  const { data: saved } = await admin.from("visits").select("ai_result").eq("id", visit.id).single();
  check("ai_result tersimpan di visits", equal(saved?.ai_result, ai));
  console.log("  ai_result:", JSON.stringify(ai));

  // confirm: relawan menyetujui hasil AI apa adanya.
  if (ai) {
    const { status: cs, json: cj } = await call(r1.token, { action: "confirm", visit_id: visit.id, final_result: ai });
    check("confirm 200", cs === 200, `status ${cs} ${JSON.stringify(cj)}`);
    const { data: v } = await admin.from("visits").select("final_result, confirmed_at").eq("id", visit.id).single();
    check("final_result dan confirmed_at tersimpan", !!v?.confirmed_at && equal(v?.final_result, ai));
    const { data: e } = await admin.from("elders").select("status, status_reason").eq("id", SRI).single();
    check("confirm mengubah elders.status menjadi segera_dikabari", e?.status === "segera_dikabari", JSON.stringify(e));
    check("status_reason berisi kutipan dan pernyataan bukan diagnosis",
      !!e?.status_reason?.includes("bukan diagnosis") && !!e?.status_reason?.toLowerCase().includes("jatuh"), e?.status_reason);
    console.log("  status_reason:", e?.status_reason);
  }
} finally {
  await admin.from("visits").delete().eq("id", visit.id);
  await admin.from("elders").update(before!).eq("id", SRI);
}

console.log(failed ? `\n${failed} cek gagal` : "\nSemua cek lulus");
Deno.exit(failed ? 1 : 0);
