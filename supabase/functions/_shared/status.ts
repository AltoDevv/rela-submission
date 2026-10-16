// Aturan status lansia (PRD F6, architecture.md bagian 5). Fungsi murni, tanpa database.
import {
  DOMAIN_KEYS,
  type DomainKey,
  DOMAINS,
  type Level,
  RED_FLAGS,
  type RedFlag,
} from "./rubric.ts";

export type DomainResult = { level: Level; evidence: string };
export type RedFlagHit = { flag: RedFlag; evidence: string };
export type VisitResult = Record<DomainKey, DomainResult> & {
  red_flags: RedFlagHit[];
};
/** Kunjungan yang sudah dikonfirmasi relawan. */
export type Visit = { final_result: VisitResult };

export type Status = "stabil" | "perlu_perhatian" | "segera_dikabari";
export type Reason = {
  domain?: DomainKey;
  flag?: RedFlag;
  text: string;
  quote: string;
};
export type StatusResult = {
  status: Status;
  reasons: Reason[];
  advice: string[];
  disclaimer: string;
};

export const DISCLAIMER =
  "Ini bukan diagnosis. Status ini hanya ringkasan dari cerita relawan untuk membantu keluarga dan yayasan.";
const BASELINE_VISITS = 3;

/** Kategori yang paling sering muncul di 3 kunjungan pertama. `null` bila domain tidak pernah disebut. */
function baseline(levels: Level[]): Level {
  const count = new Map<number, number>();
  for (const l of levels.slice(0, BASELINE_VISITS)) {
    if (l !== null) count.set(l, (count.get(l) ?? 0) + 1);
  }
  let best: Level = null;
  for (const [l, n] of count) {
    // ponytail: seri diselesaikan dengan level yang lebih buruk supaya alarm palsu lebih sedikit.
    if (
      best === null || n > count.get(best)! ||
      (n === count.get(best)! && l > best)
    ) best = l as Level;
  }
  return best;
}

/** `visits` terurut dari kunjungan lama ke baru. */
export function computeStatus(visits: Visit[]): StatusResult {
  const reasons: Reason[] = [];
  const latest = visits.at(-1)?.final_result;

  for (const hit of latest?.red_flags ?? []) {
    reasons.push({
      flag: hit.flag,
      text: `Tanda bahaya: ${RED_FLAGS[hit.flag]}.`,
      quote: hit.evidence,
    });
  }
  const urgent = reasons.length > 0;

  // Sebelum ada 3 kunjungan, baseline belum sah: hanya tanda bahaya yang dihitung.
  if (latest && visits.length >= BASELINE_VISITS) {
    for (const key of DOMAIN_KEYS) {
      const levels = visits.map((v) => v.final_result[key]?.level ?? null);
      const base = baseline(levels);
      const now = levels.at(-1)!;
      if (base === null || now === null || now <= base) continue; // null dilewati; tidak lebih buruk dari baseline
      const { name, labels } = DOMAINS[key];
      const known = levels.filter((l) => l !== null) as number[];
      const [a, b, c] = known.slice(-3);

      let why: string | null = null;
      if (now - base >= 2) why = `turun ${now - base} tingkat dari biasanya`;
      else if (known.length >= 3 && a < b && b < c) {
        why = "memburuk 3 kunjungan berturut-turut";
      } else if (
        key === "obat" &&
        levels.slice(-3).filter((l) => (l === 1 || l === 2) && l > base)
            .length >= 2
      ) {
        why = "terlewat pada 2 dari 3 kunjungan terakhir";
      } else if (key === "harian") {
        why = "ada kemampuan harian yang baru hilang";
      }
      if (!why) continue;

      reasons.push({
        domain: key,
        text: `${name}: ${labels[now]} (biasanya ${labels[base]}), ${why}.`,
        quote: latest[key].evidence,
      });
    }
  }

  if (reasons.length === 0) {
    return { status: "stabil", reasons, advice: [], disclaimer: DISCLAIMER };
  }
  const advice = ["Telepon lansia untuk menanyakan kabarnya."];
  if (reasons.some((r) => r.domain === "obat" || r.flag === "obat_habis")) {
    advice.push("Bantu isi ulang obat.");
  }
  advice.push("Periksakan ke puskesmas atau dokter langganan.");
  return {
    status: urgent ? "segera_dikabari" : "perlu_perhatian",
    reasons,
    advice,
    disclaimer: DISCLAIMER,
  };
}
