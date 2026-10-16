// E1: koreksi relawan yang MENURUNKAN penilaian AI (mencabut tanda bahaya, level lebih ringan atau "tidak disebut")
// dicatat di visits.overrides dan ditampilkan ke keluarga & yayasan. Tanda bahaya yang dicabut wajib beralasan.
import { DOMAIN_KEYS, DOMAINS, RED_FLAGS, type RedFlag } from "./rubric.ts";
import type { VisitResult } from "./status.ts";

export type Overrides = {
  removed_flags: { flag: string; evidence: string; reason: string }[];
  softened: { domain: string; ai: number; final: number | null }[];
};

/** `missing` berisi tanda bahaya AI yang dicabut tanpa alasan (3–200 karakter). */
export function findOverrides(ai: VisitResult, fin: VisitResult, reasons: Record<string, unknown> = {}) {
  const kept = new Set(fin.red_flags.map((f) => f.flag));
  const removed_flags: Overrides["removed_flags"] = [];
  const missing: string[] = [];
  for (const f of ai.red_flags ?? []) {
    if (kept.has(f.flag)) continue;
    const reason = typeof reasons[f.flag] === "string" ? (reasons[f.flag] as string).trim() : "";
    if (reason.length < 3 || reason.length > 200) missing.push(f.flag);
    else removed_flags.push({ flag: f.flag, evidence: f.evidence, reason });
  }
  const softened: Overrides["softened"] = [];
  for (const k of DOMAIN_KEYS) {
    const a = ai[k]?.level, b = fin[k]?.level;
    if (a != null && (b == null || b < a)) softened.push({ domain: k, ai: a, final: b ?? null });
  }
  return { overrides: { removed_flags, softened } as Overrides, missing };
}

/** Kalimat untuk status_reason, atau null bila tidak ada yang diturunkan. */
export function overrideNote(o: Overrides): string | null {
  const parts = [
    ...o.removed_flags.map((f) => `mencabut tanda bahaya ${RED_FLAGS[f.flag as RedFlag] ?? f.flag} (alasan: ${f.reason})`),
    ...o.softened.map((s) => {
      const d = DOMAINS[s.domain as keyof typeof DOMAINS];
      return `mengubah ${d.name} dari ${d.labels[s.ai]} ke ${s.final == null ? "Tidak disebut" : d.labels[s.final]}`;
    }),
  ];
  return parts.length ? `Koreksi relawan atas penilaian AI: ${parts.join("; ")}.` : null;
}
