import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import { type Candidate, type Elder, haversineKm, pickVolunteer } from "./matching.ts";

// Lansia di sekitar Tugu Jogja. 0,01° lintang ≈ 1,1 km.
const elder: Elder = { lat: -7.78, lng: 110.37, has_dementia: false, has_mobility_issue: false };

function vol(id: string, kmNorth: number, extra: Partial<Candidate> = {}): Candidate {
  return {
    id,
    status: "aktif",
    lat: elder.lat + kmNorth * 0.01 / 1.112,
    lng: elder.lng,
    can_dementia: false,
    can_mobility: false,
    max_load: 3,
    load: 0,
    available_days: ["senin"],
    languages: ["indonesia"],
    ...extra,
  };
}

Deno.test("haversineKm: Tugu Jogja ke Balairung UGM ≈ 1,83 km", () => {
  assertAlmostEquals(haversineKm(-7.782889, 110.367083, -7.770278, 110.377778), 1.83, 0.01);
});

Deno.test("yang terdekat dipilih", () => {
  const r = pickVolunteer(elder, [vol("jauh", 5), vol("dekat", 1), vol("sedang", 3)], []);
  assertEquals(r?.volunteer.id, "dekat");
  assertEquals(r?.distanceKm, 1.0);
});

Deno.test("lansia demensia hanya ke relawan yang mampu mendampingi demensia", () => {
  const e = { ...elder, has_dementia: true };
  const r = pickVolunteer(e, [vol("dekat", 1), vol("mampu", 4, { can_dementia: true })], []);
  assertEquals(r?.volunteer.id, "mampu");
});

Deno.test("lansia mobilitas sulit hanya ke relawan yang mampu membantu mobilitas", () => {
  const e = { ...elder, has_mobility_issue: true };
  const r = pickVolunteer(e, [vol("dekat", 1), vol("mampu", 4, { can_mobility: true })], []);
  assertEquals(r?.volunteer.id, "mampu");
});

Deno.test("lansia dengan keduanya hanya ke relawan yang mampu keduanya", () => {
  const e = { ...elder, has_dementia: true, has_mobility_issue: true };
  const r = pickVolunteer(e, [
    vol("demensia_saja", 1, { can_dementia: true }),
    vol("mobilitas_saja", 2, { can_mobility: true }),
    vol("keduanya", 6, { can_dementia: true, can_mobility: true }),
  ], []);
  assertEquals(r?.volunteer.id, "keduanya");
});

Deno.test("jarak sama: beban terendah didahulukan", () => {
  // id sengaja dipilih supaya urutan abjad berlawanan dengan urutan beban.
  const r = pickVolunteer(elder, [vol("a_sibuk", 2, { load: 2 }), vol("z_longgar", 2, { load: 0 })], []);
  assertEquals(r?.volunteer.id, "z_longgar");
});

Deno.test("hari dan bahasa tidak memengaruhi pilihan", () => {
  const r = pickVolunteer(elder, [
    vol("dekat_beda_hari_bahasa", 1, { available_days: ["minggu"], languages: ["sunda"] }),
    vol("jauh_cocok", 3, { available_days: ["senin", "selasa", "rabu"], languages: ["indonesia", "jawa"] }),
  ], []);
  assertEquals(r?.volunteer.id, "dekat_beda_hari_bahasa");
});

Deno.test("relawan di excludedIds (sudah ditolak/dipesan) dilewati", () => {
  const r = pickVolunteer(elder, [vol("ditolak", 1), vol("berikutnya", 2)], ["ditolak"]);
  assertEquals(r?.volunteer.id, "berikutnya");
});

Deno.test("relawan yang mencapai max_load dilewati", () => {
  const r = pickVolunteer(elder, [vol("penuh", 1, { load: 3, max_load: 3 }), vol("ada_ruang", 2)], []);
  assertEquals(r?.volunteer.id, "ada_ruang");
});

Deno.test("hanya relawan berstatus aktif", () => {
  const r = pickVolunteer(elder, [vol("terdaftar", 1, { status: "terdaftar" }), vol("aktif", 2)], []);
  assertEquals(r?.volunteer.id, "aktif");
});

Deno.test("tidak ada kandidat yang memenuhi syarat → null", () => {
  assertEquals(pickVolunteer(elder, [], []), null);
  const e = { ...elder, has_dementia: true };
  assertEquals(pickVolunteer(e, [vol("tidak_mampu", 1)], []), null);
});

Deno.test("reasonText: jarak koma desimal + keahlian yang relevan", () => {
  const e = { ...elder, has_dementia: true };
  const r = pickVolunteer(e, [vol("v", 1.2, { can_dementia: true, can_mobility: true })], []);
  assertEquals(r?.reasonText, "Jarak 1,2 km · berpengalaman mendampingi lansia dengan demensia");
});

Deno.test("reasonText: kedua keahlian, dan tanpa keahlian bila lansia tidak membutuhkannya", () => {
  const both = { ...elder, has_dementia: true, has_mobility_issue: true };
  const r1 = pickVolunteer(both, [vol("v", 2.5, { can_dementia: true, can_mobility: true })], []);
  assertEquals(
    r1?.reasonText,
    "Jarak 2,5 km · berpengalaman mendampingi lansia dengan demensia · mampu membantu lansia dengan mobilitas sulit",
  );
  const r2 = pickVolunteer(elder, [vol("v", 2.5, { can_dementia: true })], []);
  assertEquals(r2?.reasonText, "Jarak 2,5 km");
});
