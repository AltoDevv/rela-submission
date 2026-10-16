// Penerima notifikasi untuk satu lansia: keluarga (pendaftar + anggota yang sudah menerima undangan) dan pengurus
// yayasannya. Token diambil dari push_tokens (bisa banyak perangkat per akun). Dipakai visit, emergency, pairing.
// deno-lint-ignore-file no-explicit-any
import { type PushMessage, type PushResult, sendPush } from "./push.ts";

type Elder = { id: string; family_id: string; foundation_id?: string | null };

/** Id pendaftar + anggota keluarga yang sudah menerima undangan. */
export async function familyIds(admin: any, elder: Elder): Promise<string[]> {
  const { data } = await admin.from("family_members").select("profile_id")
    .eq("elder_id", elder.id).not("accepted_at", "is", null);
  return [elder.family_id, ...(data ?? []).map((m: { profile_id: string }) => m.profile_id)];
}

/** Id keluarga (+ `extraIds`) dan, bila `foundation` true, pengurus yayasan lansia ini. `exclude` dilewati.
 *  `category` (kondisi · pendamping · pengingat): akun yang mematikan kategori itu (profiles.notify_off) dilewati;
 *  tanpa category (mis. darurat) selalu terkirim. */
export async function recipientIds(
  admin: any,
  elder: Elder,
  { extraIds = [], exclude, foundation = true, category }: {
    extraIds?: (string | null)[];
    exclude?: string;
    foundation?: boolean;
    category?: string;
  } = {},
): Promise<string[]> {
  const ids = new Set([...await familyIds(admin, elder), ...extraIds].filter((x): x is string => !!x));
  if (foundation && elder.foundation_id) {
    const { data } = await admin.from("profiles").select("id").eq("role", "yayasan").eq("foundation_id", elder.foundation_id);
    for (const p of data ?? []) ids.add(p.id);
  }
  if (exclude) ids.delete(exclude);
  if (category && ids.size) {
    const { data } = await admin.from("profiles").select("id, notify_off").in("id", [...ids]);
    for (const p of data ?? []) if ((p.notify_off ?? []).includes(category)) ids.delete(p.id);
  }
  return [...ids];
}

/** Token semua perangkat milik akun-akun ini. */
export async function tokensFor(admin: any, ids: (string | null | undefined)[]): Promise<string[]> {
  const clean = [...new Set(ids.filter((x): x is string => !!x))];
  if (!clean.length) return [];
  const { data } = await admin.from("push_tokens").select("token").in("profile_id", clean);
  return (data ?? []).map((t: { token: string }) => t.token);
}

/** Token penerima untuk satu lansia (lihat [recipientIds]). */
export async function recipientTokens(admin: any, elder: Elder, opts: Parameters<typeof recipientIds>[2] = {}) {
  return tokensFor(admin, await recipientIds(admin, elder, opts));
}

/** Catat ke kotak masuk (tabel notifications, dibaca lewat lonceng di aplikasi) lalu kirim push ke semua perangkat.
 *  Dicatat per akun, jadi akun yang sedang logout tetap melihatnya saat masuk lagi. */
export async function notify(
  admin: any,
  ids: (string | null | undefined)[],
  msg: PushMessage,
  send: (tokens: string[], msg: PushMessage) => Promise<PushResult> = sendPush,
): Promise<PushResult> {
  const clean = [...new Set(ids.filter((x): x is string => !!x))];
  if (!clean.length) return { sent: 0, skipped: 0, failed: 0 };
  const { error } = await admin.from("notifications").insert(
    clean.map((profile_id) => ({ profile_id, title: msg.title, body: msg.body, data: msg.data ?? {} })),
  );
  if (error) console.error("simpan notifikasi gagal", error);
  return send(await tokensFor(admin, clean), msg);
}
