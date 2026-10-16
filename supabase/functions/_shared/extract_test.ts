import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  type Answers,
  buildRequest,
  extractVisit,
  stripPII,
  validateResult,
} from "./extract.ts";
import { generateJson } from "./gemini.ts";

const elder = {
  name: "Sri Wahyuni",
  address: "Jl. Kaliurang km 5, Ngaglik, Sleman",
};

const answers: Answers = {
  makan: "Makannya tinggal setengah piring, katanya tidak selera.",
  obat: "Obat diminum teratur pagi dan malam.",
  gerak: "Ibu Sri terpeleset di kamar mandi kemarin sore.",
  harian: "Mandi masih sendiri.",
  ingatan: "",
  hati: "Bu Wahyuni banyak diam hari ini.",
  lain: "Tetangga di Ngaglik bilang rumahnya di Jl. Kaliurang km 5 sepi.",
};

// fetch palsu: menyimpan body request dan membalas seperti Gemini.
function fakeFetch(reply: unknown, seen: string[]) {
  return (_url: string | URL | Request, init?: RequestInit) => {
    seen.push(String(init?.body));
    const body = {
      candidates: [{ content: { parts: [{ text: JSON.stringify(reply) }] } }],
    };
    return Promise.resolve(new Response(JSON.stringify(body)));
  };
}

Deno.test("stripPII membuang nama (per kata) dan alamat, tanpa peka huruf besar", () => {
  const out = stripPII(
    "ibu SRI tinggal di Jl. Kaliurang km 5, dekat Ngaglik. Bu Wahyuni senang.",
    elder,
  );
  for (const word of ["sri", "wahyuni", "kaliurang", "ngaglik"]) {
    assert(!out.toLowerCase().includes(word), `${word} masih ada: ${out}`);
  }
  assert(out.includes("senang"));
});

Deno.test("nama dan alamat lansia tidak ada di body request ke Gemini", async () => {
  const seen: string[] = [];
  await extractVisit(
    answers,
    elder,
    (req) =>
      generateJson(req, fakeFetch({}, seen), { apiKey: "k", model: "m" }),
  );
  assertEquals(seen.length, 1);
  const body = seen[0].toLowerCase();
  for (const word of ["sri", "wahyuni", "kaliurang", "ngaglik", "sleman"]) {
    assert(!body.includes(word), `${word} bocor ke Gemini`);
  }
  assert(body.includes("terpeleset di kamar mandi"));
  assert(body.includes("responseschema"));
});

Deno.test("buildRequest: rubrik di system instruction, cerita dibungkus tag", () => {
  const req = buildRequest(answers);
  assert(JSON.stringify(req.systemInstruction).includes("Tidak makan"));
  const text = req.contents[0].parts[0].text;
  assert(text.startsWith("<cerita>") && text.trimEnd().endsWith("</cerita>"));
});

Deno.test("kalimat bukti yang tidak ada di cerita membuat domain null", () => {
  const r = validateResult(
    {
      makan: { level: 1, evidence: "makannya   TINGGAL setengah piring" }, // beda spasi & huruf: tetap cocok
      obat: { level: 2, evidence: "Obat sering lupa diminum." }, // karangan Gemini
      red_flags: [
        { flag: "jatuh", evidence: "terpeleset di kamar mandi" },
        { flag: "sesak_nyeri_dada", evidence: "mengeluh dadanya sesak" }, // karangan
      ],
    },
    answers,
  );
  assertEquals(r.makan.level, 1);
  assertEquals(r.obat, { level: null, evidence: "" });
  assertEquals(r.red_flags.map((f) => f.flag), ["jatuh"]);
});

Deno.test("level di luar 0–3 dibuang", () => {
  const ev = "Mandi masih sendiri.";
  const r = validateResult(
    {
      harian: { level: 5, evidence: ev },
      makan: { level: -1, evidence: ev },
      obat: { level: 1.5, evidence: ev },
      hati: { level: "2", evidence: ev },
      gerak: { level: 0, evidence: ev },
      red_flags: [{ flag: "bukan_tanda", evidence: ev }],
    },
    answers,
  );
  assertEquals(r.harian.level, null);
  assertEquals(r.makan.level, null);
  assertEquals(r.obat.level, null);
  assertEquals(r.hati.level, null);
  assertEquals(r.gerak.level, 0);
  assertEquals(r.red_flags, []);
});

Deno.test("domain yang tidak disebut menjadi null; keluaran rusak tidak membuat crash", () => {
  const r = validateResult(
    { makan: { level: 1, evidence: "tidak selera" } },
    answers,
  );
  assertEquals(r.makan.level, 1);
  for (
    const key of ["obat", "gerak", "harian", "ingatan", "hati", "umum"] as const
  ) {
    assertEquals(r[key], { level: null, evidence: "" });
  }
  assertEquals(validateResult("bukan json", answers).makan.level, null);
  assertEquals(validateResult(null, answers).red_flags, []);
});

Deno.test("generateJson melempar error bila Gemini membalas gagal", async () => {
  const failing = () => Promise.resolve(new Response("quota", { status: 429 }));
  let err = "";
  try {
    await generateJson({}, failing, { apiKey: "k", model: "m" });
  } catch (e) {
    err = String(e);
  }
  assert(err.includes("429"));
});
