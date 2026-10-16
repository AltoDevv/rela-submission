// Usulan relawan otomatis (PRD F2/F2a) dan pencocokan ulang saat relawan lepas. Dipakai pairing, reminders, account.
// deno-lint-ignore-file no-explicit-any
import { type Candidate, pickVolunteer } from "./matching.ts";
import { notify, recipientIds } from "./recipients.ts";

export const MAX_PROPOSALS = 3;

export type Elder = {
  id: string;
  family_id: string;
  lat: number;
  lng: number;
  has_dementia: boolean;
  has_mobility_issue: boolean;
  pairing_state: string;
  match_round_at?: string | null;
};
export const ELDER_COLS = "id, family_id, lat, lng, has_dementia, has_mobility_issue, pairing_state, match_round_at";

export async function setElder(admin: any, id: string, fields: Record<string, unknown>) {
  const { error } = await admin.from("elders").update(fields).eq("id", id);
  if (error) throw error;
}

/** Mengusulkan relawan berikutnya. Bila sudah 3 usulan → perlu_yayasan, bila tidak ada kandidat → tanpa_pendamping. */
export async function proposeNext(admin: any, elder: Elder) {
  const { data: past, error: e1 } = await admin.from("proposals").select("volunteer_id, created_at, state")
    .eq("elder_id", elder.id);
  if (e1) throw e1;
  // Putaran baru (hitungan 3 usulan mulai lagi dari 1) setelah keluarga minta ganti atau relawan lepas, tetapi semua
  // relawan yang pernah diusulkan/mendampingi lansia ini tetap dikecualikan (unique elder_id + volunteer_id).
  const { data: lastChange } = await admin.from("pairing_changes").select("created_at").eq("elder_id", elder.id)
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  const since = [lastChange?.created_at, elder.match_round_at].filter((t): t is string => !!t)
    .map((t) => new Date(t).getTime());
  const start = since.length ? Math.max(...since) : 0;
  const round = (past as any[]).filter((p) => p.state !== "manual" && new Date(p.created_at).getTime() > start);
  if (round.length >= MAX_PROPOSALS) {
    await setElder(admin, elder.id, { pairing_state: "perlu_yayasan" });
    return { pairing_state: "perlu_yayasan" };
  }

  // Dikecualikan: relawan yang sudah pernah diusulkan ke lansia ini, dan relawan yang sedang "dipesan".
  const { data: pending, error: e2 } = await admin.from("proposals").select("volunteer_id").eq("state", "pending");
  const { data: vols, error: e3 } = await admin.from("volunteers")
    .select("id, status, lat, lng, can_dementia, can_mobility, max_load, available_days, languages")
    .eq("status", "aktif").is("resign_requested_at", null).not("lat", "is", null).not("lng", "is", null);
  const { data: paired, error: e4 } = await admin.from("elders").select("volunteer_id")
    .eq("pairing_state", "berpasangan").not("volunteer_id", "is", null);
  if (e2 || e3 || e4) throw e2 ?? e3 ?? e4;

  // Juga relawan yang pernah diganti atau pernah berkunjung (pasangan lama bisa terjadi tanpa baris proposals,
  // mis. data awal atau pemasangan lama), supaya keluarga tidak disodori relawan yang baru saja diganti.
  const { data: changed } = await admin.from("pairing_changes").select("volunteer_id").eq("elder_id", elder.id);
  const { data: visited } = await admin.from("visits").select("volunteer_id").eq("elder_id", elder.id);
  const excluded = [...past, ...pending, ...(changed ?? []), ...(visited ?? [])]
    .map((p: any) => p.volunteer_id).filter((id: unknown): id is string => !!id);
  const candidates: Candidate[] = vols.map((v: any) => ({
    ...v,
    load: paired.filter((e: any) => e.volunteer_id === v.id).length,
  }));

  for (;;) {
    const match = pickVolunteer(elder, candidates, excluded);
    if (!match) {
      await setElder(admin, elder.id, { pairing_state: "tanpa_pendamping" });
      return { pairing_state: "tanpa_pendamping" };
    }
    const { data, error } = await admin.from("proposals").insert({
      elder_id: elder.id,
      volunteer_id: match.volunteer.id,
      attempt: round.length + 1,
      distance_km: match.distanceKm,
      reason_text: match.reasonText,
    }).select("id").single();
    // 23505 = melanggar index unik: relawan baru saja dipesan untuk lansia lain. Coba kandidat berikutnya.
    if (error?.code === "23505") {
      excluded.push(match.volunteer.id);
      continue;
    }
    if (error) throw error;
    await setElder(admin, elder.id, { pairing_state: "menunggu_keluarga" });
    return { pairing_state: "menunggu_keluarga", proposal_id: data.id };
  }
}

