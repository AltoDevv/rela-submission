import { assert, assertEquals } from "jsr:@std/assert@1";
import { DOMAIN_KEYS, type DomainKey, type Level } from "./rubric.ts";
import { computeStatus, type RedFlagHit, type Visit } from "./status.ts";

// Membuat kunjungan: domain yang tidak diisi bernilai level 0.
function visit(
  levels: Partial<Record<DomainKey, Level>> = {},
  red_flags: RedFlagHit[] = [],
): Visit {
  const result = {} as Visit["final_result"];
  for (const key of DOMAIN_KEYS) {
    const level = key in levels ? levels[key]! : 0;
    result[key] = {
      level,
      evidence: level === null ? "" : `bukti ${key} ${level}`,
    };
  }
  result.red_flags = red_flags;
  return { final_result: result };
}

const baik = () => visit();

Deno.test("semua baik → stabil tanpa alasan", () => {
  const r = computeStatus([baik(), baik(), baik(), baik()]);
  assertEquals(r.status, "stabil");
  assertEquals(r.reasons, []);
});

Deno.test("tanda bahaya di kunjungan terbaru → segera_dikabari dengan kutipan", () => {
  const r = computeStatus([
    baik(),
    visit({}, [{ flag: "jatuh", evidence: "Ibu terpeleset di kamar mandi" }]),
  ]);
  assertEquals(r.status, "segera_dikabari");
  assert(r.reasons[0].quote === "Ibu terpeleset di kamar mandi");
  assert(r.advice.length > 0);
  assert(r.disclaimer.includes("bukan diagnosis"));
});

Deno.test("tanda bahaya di kunjungan lama tidak memicu", () => {
  const r = computeStatus([
    visit({}, [{ flag: "jatuh", evidence: "jatuh minggu lalu" }]),
    baik(),
    baik(),
    baik(),
  ]);
  assertEquals(r.status, "stabil");
});

Deno.test("turun ≥2 level dari baseline → perlu_perhatian", () => {
  const r = computeStatus([baik(), baik(), baik(), visit({ makan: 2 })]);
  assertEquals(r.status, "perlu_perhatian");
  assertEquals(r.reasons[0].domain, "makan");
  assertEquals(r.reasons[0].quote, "bukti makan 2");
  assert(r.disclaimer.includes("bukan diagnosis"));
});

Deno.test("turun 1 level saja tidak memicu", () => {
  const r = computeStatus([baik(), baik(), baik(), visit({ hati: 1 })]);
  assertEquals(r.status, "stabil");
});

Deno.test("memburuk 3 kunjungan berturut-turut → perlu_perhatian", () => {
  // Baseline gerak = 1. Turun hanya 1 dari baseline, tapi tren 0 → 1 → 2.
  const r = computeStatus([
    visit({ gerak: 1 }),
    visit({ gerak: 1 }),
    visit({ gerak: 1 }),
    visit({ gerak: 0 }),
    visit({ gerak: 1 }),
    visit({ gerak: 2 }),
  ]);
  assertEquals(r.status, "perlu_perhatian");
  assertEquals(r.reasons[0].domain, "gerak");
});

Deno.test("obat terlewat 2 dari 3 kunjungan terakhir → perlu_perhatian", () => {
  const r = computeStatus([
    baik(),
    baik(),
    baik(),
    visit({ obat: 1 }),
    baik(),
    visit({ obat: 1 }),
  ]);
  assertEquals(r.status, "perlu_perhatian");
  assertEquals(r.reasons[0].domain, "obat");
});

Deno.test("obat terlewat hanya 1 dari 3 tidak memicu", () => {
  const r = computeStatus([
    baik(),
    baik(),
    baik(),
    baik(),
    baik(),
    visit({ obat: 1 }),
  ]);
  assertEquals(r.status, "stabil");
});

Deno.test("kemandirian harian hilang (lebih buruk dari baseline) → perlu_perhatian", () => {
  const r = computeStatus([baik(), baik(), baik(), visit({ harian: 1 })]);
  assertEquals(r.status, "perlu_perhatian");
  assertEquals(r.reasons[0].domain, "harian");
});

