import { assertEquals } from "jsr:@std/assert@1";
import { checkSchedule, checkShift, nextVisit, wibDate } from "./schedule.ts";

// Jumat 16 Okt 2026 09.00 WIB = 02.00 UTC.
const now = new Date("2026-10-16T02:00:00Z");

Deno.test("kunjungan berikutnya: Rabu 10.00 dari Jumat → Rabu depan; Jumat 15.00 → hari ini", () => {
  assertEquals(nextVisit(3, "10:00", null, now).toISOString(), "2026-10-21T03:00:00.000Z");
  assertEquals(nextVisit(5, "15:00:00", null, now).toISOString(), "2026-10-16T08:00:00.000Z");
  assertEquals(nextVisit(5, "08:00", null, now).toISOString(), "2026-10-23T01:00:00.000Z", "jam sudah lewat → minggu depan");
});

Deno.test("geseran yang akan datang menggantikan slot; yang sudah lewat diabaikan", () => {
  assertEquals(nextVisit(3, "10:00", "2026-10-17T07:00:00Z", now).toISOString(), "2026-10-17T07:00:00.000Z");
  assertEquals(nextVisit(3, "10:00", "2026-10-15T07:00:00Z", now).toISOString(), "2026-10-21T03:00:00.000Z");
});

Deno.test("tanggal WIB dan validasi", () => {
  assertEquals(wibDate(new Date("2026-10-16T18:00:00Z")), "2026-10-17");
  assertEquals(checkSchedule(3, "10:00"), null);
  assertEquals(checkSchedule(8, "10:00"), "Pilih hari kunjungan");
  assertEquals(checkSchedule(3, "25:00"), "Jam harus berformat JJ:MM");
  assertEquals(checkShift("2026-10-18T03:00:00Z", now), null);
  assertEquals(checkShift("2026-10-15T03:00:00Z", now), "Waktu geser harus di masa depan");
  assertEquals(checkShift("2026-10-30T03:00:00Z", now), "Geser paling jauh 7 hari ke depan");
});
