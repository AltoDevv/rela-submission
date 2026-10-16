// Edge Function `pairing` (Alur A, PRD F2 dan F2a): usulkan, terima, tolak, dan pasang manual.
// Body: {action: "propose", elder_id} | {action: "accept", proposal_id}
//     | {action: "reject", proposal_id, reason, note?} | {action: "manual", elder_id, volunteer_id}
//     | {action: "release", elder_id}  (yayasan melepas; lansia langsung dicocokkan ulang otomatis)
//     | {action: "end", elder_id, reason, note?}  (pendampingan selesai: meninggal/pindah/tidak_butuh/lainnya)
//     | {action: "delete", elder_id, confirm: "HAPUS"}  (pendaftar menghapus semua data lansia, UU PDP)
//     | {action: "verify", elder_id, approve, note?}  (yayasan memeriksa dokumen keluarga/lansia secara online)
//     | {action: "request_stop", elder_id, reason}  (relawan mengajukan berhenti; diterima yayasan / otomatis 7 hari)
//     | {action: "approve_stop", request_id}  (yayasan menerima permintaan berhenti)
//     | {action: "deactivate", volunteer_id, reason}  (yayasan menonaktifkan relawan aktif)
//     | {action: "schedule_propose", elder_id, weekday, time}  (relawan mengusulkan jadwal rutin, mis. 3, "10:00")
//     | {action: "schedule_answer", elder_id, approve}  (keluarga menyetujui/menolak usulan jadwal)
//     | {action: "schedule_shift", elder_id, at}  (relawan menggeser satu kunjungan, maks. 7 hari ke depan)
//     | {action: "resign", reason}  (relawan mengajukan pengunduran diri; semua lansianya ikut diajukan berhenti)
//     | {action: "change", elder_id, reason, note?}  (keluarga minta ganti; maks. 1× per lansia; pengganti otomatis)
import { createClient } from "npm:@supabase/supabase-js@2";
import { haversineKm } from "../_shared/matching.ts";
import { checkSchedule, checkShift } from "../_shared/schedule.ts";
import { ELDER_COLS, type Elder, MAX_PROPOSALS, proposeNext as proposeNextShared, rematch, rematchReleased, setElder as setElderShared } from "../_shared/propose.ts";
import { approveStop } from "../_shared/stop.ts";
import { familyIds, notify, recipientIds } from "../_shared/recipients.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  {
    auth: { persistSession: false },
  },
);

