// Edge Function `reminders` (E8): dipanggil pg_cron setiap hari 08.00 WIB. Lansia berpasangan yang lebih dari
// 7 hari tidak dikunjungi → push ke relawan setiap hari; keluarga dan yayasan hanya tiap kelipatan 7 hari (hari ke-7,
// 14, …) supaya tidak menjadi notifikasi harian yang diabaikan.
// Di-deploy dengan --no-verify-jwt; pemanggil dikenali lewat header x-cron-secret (disimpan di Vault).
import { createClient } from "npm:@supabase/supabase-js@2";
import { notify, recipientIds } from "../_shared/recipients.ts";
import { rematchReleased } from "../_shared/propose.ts";
import { nextVisit, wibDate } from "../_shared/schedule.ts";
import { approveStop } from "../_shared/stop.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const SECRET = Deno.env.get("REMINDERS_CRON_SECRET") ?? "";
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (!SECRET || req.headers.get("x-cron-secret") !== SECRET) return json(401, { error: "Tidak berhak" });

  const { data: due, error } = await admin.rpc("due_visit_reminders");
  if (error) return json(500, { error: error.message });

  let sent = 0;
  for (const e of due ?? []) {
    try {
      const everyone = e.days % 7 === 0;
      const ids = everyone
        ? await recipientIds(admin, e, { extraIds: [e.volunteer_id], category: "pengingat" })
        : [e.volunteer_id];
      const push = await notify(admin, ids, {
        title: `Sudah ${e.days} hari belum dikunjungi: ${e.full_name}`,
        body: "Relawan: jadwalkan kunjungan. Keluarga/yayasan: hubungi relawan bila perlu.",
        data: { elder_id: e.id, type: "pengingat_kunjungan" },
      });
      sent += push.sent;
    } catch (err) {
      console.error("push gagal", e.id, err);
    }
  }
  // Langganan: diingatkan 3 hari sebelum berakhir dan pada hari berakhir (job jalan sekali sehari, jendela 24 jam).
  const day = 86400_000, now = Date.now();
  let billing = 0;
  for (const [from, to, msg] of [
    [now + 2 * day, now + 3 * day, "berakhir dalam 3 hari"],
    [now - day, now, "berakhir hari ini. Pendampingan tetap berjalan 7 hari lagi"],
  ] as const) {
    const { data: rows } = await admin.from("elders").select("id, full_name, family_id")
      .neq("pairing_state", "selesai").gte("paid_until", new Date(from).toISOString()).lt("paid_until", new Date(to).toISOString());
    for (const e of rows ?? []) {
      try {
        const push = await notify(admin, await recipientIds(admin, e, { foundation: false, category: "pengingat" }), {
          title: `Langganan ${e.full_name} ${msg.split(".")[0]}`,
          body: `Langganan ${msg}. Perpanjang dari halaman detail lansia.`,
          data: { elder_id: e.id, type: "langganan" },
        });
        billing += push.sent;
      } catch (err) {
        console.error("push langganan gagal", e.id, err);
      }
    }
  }
  // Jadwal rutin: pengingat sehari sebelum kunjungan ke relawan dan keluarga (job jalan 08.00 WIB).
  let scheduled = 0;
  const { data: sched } = await admin.from("elders").select("id, full_name, family_id, foundation_id, volunteer_id, schedule_weekday, schedule_time, schedule_shift_at")
    .eq("pairing_state", "berpasangan").eq("schedule_status", "disetujui");
  const tomorrow = wibDate(new Date(now + day));
  for (const e of sched ?? []) {
    const at = nextVisit(e.schedule_weekday, e.schedule_time, e.schedule_shift_at, new Date(now));
    if (wibDate(at) !== tomorrow) continue;
    try {
      const wib = new Date(at.getTime() + 7 * 3600_000);
      const jam = `${String(wib.getUTCHours()).padStart(2, "0")}.${String(wib.getUTCMinutes()).padStart(2, "0")}`;
      const push = await notify(admin, await recipientIds(admin, e, { extraIds: [e.volunteer_id], foundation: false, category: "pengingat" }), {
        title: `Besok kunjungan ${e.full_name}`,
        body: `Jadwal kunjungan relawan besok pukul ${jam}.`,
        data: { elder_id: e.id, type: "jadwal" },
      });
      scheduled += push.sent;
    } catch (err) {
      console.error("push jadwal gagal", e.id, err);
    }
  }
  // Permintaan berhenti relawan yang 7 hari tidak ditanggapi yayasan: otomatis diterima.
  const { data: stale } = await admin.from("stop_requests").select("id").is("decided_at", null)
    .lt("created_at", new Date(now - 7 * day).toISOString());
  let autoStops = 0;
  for (const r of stale ?? []) if (await approveStop(admin, r.id, "Otomatis (7 hari tanpa tanggapan)")) autoStops++;
  // Lansia yang kehilangan relawan (termasuk jalur di luar Edge Function, mis. relawan mencabut keahlian) atau
  // belum mendapat relawan dicocokkan ulang otomatis.
  const rematched = await rematchReleased(admin);
  return json(200, { elders: (due ?? []).length, sent, billing, autoStops, rematched, scheduled });
});
