// Edge Function `emergency` (Alur C, PRD F8): relawan menekan tombol Darurat saat bersama lansia.
// Body: {elder_id, lat?, lng?}. Simpan kejadian, kirim push ke keluarga + pengurus yayasan, kembalikan
// Profil Kesehatan Ringkas untuk dibacakan ke operator 119 (panggilannya disimulasikan di aplikasi).
import { createClient } from "npm:@supabase/supabase-js@2";
import { notify, recipientIds } from "../_shared/recipients.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const coord = (v: unknown, max: number) => typeof v === "number" && Number.isFinite(v) && Math.abs(v) <= max;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Gunakan POST" });

  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ?? "";
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json(401, { error: "Belum login" });

  const body = await req.json().catch(() => null);
  const { elder_id, lat, lng } = body ?? {};
  if (typeof elder_id !== "string" || !UUID.test(elder_id)) return json(400, { error: "elder_id harus uuid" });
  // Lokasi boleh kosong (GPS gagal tidak boleh menahan keadaan darurat), tapi kalau ada harus valid.
  const hasLoc = lat != null || lng != null;
  if (hasLoc && !(coord(lat, 90) && coord(lng, 180))) return json(400, { error: "lat/lng tidak valid" });

  const { data: elder } = await admin.from("elders")
    .select("id, full_name, family_id, foundation_id, volunteer_id").eq("id", elder_id).maybeSingle();
  if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
  if (elder.volunteer_id !== auth.user.id) return json(403, { error: "Hanya relawan pasangan lansia ini" });

  // Tekan berulang dalam 2 menit: kejadian dan notifikasi tidak digandakan, profil kesehatan tetap dikembalikan.
  const since = new Date(Date.now() - 2 * 60_000).toISOString();
  const { data: recent } = await admin.from("emergencies").select("id, notified").eq("elder_id", elder_id)
    .gte("created_at", since).order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (recent) {
    const { data: health } = await admin.from("health_profiles").select("*").eq("elder_id", elder_id).maybeSingle();
    return json(200, { emergency_id: recent.id, notified: recent.notified, duplicate: true, maps_url: null, health });
  }

  const [{ data: health }, { data: me }] = await Promise.all([
    admin.from("health_profiles").select("*").eq("elder_id", elder_id).maybeSingle(),
    admin.from("profiles").select("full_name").eq("id", auth.user.id).single(),
  ]);

  const maps = hasLoc ? `https://maps.google.com/?q=${lat},${lng}` : null;
  const summary = `${me?.full_name ?? "Relawan"} menekan tombol Darurat saat mendampingi ${elder.full_name}. ` +
    "Panggilan 119 disimulasikan dari aplikasi relawan.";

  const { data: ev, error: insErr } = await admin.from("emergencies")
    .insert({ elder_id, volunteer_id: auth.user.id, lat: hasLoc ? lat : null, lng: hasLoc ? lng : null, summary })
    .select("id").single();
  if (insErr) return json(500, { error: insErr.message });

  // Gagal kirim push tidak membatalkan kejadian: sudah tersimpan dan terlihat di riwayat keluarga.
  let notified = false;
  try {
    const push = await notify(admin, await recipientIds(admin, elder), {
      title: `DARURAT: ${elder.full_name}`,
      body: `${summary}${maps ? ` Lokasi: ${maps}` : " Lokasi tidak tersedia."}`.slice(0, 300),
      data: { elder_id, type: "darurat", ...(maps ? { maps_url: maps } : {}) },
    });
    notified = push.sent > 0;
    if (notified) await admin.from("emergencies").update({ notified }).eq("id", ev.id);
    console.log("push darurat", push);
  } catch (e) {
    console.error("push gagal", e);
  }

  return json(200, { emergency_id: ev.id, notified, maps_url: maps, health });
});