const REJECT_REASONS = ["jarak", "jadwal", "bahasa", "lainnya"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isId = (v: unknown): v is string => typeof v === "string" && UUID.test(v);
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const setElder = (id: string, fields: Record<string, unknown>) => setElderShared(admin, id, fields);
const proposeNext = (elder: Elder) => proposeNextShared(admin, elder);

/** Usulan beserta lansianya, setelah memastikan pemanggil adalah keluarga pemilik dan usulan masih pending. */
async function ownPendingProposal(proposalId: unknown, userId: string) {
  if (!isId(proposalId)) {
    return { res: json(400, { error: "proposal_id harus uuid" }) };
  }
  const { data: p } = await admin.from("proposals")
    .select(
      `id, attempt, state, volunteer_id, volunteers(foundation_id), elders(${ELDER_COLS})`,
    )
    .eq("id", proposalId).maybeSingle();
  if (!p) return { res: json(404, { error: "Usulan tidak ditemukan" }) };
  const elder = p.elders as unknown as Elder;
  if (elder.family_id !== userId) {
    return { res: json(403, { error: "Hanya keluarga lansia ini" }) };
  }
  if (p.state !== "pending") {
    return { res: json(409, { error: "Usulan ini sudah dijawab" }) };
  }
  const foundationId =
    (p.volunteers as unknown as { foundation_id: string }).foundation_id;
  return { p, elder, foundationId };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Gunakan POST" });

  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ??
    "";
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json(401, { error: "Belum login" });
  const userId = auth.user.id;

  const body = await req.json().catch(() => null) ?? {};
  // Usulan yang tidak dijawab 48 jam dilepas dulu, supaya relawannya bisa diusulkan ke lansia lain.
  await admin.rpc("expire_stale_proposals");
  try {
    switch (body.action) {
      case "propose": {
        if (!isId(body.elder_id)) {
          return json(400, { error: "elder_id harus uuid" });
        }
        const { data: elder } = await admin.from("elders").select(ELDER_COLS)
          .eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        if (elder.family_id !== userId) {
          return json(403, { error: "Hanya keluarga lansia ini" });
        }
        if (!["mencari", "tanpa_pendamping"].includes(elder.pairing_state)) {
          return json(409, {
            error: `Tidak bisa mengusulkan saat status ${elder.pairing_state}`,
          });
        }
        if (elder.lat == null || elder.lng == null) {
          return json(400, { error: "Lokasi lansia belum diisi" });
        }
        // K1/K5: relawan hanya diusulkan untuk lansia yang berlangganan dan dokumennya sudah dikirim.
        const { data: gate } = await admin.from("elders").select("paid_until, verify_state").eq("id", elder.id).single();
        if (!gate?.paid_until || new Date(gate.paid_until) < new Date()) {
          return json(402, { error: "Langganan lansia ini belum aktif" });
        }
        if (!["menunggu", "terverifikasi"].includes(gate.verify_state)) {
          return json(409, { error: "Lengkapi dokumen verifikasi dulu" });
        }
        return json(200, await proposeNext(elder));
      }

      case "accept": {
        const r = await ownPendingProposal(body.proposal_id, userId);
        if (r.res) return r.res;
        const { error } = await admin.from("proposals").update({
          state: "accepted",
        }).eq("id", r.p.id);
        if (error) throw error;
        await setElder(r.elder.id, {
          volunteer_id: r.p.volunteer_id,
          foundation_id: r.foundationId,
          pairing_state: "berpasangan",
          first_visit_at: null, // relawan baru memastikan lagi lansia ada & setuju
        });
        // Dokumen keluarga kini diperiksa yayasan relawan ini.
        try {
          const { data: e } = await admin.from("elders").select("full_name, verify_state").eq("id", r.elder.id).single();
          if (e?.verify_state === "menunggu") {
            const { data: admins } = await admin.from("profiles").select("id").eq("role", "yayasan")
              .eq("foundation_id", r.foundationId);
            await notify(admin, (admins ?? []).map((a: { id: string }) => a.id), {
              title: `Periksa dokumen keluarga ${e.full_name}`,
              body: "Keluarga sudah menerima relawan Anda. Periksa dokumennya sebelum relawan berkunjung.",
              data: { elder_id: r.elder.id, type: "verifikasi" },
            });
          }
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { pairing_state: "berpasangan" });
      }

      case "reject": {
        const { reason } = body;
        const note = typeof body.note === "string" ? body.note.trim() : "";
        if (!REJECT_REASONS.includes(reason)) {
          return json(400, {
            error: "reason harus jarak/jadwal/bahasa/lainnya",
          });
        }
        if (reason === "lainnya" && !note) {
          return json(400, { error: "Alasan 'lainnya' wajib disertai teks" });
        }
        if (note.length > 300) {
          return json(400, { error: "Teks alasan maksimal 300 karakter" });
        }
        const r = await ownPendingProposal(body.proposal_id, userId);
        if (r.res) return r.res;
        // Keputusan pengguna 16 Okt: usulan ke-3 tidak bisa ditolak. Bila nanti kurang cocok, keluarga punya
        // jatah Minta ganti satu kali per lansia.
        if (r.p.attempt >= MAX_PROPOSALS) {
          return json(409, { error: "Usulan ketiga tidak bisa ditolak. Bila nanti kurang cocok, gunakan Minta ganti pendamping." });
        }
        const { error } = await admin.from("proposals")
          .update({
            state: "rejected",
            reject_reason: reason,
            reject_note: note || null,
          }).eq("id", r.p.id);
        if (error) throw error;
        return json(200, await proposeNext(r.elder));
      }

      case "manual": {
        if (!isId(body.elder_id) || !isId(body.volunteer_id)) {
          return json(400, { error: "elder_id dan volunteer_id harus uuid" });
        }
        const { data: me } = await admin.from("profiles").select(
          "role, foundation_id",
        ).eq("id", userId).single();
        if (me?.role !== "yayasan" || !me.foundation_id) {
          return json(403, { error: "Khusus pengurus yayasan" });
        }
        const { data: elder } = await admin.from("elders").select(
          "id, lat, lng, pairing_state",
        )
          .eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        if (!["perlu_yayasan", "tanpa_pendamping"].includes(elder.pairing_state)) {
          return json(409, {
            error: "Pemasangan manual hanya untuk lansia yang belum mendapat relawan",
          });
        }
        const { data: v } = await admin.from("volunteers").select(
          "id, status, foundation_id, lat, lng",
        )
          .eq("id", body.volunteer_id).maybeSingle();
        if (
          !v || v.status !== "aktif" || v.foundation_id !== me.foundation_id
        ) {
          return json(400, {
            error: "Relawan harus aktif dan dari yayasan Anda",
          });
        }
        const km = elder.lat != null && v.lat != null
          ? Math.round(haversineKm(elder.lat, elder.lng, v.lat, v.lng) * 10) /
            10
          : 0;
        // Relawan yang pernah ditolak boleh dipilih setelah yayasan bicara dengan keluarga, jadi barisnya ditimpa.
        // ponytail: attempt diisi 3 karena kolomnya wajib 1..3; usulan manual tidak dihitung sebagai kesempatan.
        const { error } = await admin.from("proposals").upsert({
          elder_id: elder.id,
          volunteer_id: v.id,
          attempt: MAX_PROPOSALS,
          distance_km: km,
          reason_text: "Dipasangkan manual oleh pengurus yayasan",
          state: "manual",
          reject_reason: null,
          reject_note: null,
        }, { onConflict: "elder_id,volunteer_id" });
        if (error) throw error;
        await setElder(elder.id, {
          volunteer_id: v.id,
          foundation_id: v.foundation_id,
          pairing_state: "berpasangan",
          first_visit_at: null, // relawan baru memastikan lagi lansia ada & setuju
        });
        return json(200, { pairing_state: "berpasangan" });
      }

      case "release": {
        // Mengakhiri pasangan. Lansia diteruskan ke yayasan (perlu_yayasan) untuk dipasangkan ulang
        // lewat pemasangan manual setelah bicara dengan keluarga; relawan lama otomatis kehilangan akses (RLS).
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        const { data: elder } = await admin.from("elders")
          .select("id, full_name, family_id, foundation_id, volunteer_id, pairing_state")
          .eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id, full_name")
          .eq("id", userId).single();
        const family = await familyIds(admin, elder);
        const by = elder.volunteer_id === userId
          ? "relawan"
          : family.includes(userId)
          ? "keluarga"
          : me?.role === "yayasan" && me.foundation_id && me.foundation_id === elder.foundation_id
          ? "yayasan"
          : null;
        if (!by) return json(403, { error: "Hanya relawan pasangan, keluarga, atau yayasan lansia ini" });
        // Relawan tidak melepas sendiri: lansia tidak boleh tiba-tiba tanpa pendamping (lihat request_stop).
        if (by === "relawan") return json(409, { error: "Ajukan permintaan berhenti ke yayasan" });
        if (by === "keluarga") return json(409, { error: "Gunakan Minta ganti pendamping (wajib alasan, maks. 1× per lansia)" });
        if (elder.pairing_state !== "berpasangan" || !elder.volunteer_id) {
          return json(409, { error: "Lansia ini sedang tidak berpasangan" });
        }
        await setElder(elder.id, { volunteer_id: null, pairing_state: "perlu_yayasan" });

        const text = {
          relawan: `${me?.full_name ?? "Relawan"} berhenti mendampingi ${elder.full_name}.`,
          keluarga: `Keluarga meminta ganti pendamping untuk ${elder.full_name}.`,
          yayasan: `Pengurus yayasan melepas pendamping ${elder.full_name}.`,
        }[by] + " Sistem mencarikan relawan pengganti secara otomatis.";
        try {
          await notify(admin, await recipientIds(admin, elder, { exclude: userId, category: "pendamping" }), {
            title: `Pendamping ${elder.full_name} berubah`,
            body: text,
            data: { elder_id: elder.id, type: "pendamping_dilepas" },
          });
        } catch (e) {
          console.error("push gagal", e); // pasangan tetap dilepas
        }
        return json(200, { ...(await rematch(admin, elder.id) ?? { pairing_state: "perlu_yayasan" }), by });
      }

      case "end": {
        const END_REASONS: Record<string, string> = {
          meninggal: "Lansia meninggal dunia",
          pindah: "Lansia pindah",
          tidak_butuh: "Tidak lagi membutuhkan pendamping",
          lainnya: "Lainnya",
        };
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        if (!(body.reason in END_REASONS)) return json(400, { error: "reason harus meninggal/pindah/tidak_butuh/lainnya" });
        const note = typeof body.note === "string" ? body.note.trim().slice(0, 200) : "";
        if (body.reason === "lainnya" && !note) return json(400, { error: "Alasan 'lainnya' wajib disertai teks" });
        const { data: elder } = await admin.from("elders")
          .select("id, full_name, family_id, foundation_id, volunteer_id, pairing_state")
          .eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id").eq("id", userId).single();
        // Mengakhiri pendampingan hanya pendaftar atau yayasan, bukan anggota keluarga lain (keputusan besar).
        const isFamily = elder.family_id === userId;
        const isFoundation = me?.role === "yayasan" && !!me.foundation_id && me.foundation_id === elder.foundation_id;
        if (!isFamily && !isFoundation) return json(403, { error: "Hanya keluarga atau yayasan lansia ini" });
        if (elder.pairing_state === "selesai") return json(409, { error: "Pendampingan sudah selesai" });

        await admin.from("proposals").delete().eq("elder_id", elder.id).eq("state", "pending");
        const reasonText = END_REASONS[body.reason] + (note ? `: ${note}` : "");
        await setElder(elder.id, {
          volunteer_id: null,
          pairing_state: "selesai",
          ended_reason: reasonText,
          ended_at: new Date().toISOString(),
        });
        try {
          const ids = await recipientIds(admin, elder, {
            extraIds: [elder.volunteer_id],
            exclude: userId,
            foundation: !isFoundation,
          });
          await notify(admin, ids, {
            title: `Pendampingan ${elder.full_name} selesai`,
            body: `${reasonText}. Terima kasih atas pendampingannya.`,
            data: { elder_id: elder.id, type: "selesai" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { pairing_state: "selesai" });
      }

      case "reopen": {
        // Membatalkan "selesai" (mis. salah ketuk): lansia kembali mencari relawan.
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        const { data: elder } = await admin.from("elders").select("id, family_id, foundation_id, pairing_state")
          .eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id").eq("id", userId).single();
        const allowed = elder.family_id === userId ||
          (me?.role === "yayasan" && !!me.foundation_id && me.foundation_id === elder.foundation_id);
        if (!allowed) return json(403, { error: "Hanya pendaftar atau yayasan lansia ini" });
        if (elder.pairing_state !== "selesai") return json(409, { error: "Pendampingan belum diakhiri" });
        await setElder(elder.id, { pairing_state: "mencari", ended_reason: null, ended_at: null });
        return json(200, { pairing_state: "mencari" });
      }

      case "change": {
        const REASONS: Record<string, string> = {
          jadwal: "Jadwal tidak cocok",
          tidak_cocok: "Kurang cocok dengan lansia",
          perbaikan: "Ada yang perlu diperbaiki",
          serius: "Masalah serius",
        };
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        if (!(body.reason in REASONS)) return json(400, { error: "Pilih alasan ganti" });
        const note = typeof body.note === "string" ? body.note.trim().slice(0, 300) : "";
        if (body.reason === "serius" && note.length < 3) return json(400, { error: "Ceritakan masalahnya untuk yayasan" });
        const { data: elder } = await admin.from("elders")
          .select(`${ELDER_COLS}, full_name, foundation_id, volunteer_id, paid_until`).eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        if (!(await familyIds(admin, elder)).includes(userId)) return json(403, { error: "Hanya keluarga lansia ini" });
        if (elder.pairing_state !== "berpasangan" || !elder.volunteer_id) {
          return json(409, { error: "Lansia ini sedang tidak didampingi" });
        }
        if (!elder.paid_until || new Date(elder.paid_until) < new Date()) {
          return json(402, { error: "Perpanjang langganan dulu sebelum mencari pengganti" });
        }
        // Keputusan pengguna 16 Okt: keluarga hanya bisa minta ganti satu kali per lansia.
        const { data: last } = await admin.from("pairing_changes").select("id").eq("elder_id", elder.id).limit(1).maybeSingle();
        if (last) {
          return json(429, {
            error: "Ganti pendamping hanya bisa sekali untuk lansia ini. Untuk masalah serius, kirim laporan ke yayasan.",
          });
        }
        const oldVol = elder.volunteer_id as string;
        const { error: insErr } = await admin.from("pairing_changes")
          .insert({ elder_id: elder.id, volunteer_id: oldVol, requested_by: userId, reason: body.reason, note: note || null });
        if (insErr) return json(500, { error: insErr.message });
        if (body.reason === "serius") {
          await admin.from("reviews").insert({ elder_id: elder.id, volunteer_id: oldVol, author_id: userId, kind: "serius", body: note });
        }
        await admin.from("stop_requests").update({ decided_at: new Date().toISOString(), decided_by: "Keluarga minta ganti" })
          .eq("elder_id", elder.id).is("decided_at", null);
        await setElder(elder.id, { volunteer_id: null, pairing_state: "mencari" });

        try {
          // Relawan lama: netral, tanpa alasan (melindungi keluarga).
          await notify(admin, [oldVol], {
            title: `Pendampingan ${elder.full_name} dialihkan`,
            body: "Keluarga memilih relawan lain. Terima kasih atas pendampingan Anda.",
            data: { type: "pendamping_dilepas" },
          });
          // Yayasan relawan lama: dengan alasan, untuk pembinaan.
          const { data: vol } = await admin.from("volunteers").select("foundation_id").eq("id", oldVol).single();
          const { data: admins } = await admin.from("profiles").select("id").eq("role", "yayasan")
            .eq("foundation_id", vol?.foundation_id);
          await notify(admin, (admins ?? []).map((a: { id: string }) => a.id), {
            title: `Keluarga ${elder.full_name} meminta ganti pendamping`,
            body: `Alasan: ${REASONS[body.reason]}${note ? ` — ${note}` : ""}`.slice(0, 200),
            data: { type: body.reason === "serius" ? "masukan_serius" : "ganti_pendamping" },
          });
          // Anggota keluarga lain.
          const others = (await familyIds(admin, elder)).filter((id) => id !== userId);
          await notify(admin, others, {
            title: `Pendamping ${elder.full_name} sedang diganti`,
            body: "Sistem mencarikan relawan baru; pendaftar meninjau usulannya.",
            data: { elder_id: elder.id, type: "ganti_pendamping" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { changed: true, ...(await proposeNext({ ...elder, pairing_state: "mencari" } as Elder)) });
      }

      case "request_stop": {
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 300) : "";
        if (reason.length < 3) return json(400, { error: "Tulis alasan berhenti" });
        const { data: elder } = await admin.from("elders").select("id, full_name, volunteer_id, foundation_id, pairing_state")
          .eq("id", body.elder_id).maybeSingle();
        if (!elder || elder.volunteer_id !== userId || elder.pairing_state !== "berpasangan") {
          return json(403, { error: "Hanya relawan pasangan lansia ini" });
        }
        const { error } = await admin.from("stop_requests").insert({ elder_id: elder.id, volunteer_id: userId, reason });
        if (error) return json(409, { error: "Permintaan berhenti untuk lansia ini sudah dikirim" });
        try {
          const { data: admins } = await admin.from("profiles").select("id").eq("role", "yayasan")
            .eq("foundation_id", elder.foundation_id);
          await notify(admin, (admins ?? []).map((a: { id: string }) => a.id), {
            title: `Relawan ingin berhenti mendampingi ${elder.full_name}`,
            body: `Alasan: ${reason}`.slice(0, 200) + ". Otomatis diterima dalam 7 hari bila tidak ditanggapi.",
            data: { elder_id: elder.id, type: "permintaan_berhenti" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { requested: true });
      }

      case "approve_stop": {
        if (!isId(body.request_id)) return json(400, { error: "request_id harus uuid" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id, full_name").eq("id", userId).single();
        const { data: req } = await admin.from("stop_requests").select("id, volunteers(foundation_id)")
          .eq("id", body.request_id).maybeSingle();
        const f = (req?.volunteers as unknown as { foundation_id: string } | null)?.foundation_id;
        if (!req || me?.role !== "yayasan" || !f || me.foundation_id !== f) {
          return json(403, { error: "Hanya pengurus yayasan relawan ini" });
        }
        if (!(await approveStop(admin, req.id, me.full_name ?? "Pengurus yayasan"))) {
          return json(409, { error: "Permintaan sudah diputuskan" });
        }
        await rematchReleased(admin); // lansianya langsung mendapat usulan relawan pengganti
        return json(200, { approved: true });
      }

      case "deactivate": {
        // Mencabut kedua centang: trigger volunteers_checks mengembalikan lansia pasangannya ke yayasan.
        if (!isId(body.volunteer_id)) return json(400, { error: "volunteer_id harus uuid" });
        const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 300) : "";
        if (reason.length < 3) return json(400, { error: "Tulis alasan penonaktifan" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id").eq("id", userId).single();
        const { data: vol } = await admin.from("volunteers").select("id, foundation_id, status")
          .eq("id", body.volunteer_id).maybeSingle();
        if (!vol || me?.role !== "yayasan" || me.foundation_id !== vol.foundation_id) {
          return json(403, { error: "Hanya pengurus yayasan relawan ini" });
        }
        if (vol.status !== "aktif") return json(409, { error: "Relawan ini tidak aktif" });
        const { data: paired } = await admin.from("elders").select("id, full_name, family_id, foundation_id")
          .eq("volunteer_id", vol.id).eq("pairing_state", "berpasangan");
        const { error } = await admin.from("volunteers")
          .update({
            id_checked_by: null,
            oriented_by: null,
            status_note: `Dinonaktifkan yayasan: ${reason}`,
            resign_reason: null,
            resign_requested_at: null,
          })
          .eq("id", vol.id);
        if (error) return json(500, { error: error.message });
        await admin.from("stop_requests").update({ decided_at: new Date().toISOString(), decided_by: "Relawan dinonaktifkan" })
          .eq("volunteer_id", vol.id).is("decided_at", null);
        try {
          for (const e of paired ?? []) {
            await notify(admin, await recipientIds(admin, e, { foundation: false, category: "pendamping" }), {
              title: `Pendamping ${e.full_name} berganti`,
              body: "Sistem sedang mencarikan relawan pengganti.",
              data: { elder_id: e.id, type: "pendamping_dilepas" },
            });
          }
          await notify(admin, [vol.id], {
            title: "Status relawan Anda dinonaktifkan",
            body: `Alasan: ${reason}`.slice(0, 200),
            data: { type: "relawan_nonaktif" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        await rematchReleased(admin);
        return json(200, { deactivated: true, released: (paired ?? []).length });
      }

      case "resign": {
        // Lansia tidak boleh tiba-tiba tanpa pendamping: setiap lansia pasangan masuk alur permintaan berhenti
        // (diterima yayasan / otomatis 7 hari). Yayasan menuntaskan pengunduran diri dengan "Nonaktifkan".
        const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 300) : "";
        if (reason.length < 3) return json(400, { error: "Tulis alasan pengunduran diri" });
        const { data: vol } = await admin.from("volunteers").select("id, foundation_id, resign_requested_at")
          .eq("id", userId).maybeSingle();
        if (!vol) return json(403, { error: "Khusus relawan" });
        if (vol.resign_requested_at) return json(409, { error: "Pengunduran diri sudah diajukan" });
        const { error } = await admin.from("volunteers").update({
          resign_reason: reason,
          resign_requested_at: new Date().toISOString(),
          status_note: `Mengajukan pengunduran diri: ${reason}`.slice(0, 300),
        }).eq("id", userId);
        if (error) return json(500, { error: error.message });
        const { data: paired } = await admin.from("elders").select("id").eq("volunteer_id", userId)
          .eq("pairing_state", "berpasangan");
        const { data: pending } = await admin.from("stop_requests").select("elder_id").eq("volunteer_id", userId)
          .is("decided_at", null);
        const skip = new Set((pending ?? []).map((p: { elder_id: string }) => p.elder_id));
        const rows = (paired ?? []).filter((e: { id: string }) => !skip.has(e.id))
          .map((e: { id: string }) => ({ elder_id: e.id, volunteer_id: userId, reason: `Mengundurkan diri: ${reason}`.slice(0, 300) }));
        if (rows.length) await admin.from("stop_requests").insert(rows);
        try {
          const { data: admins } = await admin.from("profiles").select("id").eq("role", "yayasan")
            .eq("foundation_id", vol.foundation_id);
          await notify(admin, (admins ?? []).map((a: { id: string }) => a.id), {
            title: "Relawan mengajukan pengunduran diri",
            body: `Alasan: ${reason}`.slice(0, 200) + ". Carikan pengganti untuk lansianya, lalu nonaktifkan relawan.",
            data: { type: "relawan_mundur" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { resigned: true, stop_requests: rows.length });
      }

      case "schedule_propose":
      case "schedule_answer":
      case "schedule_shift": {
        // Jadwal kunjungan rutin (keputusan pengguna 16 Okt): relawan usul, keluarga setuju; relawan bisa menggeser
        // satu kunjungan. Kolom jadwal tidak di-grant ke klien, jadi hanya lewat sini.
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        const { data: elder } = await admin.from("elders")
          .select("id, full_name, family_id, foundation_id, volunteer_id, pairing_state, schedule_status, schedule_weekday, schedule_time")
          .eq("id", body.elder_id).maybeSingle();
        if (!elder || elder.pairing_state !== "berpasangan" || !elder.volunteer_id) {
          return json(409, { error: "Lansia ini sedang tidak didampingi" });
        }
        const DAYS = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
        if (body.action === "schedule_answer") {
          if (!(await familyIds(admin, elder)).includes(userId)) return json(403, { error: "Hanya keluarga lansia ini" });
          if (elder.schedule_status !== "diusulkan") return json(409, { error: "Tidak ada usulan jadwal" });
          const approve = body.approve === true;
          await setElder(elder.id, approve
            ? { schedule_status: "disetujui", schedule_shift_at: null }
            : { schedule_status: null, schedule_weekday: null, schedule_time: null, schedule_shift_at: null });
          try {
            await notify(admin, [elder.volunteer_id], {
              title: approve ? `Jadwal ${elder.full_name} disetujui` : `Usulan jadwal ${elder.full_name} ditolak`,
              body: approve
                ? `Tiap ${DAYS[elder.schedule_weekday - 1]} ${String(elder.schedule_time).slice(0, 5)}. Pengingat dikirim sehari sebelumnya.`
                : "Keluarga meminta waktu lain. Usulkan jadwal baru dari beranda.",
              data: { elder_id: elder.id, type: "jadwal" },
            });
          } catch (e) {
            console.error("push gagal", e);
          }
          return json(200, { schedule_status: approve ? "disetujui" : null });
        }
        if (elder.volunteer_id !== userId) return json(403, { error: "Hanya relawan pasangan lansia ini" });
        let msg: { title: string; body: string };
        if (body.action === "schedule_propose") {
          const err = checkSchedule(body.weekday, body.time);
          if (err) return json(400, { error: err });
          await setElder(elder.id, {
            schedule_weekday: body.weekday,
            schedule_time: body.time,
            schedule_status: "diusulkan",
            schedule_shift_at: null,
          });
          msg = {
            title: `Usulan jadwal kunjungan ${elder.full_name}`,
            body: `Relawan mengusulkan tiap ${DAYS[body.weekday - 1]} ${body.time}. Buka aplikasi untuk menyetujui.`,
          };
        } else {
          if (elder.schedule_status !== "disetujui") return json(409, { error: "Jadwal rutin belum disetujui keluarga" });
          const err = checkShift(body.at);
          if (err) return json(400, { error: err });
          await setElder(elder.id, { schedule_shift_at: body.at });
          const t = new Date(new Date(body.at).getTime() + 7 * 3600_000); // tampil dalam WIB
          msg = {
            title: `Kunjungan ${elder.full_name} digeser`,
            body: `Kunjungan minggu ini menjadi ${DAYS[(t.getUTCDay() + 6) % 7]} ${t.getUTCDate()}/${t.getUTCMonth() + 1} pukul ${
              String(t.getUTCHours()).padStart(2, "0")}.${String(t.getUTCMinutes()).padStart(2, "0")}.`,
          };
        }
        try {
          await notify(admin, await recipientIds(admin, elder, { foundation: false, category: "pendamping" }), {
            ...msg,
            data: { elder_id: elder.id, type: "jadwal" },
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { ok: true });
      }

      case "delete": {
        // Hak penghapusan (UU PDP): hanya pendaftar. Profil kesehatan, kunjungan, darurat, usulan, dan anggota
        // keluarga ikut terhapus (on delete cascade). Penerima dihitung sebelum data anggota hilang.
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        if (body.confirm !== "HAPUS") return json(400, { error: "Ketik HAPUS untuk mengonfirmasi" });
        const { data: elder } = await admin.from("elders")
          .select("id, full_name, family_id, foundation_id, volunteer_id").eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        if (elder.family_id !== userId) return json(403, { error: "Hanya keluarga yang mendaftarkan lansia ini" });
        const ids = await recipientIds(admin, elder, { extraIds: [elder.volunteer_id], exclude: userId })
          .catch(() => [] as string[]);
        const { error } = await admin.from("elders").delete().eq("id", elder.id);
        if (error) return json(500, { error: error.message });
        try {
          await notify(admin, ids, {
            title: `Data ${elder.full_name} dihapus`,
            body: "Keluarga menghapus data lansia ini dari ReLa. Pendampingan berakhir.",
            data: { type: "dihapus" }, // tanpa elder_id: datanya sudah tidak ada
          });
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { deleted: true });
      }

      case "verify": {
        // Verifikasi online oleh pengurus yayasan lansia ini. Dokumen dihapus setelah diputuskan (data minimal);
        // yang disimpan hanya siapa dan kapan.
        if (!isId(body.elder_id)) return json(400, { error: "elder_id harus uuid" });
        if (typeof body.approve !== "boolean") return json(400, { error: "approve harus true/false" });
        const note = typeof body.note === "string" ? body.note.trim().slice(0, 300) : "";
        if (!body.approve && !note) return json(400, { error: "Tulis alasan penolakan untuk keluarga" });
        const { data: me } = await admin.from("profiles").select("role, foundation_id").eq("id", userId).single();
        const { data: elder } = await admin.from("elders")
          .select("id, full_name, family_id, foundation_id, volunteer_id, verify_state").eq("id", body.elder_id).maybeSingle();
        if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
        if (me?.role !== "yayasan" || !me.foundation_id || me.foundation_id !== elder.foundation_id) {
          return json(403, { error: "Hanya pengurus yayasan lansia ini" });
        }
        if (elder.verify_state !== "menunggu") return json(409, { error: "Tidak ada dokumen yang menunggu diperiksa" });
        await setElder(elder.id, {
          verify_state: body.approve ? "terverifikasi" : "ditolak",
          verify_note: body.approve ? null : note,
          verified_by: body.approve ? userId : null,
          verified_at: body.approve ? new Date().toISOString() : null,
        });
        await admin.storage.from("elder-docs").remove(
          ["ktp_keluarga", "ktp_lansia", "kk"].map((k) => `${elder.id}/${k}.jpg`),
        );
        try {
          const family = await recipientIds(admin, elder, { foundation: false, category: "pendamping" });
          await notify(admin, family, body.approve
            ? { title: `Verifikasi ${elder.full_name} selesai`, body: "Kontak lengkap relawan sudah bisa dilihat.",
                data: { elder_id: elder.id, type: "verifikasi" } }
            : { title: `Dokumen ${elder.full_name} ditolak`, body: `${note}. Silakan unggah ulang.`.slice(0, 200),
                data: { elder_id: elder.id, type: "verifikasi" } });
          if (body.approve && elder.volunteer_id) {
            await notify(admin, [elder.volunteer_id], {
              title: `Keluarga ${elder.full_name} terverifikasi`,
              body: "Anda bisa mulai berkunjung. Pastikan lansia setuju saat kunjungan pertama.",
              data: { elder_id: elder.id, type: "verifikasi" },
            });
          }
        } catch (e) {
          console.error("push gagal", e);
        }
        return json(200, { verify_state: body.approve ? "terverifikasi" : "ditolak" });
      }

      default:
        return json(400, {
          error: "action harus propose/accept/reject/manual/release/end/reopen/delete/verify/request_stop/approve_stop/deactivate/resign/schedule_*",
        });
    }
  } catch (e) {
    console.error(e);
    return json(500, { error: "Terjadi kesalahan di server" });
  }
});
