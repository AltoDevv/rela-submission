import { assertEquals } from "jsr:@std/assert";
import { findOverrides, overrideNote } from "./overrides.ts";
import type { VisitResult } from "./status.ts";

const base = (): VisitResult => ({
  makan: { level: 2, evidence: "beberapa suap" }, obat: { level: 0, evidence: "" }, gerak: { level: 1, evidence: "" },
  harian: { level: 0, evidence: "" }, ingatan: { level: null, evidence: "" }, hati: { level: 1, evidence: "" },
  umum: { level: 1, evidence: "" }, red_flags: [{ flag: "jatuh", evidence: "terpeleset di kamar mandi" }],
} as VisitResult);

Deno.test("tidak ada koreksi → tidak ada catatan", () => {
  const r = findOverrides(base(), base());
  assertEquals(r.missing, []);
  assertEquals(overrideNote(r.overrides), null);
});

Deno.test("mencabut tanda bahaya tanpa alasan → missing", () => {
  const fin = { ...base(), red_flags: [] };
  assertEquals(findOverrides(base(), fin).missing, ["jatuh"]);
  assertEquals(findOverrides(base(), fin, { jatuh: "  " }).missing, ["jatuh"]);
});

Deno.test("dicabut dengan alasan + level diturunkan → tercatat di catatan", () => {
  const fin = { ...base(), makan: { level: 0, evidence: "beberapa suap" }, hati: { level: null, evidence: "" }, red_flags: [] } as VisitResult;
  const { overrides, missing } = findOverrides(base(), fin, { jatuh: "Itu cerita tahun lalu" });
  assertEquals(missing, []);
  assertEquals(overrides.removed_flags[0].reason, "Itu cerita tahun lalu");
  assertEquals(overrides.softened.map((s) => s.domain), ["makan", "hati"]);
  assertEquals(overrideNote(overrides),
    "Koreksi relawan atas penilaian AI: mencabut tanda bahaya Jatuh (alasan: Itu cerita tahun lalu); " +
      "mengubah Nafsu makan dari Sangat sedikit ke Baik; mengubah Suasana hati dari Biasa ke Tidak disebut.");
});

Deno.test("menaikkan level / menambah tanda bahaya bukan penurunan", () => {
  const fin = { ...base(), makan: { level: 3, evidence: "" }, red_flags: [...base().red_flags, { flag: "obat_habis", evidence: "x" }] } as VisitResult;
  assertEquals(overrideNote(findOverrides(base(), fin).overrides), null);
});
