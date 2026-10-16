// Jadwal kunjungan rutin (keputusan pengguna 16 Okt). Hari 1 = Senin … 7 = Minggu; jam disimpan sebagai waktu WIB.
const WIB = 7 * 3600_000;
const DAY = 86400_000;

/** "YYYY-MM-DD" menurut WIB. */
export const wibDate = (d: Date) => new Date(d.getTime() + WIB).toISOString().slice(0, 10);

/** Kunjungan berikutnya setelah [now]. Geseran (shiftAt) yang masih akan datang menggantikan slot minggu itu. */
export function nextVisit(weekday: number, time: string, shiftAt: string | null, now = new Date()): Date {
  if (shiftAt && new Date(shiftAt) > now) return new Date(shiftAt);
  const [h, m] = time.split(":").map(Number);
  const local = new Date(now.getTime() + WIB); // dibaca dengan getUTC* = jam dinding WIB
  const dow = ((local.getUTCDay() + 6) % 7) + 1;
  let at = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() + ((weekday - dow + 7) % 7), h, m) - WIB;
  if (at <= now.getTime()) at += 7 * DAY;
  return new Date(at);
}

/** Validasi usulan jadwal dari relawan. Mengembalikan pesan error atau null. */
export function checkSchedule(weekday: unknown, time: unknown): string | null {
  if (!Number.isInteger(weekday) || (weekday as number) < 1 || (weekday as number) > 7) return "Pilih hari kunjungan";
  if (typeof time !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) return "Jam harus berformat JJ:MM";
  return null;
}

/** Geseran hanya untuk 7 hari ke depan (menggantikan satu kunjungan minggu ini). */
export function checkShift(at: unknown, now = new Date()): string | null {
  const t = typeof at === "string" ? new Date(at) : null;
  if (!t || isNaN(t.getTime())) return "Tanggal geser tidak valid";
  if (t <= now) return "Waktu geser harus di masa depan";
  if (t.getTime() - now.getTime() > 7 * DAY) return "Geser paling jauh 7 hari ke depan";
  return null;
}
