// Edge Function `visit` (Alur B): extract cerita via Gemini, lalu confirm dan hitung status lansia.
// Body: {action: "extract", visit_id} | {action: "confirm", visit_id, final_result, flag_reasons?}
// flag_reasons: {<tanda bahaya AI yang dicabut>: alasan}, wajib untuk setiap tanda bahaya AI yang dicabut (E1).
import { createClient } from "npm:@supabase/supabase-js@2";
import { type Answers, extractVisit } from "../_shared/extract.ts";
import { generateJson } from "../_shared/gemini.ts";
import { findOverrides, overrideNote } from "../_shared/overrides.ts";
import { notify, recipientIds } from "../_shared/recipients.ts";
import { DOMAIN_KEYS, RED_FLAGS } from "../_shared/rubric.ts";
import { computeStatus, type Visit, type VisitResult } from "../_shared/status.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

/** Koreksi relawan (F5) dicek strukturnya saja: level boleh diubah tanpa kutipan baru. */
function isVisitResult(r: unknown): r is VisitResult {
  if (!r || typeof r !== "object") return false;
  const o = r as Record<string, unknown>;
  const domainsOk = DOMAIN_KEYS.every((k) => {
    const d = o[k] as { level?: unknown; evidence?: unknown } | undefined;
    return !!d && typeof d.evidence === "string" &&
      (d.level === null || (Number.isInteger(d.level) && (d.level as number) >= 0 && (d.level as number) <= 3));
  });
  return domainsOk && Array.isArray(o.red_flags) &&
    o.red_flags.every((f) => !!f && typeof f.flag === "string" && f.flag in RED_FLAGS && typeof f.evidence === "string");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Gunakan POST" });

  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ?? "";
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json(401, { error: "Belum login" });

  const body = await req.json().catch(() => null);
  const { action, visit_id, final_result, flag_reasons } = body ?? {};
  if (!["extract", "confirm"].includes(action) || typeof visit_id !== "string" || !UUID.test(visit_id)) {
    return json(400, { error: "action harus extract/confirm dan visit_id harus uuid" });
  }
  if (action === "confirm" && !isVisitResult(final_result)) {
    return json(400, { error: "final_result tidak sesuai format 7 domain + red_flags" });
  }

  const { data: visit } = await admin.from("visits")
    .select("id, elder_id, answers, ai_result, overrides, visited_at, confirmed_at, elders(full_name, address, volunteer_id, family_id, foundation_id, status)")
    .eq("id", visit_id).maybeSingle();
  if (!visit) return json(404, { error: "Kunjungan tidak ditemukan" });
  const elder = visit.elders as unknown as {
    full_name: string;
    address: string;
    volunteer_id: string | null;
    family_id: string;
    foundation_id: string | null;
    status: string;
  };
  if (elder.volunteer_id !== auth.user.id) return json(403, { error: "Hanya relawan pasangan lansia ini" });

  if (action === "extract") {
    // Hasil asli AI disimpan berdampingan dengan koreksi relawan (F5): tidak boleh ditimpa setelah konfirmasi.
    if (visit.confirmed_at) return json(409, { error: "Kunjungan sudah dikonfirmasi" });
    // Satu kali panggilan Gemini per kunjungan (kuota free tier kecil); "Coba lagi" tetap bisa setelah gagal.
    const { data: prev } = await admin.from("visits").select("ai_result").eq("id", visit_id).single();
    if (prev?.ai_result) return json(200, { ai_result: prev.ai_result });
    let ai_result: VisitResult;
    try {
      ai_result = await extractVisit(visit.answers as Answers, { name: elder.full_name, address: elder.address }, generateJson);
    } catch (e) {
      console.error(e);
      return json(502, { error: "Gagal membaca cerita, coba lagi" });
    }
    const { error } = await admin.from("visits").update({ ai_result }).eq("id", visit_id);
    if (error) return json(500, { error: error.message });
    return json(200, { ai_result });
  }

  // confirm. Mengonfirmasi ulang = koreksi; hanya untuk kunjungan terakhir lansia ini supaya riwayat tren
  // tidak bisa ditulis ulang.
  if (visit.confirmed_at) {
    const { data: latest } = await admin.from("visits").select("id").eq("elder_id", visit.elder_id)
      .not("confirmed_at", "is", null).order("visited_at", { ascending: false }).limit(1).single();
    if (latest?.id !== visit.id) return json(409, { error: "Hanya kunjungan terakhir yang bisa dikoreksi" });
  }
  // Penurunan penilaian AI dicatat dan diperlihatkan, supaya alarm tidak bisa dibungkam diam-diam (E1).
  if (!visit.ai_result) return json(409, { error: "Cerita belum dibaca AI" });
  // Koreksi ulang: alasan yang sudah diberikan sebelumnya tetap berlaku.
  const prevReasons = Object.fromEntries(
    ((visit.overrides as { removed_flags?: { flag: string; reason: string }[] } | null)?.removed_flags ?? [])
      .map((f) => [f.flag, f.reason]),
  );
  const { overrides, missing } = findOverrides(visit.ai_result as VisitResult, final_result,
    { ...prevReasons, ...(flag_reasons && typeof flag_reasons === "object" ? flag_reasons : {}) });
  if (missing.length) return json(400, { error: "Tulis alasan untuk setiap tanda bahaya yang dicabut", missing });
  const note = overrideNote(overrides);
  const { error: upErr } = await admin.from("visits")
    .update({ final_result, overrides: note ? overrides : null, confirmed_at: new Date().toISOString() })
    .eq("id", visit_id);
  if (upErr) return json(500, { error: upErr.message });

  const { data: visits, error: listErr } = await admin.from("visits")
    .select("final_result").eq("elder_id", visit.elder_id).not("confirmed_at", "is", null)
    .order("visited_at", { ascending: true });
  if (listErr) return json(500, { error: listErr.message });

  const result = computeStatus(visits as Visit[]);
  const details = [
    ...result.reasons.map((r) => `${r.text}${r.quote ? ` Kata relawan: "${r.quote}"` : ""}`),
    ...(result.advice.length ? [`Saran: ${result.advice.join(" ")}`] : []),
  ].join("\n");
  // Kolom dibatasi 1000 karakter; disclaimer selalu ikut.
  // Catatan koreksi relawan di baris pertama: itu yang tampil di dashboard yayasan.
  const head = [note, details].filter(Boolean).join("\n");
  const status_reason = [head.slice(0, 1000 - result.disclaimer.length - 1), result.disclaimer]
    .filter(Boolean).join("\n");
  const { error: elErr } = await admin.from("elders")
    .update({ status: result.status, status_reason, status_ack_at: null, status_ack_by: null, status_ack_note: null })
    .eq("id", visit.elder_id); // penilaian baru: tanda "sudah ditangani" dihapus
  if (elErr) return json(500, { error: elErr.message });
  // Status setelah kunjungan ini, untuk Riwayat keluarga ("3 Okt · Stabil"). Gagal tidak membatalkan confirm.
  await admin.from("visits").update({ status_after: result.status }).eq("id", visit_id);

  // Push hanya saat status BERUBAH menjadi segera_dikabari, supaya keluarga tidak dikirimi ulang tiap kunjungan.
  // Gagal kirim push tidak membatalkan confirm: status sudah tersimpan dan terlihat lewat Realtime.
  if (result.status === "segera_dikabari" && elder.status !== "segera_dikabari") {
    try {
      const ids = await recipientIds(admin, { id: visit.elder_id, ...elder }, { category: "kondisi" });
      const first = result.reasons[0];
      const push = await notify(admin, ids, {
        title: `Segera dikabari: ${elder.full_name}`,
        body: `${first.text}${first.quote ? ` "${first.quote}"` : ""}`.slice(0, 200),
        data: { elder_id: visit.elder_id, type: "segera_dikabari" },
      });
      console.log("push segera_dikabari", push);
    } catch (e) {
      console.error("push gagal", e);
    }
  }
  return json(200, result);
});