/**
 * Keputusan pengguna 16 Okt: lansia yang kehilangan relawan (berhenti, mengundurkan diri, dinonaktifkan, dilepas
 * yayasan, akun relawan dihapus) langsung masuk pencocokan otomatis putaran baru, bisa ke yayasan lain. Lansia
 * tanpa_pendamping dicoba lagi (relawan baru mungkin sudah ada) tanpa mengulang hitungan. Bila tetap tidak ada
 * relawan yang cocok, lansia terlihat oleh semua yayasan (foundation_id kosong) untuk dipasangkan manual.
 * Lansia yang langganannya habis atau dokumennya belum dikirim tetap menunggu (sama dengan syarat aksi propose).
 */
export async function rematch(admin: any, elderId: string) {
  const { data: e } = await admin.from("elders")
    .select(`${ELDER_COLS}, full_name, foundation_id, paid_until, verify_state`).eq("id", elderId).maybeSingle();
  if (!e || !["perlu_yayasan", "tanpa_pendamping"].includes(e.pairing_state)) return null;
  if (e.lat == null || e.lng == null) return null;
  if (!e.paid_until || new Date(e.paid_until) < new Date()) return null;
  if (!["menunggu", "terverifikasi"].includes(e.verify_state)) return null;

  const wasState = e.pairing_state;
  if (wasState === "perlu_yayasan") {
    const now = new Date().toISOString();
    await setElder(admin, e.id, { pairing_state: "mencari", match_round_at: now });
    e.match_round_at = now;
  }
  const r = await proposeNext(admin, e);
  if (r.pairing_state === "tanpa_pendamping" && e.foundation_id) await setElder(admin, e.id, { foundation_id: null });
  if (r.pairing_state === "menunggu_keluarga" || wasState === "perlu_yayasan") {
    try {
      await notify(admin, await recipientIds(admin, e, { foundation: false, category: "pendamping" }), r.pairing_state === "menunggu_keluarga"
        ? {
          title: `Usulan relawan baru untuk ${e.full_name}`,
          body: "Buka aplikasi untuk meninjau relawan yang diusulkan.",
          data: { elder_id: e.id, type: "usulan" },
        }
        : {
          title: `Belum ada relawan pengganti untuk ${e.full_name}`,
          body: "Yayasan di sekitar sudah diberi tahu dan akan membantu mencarikan.",
          data: { elder_id: e.id, type: "tanpa_pendamping" },
        });
    } catch (err) {
      console.error("push gagal", err);
    }
  }
  return r;
}

/** Sapuan: semua lansia perlu_yayasan/tanpa_pendamping dicocokkan ulang. Dipanggil setelah aksi yang melepas
 *  relawan dan setiap hari oleh reminders (menangkap jalur lain, mis. relawan mencabut keahlian). */
export async function rematchReleased(admin: any) {
  const { data } = await admin.from("elders").select("id").in("pairing_state", ["perlu_yayasan", "tanpa_pendamping"]);
  let n = 0;
  for (const e of data ?? []) {
    try {
      if (await rematch(admin, e.id)) n++;
    } catch (err) {
      console.error("rematch gagal", e.id, err);
    }
  }
  return n;
}
