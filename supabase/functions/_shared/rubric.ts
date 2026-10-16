// Sumber utama rubrik (PRD F4). Bila diubah, ubah juga app/lib/shared/rubric.dart.
// Index label = level: 0 = terbaik, 3 = terburuk. `null` = tidak disebut.

export const DOMAINS = {
  makan: {
    name: "Nafsu makan",
    labels: ["Baik", "Berkurang", "Sangat sedikit", "Tidak makan"],
  },
  obat: {
    name: "Obat",
    labels: [
      "Teratur",
      "Kadang terlewat",
      "Sering terlewat",
      "Habis atau berhenti",
    ],
  },
  gerak: {
    name: "Mobilitas",
    labels: [
      "Mandiri",
      "Pelan atau perlu pegangan",
      "Perlu dibantu",
      "Tidak bisa bangun",
    ],
  },
  harian: {
    name: "Kemandirian harian",
    labels: [
      "Mandiri",
      "Butuh sedikit bantuan",
      "Butuh banyak bantuan",
      "Bergantung penuh",
    ],
  },
  ingatan: {
    name: "Daya ingat",
    labels: ["Seperti biasa", "Agak pelupa", "Bingung", "Bingung mendadak"],
  },
  hati: {
    name: "Suasana hati",
    labels: ["Ceria", "Biasa", "Murung", "Menarik diri"],
  },
  umum: {
    name: "Kondisi umum",
    labels: ["Sehat", "Kurang fit", "Tampak lemah", "Tampak sakit berat"],
  },
} as const;

export type DomainKey = keyof typeof DOMAINS;
export const DOMAIN_KEYS = Object.keys(DOMAINS) as DomainKey[];
export type Level = 0 | 1 | 2 | 3 | null;

export const RED_FLAGS = {
  jatuh: "Jatuh",
  bingung_mendadak: "Bingung mendadak",
  sesak_nyeri_dada: "Sesak atau nyeri dada",
  tidak_makan: "Tidak makan sama sekali",
  obat_habis: "Obat habis",
  keluhan_baru: "Keluhan baru",
} as const;

export type RedFlag = keyof typeof RED_FLAGS;