Deno.test("baseline buruk tidak memicu", () => {
  // Lansia dengan demensia: daya ingat memang 'Bingung' sejak awal.
  const r = computeStatus([
    visit({ ingatan: 2, obat: 1 }),
    visit({ ingatan: 2, obat: 1 }),
    visit({ ingatan: 2, obat: 1 }),
    visit({ ingatan: 2, obat: 1 }),
    visit({ ingatan: 2, obat: 1 }),
  ]);
  assertEquals(r.status, "stabil");
});

Deno.test("domain null dilewati, tidak dianggap baik maupun buruk", () => {
  // Baseline makan null semua → tidak ada baseline, level 3 belakangan tidak dibandingkan.
  const r1 = computeStatus([
    visit({ makan: null }),
    visit({ makan: null }),
    visit({ makan: null }),
    visit({ makan: 3 }),
  ]);
  assertEquals(r1.status, "stabil");
  // Kunjungan terbaru tidak menyebut harian → tidak memicu meski sebelumnya memburuk.
  const r2 = computeStatus([baik(), baik(), baik(), visit({ harian: null })]);
  assertEquals(r2.status, "stabil");
});

Deno.test("kurang dari 3 kunjungan: baseline belum sah, hanya tanda bahaya", () => {
  const r = computeStatus([baik(), visit({ makan: 3, harian: 3 })]);
  assertEquals(r.status, "stabil");
  assertEquals(computeStatus([]).status, "stabil");
});

// ---- T-009: data demo Ibu Sri (sama dengan supabase/seeds/03_visits_ibu_sri.sql) ----
import ibuSri from "../../seeds/ibu_sri.json" with { type: "json" };

type DemoVisit = { answers: Record<string, string>; final_result: Visit["final_result"] };
const demoSeed = (ibuSri.visits as unknown as DemoVisit[]);
const story7 = ibuSri.story7 as unknown as Record<"perlu_perhatian" | "segera_dikabari", DemoVisit>;
const asVisits = (vs: DemoVisit[]): Visit[] => vs.map((v) => ({ final_result: v.final_result }));

Deno.test("demo Ibu Sri: setiap kalimat bukti benar-benar ada di cerita relawan", () => {
  for (const v of [...demoSeed, story7.perlu_perhatian, story7.segera_dikabari]) {
    const story = Object.values(v.answers).join(" ");
    for (const key of DOMAIN_KEYS) assert(story.includes(v.final_result[key].evidence), v.final_result[key].evidence);
    for (const hit of v.final_result.red_flags) assert(story.includes(hit.evidence), hit.evidence);
  }
});

Deno.test("demo Ibu Sri: 6 kunjungan seed → stabil", () => {
  assertEquals(demoSeed.length, 6);
  const r = computeStatus(asVisits(demoSeed));
  assertEquals(r.status, "stabil", JSON.stringify(r.reasons));
});

Deno.test("demo Ibu Sri: cerita ke-7 versi A → perlu_perhatian (makan dan obat, mengutip relawan)", () => {
  const r = computeStatus(asVisits([...demoSeed, story7.perlu_perhatian]));
  assertEquals(r.status, "perlu_perhatian");
  assertEquals(r.reasons.map((x) => x.domain).sort(), ["makan", "obat"]);
  assert(r.reasons.some((x) => x.quote === "cuma makan beberapa suap"));
  assert(r.reasons.some((x) => x.quote === "Obat tadi pagi belum diminum"));
});

Deno.test("demo Ibu Sri: cerita ke-7 versi B (terpeleset) → segera_dikabari", () => {
  const r = computeStatus(asVisits([...demoSeed, story7.segera_dikabari]));
  assertEquals(r.status, "segera_dikabari");
  assert(r.reasons.some((x) => x.flag === "jatuh" && x.quote === "terpeleset di kamar mandi"));
});
