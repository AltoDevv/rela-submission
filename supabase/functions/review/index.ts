// Edge Function `review`: keluarga memberi masukan tentang relawan pendamping (bukan bintang).
// Body: {elder_id, kind: "apresiasi" | "perbaikan" | "serius", body}
// Siapa: pendaftar atau anggota keluarga yang sudah menerima undangan. Relawan yang dinilai = pendamping saat ini,
// atau pendamping terakhir yang pernah berkunjung (ulasan penutup setelah ganti/akhiri).
// Batas: apresiasi/perbaikan maks. 1 per 7 hari per orang per lansia; "serius" tidak dibatasi.
import { createClient } from "npm:@supabase/supabase-js@2";
import { familyIds, notify } from "../_shared/recipients.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KINDS = ["apresiasi", "perbaikan", "serius"];
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Gunakan POST" });
  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ?? "";
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json(401, { error: "Belum login" });
  const userId = auth.user.id;

  const b = await req.json().catch(() => null);
  const text = typeof b?.body === "string" ? b.body.trim() : "";
  if (typeof b?.elder_id !== "string" || !UUID.test(b.elder_id)) return json(400, { error: "elder_id harus uuid" });
  if (!KINDS.includes(b?.kind)) return json(400, { error: "kind harus apresiasi/perbaikan/serius" });
  if (text.length < 3 || text.length > 500) return json(400, { error: "Tulis masukan 3–500 karakter" });

  const { data: elder } = await admin.from("elders").select("id, full_name, family_id, volunteer_id")
    .eq("id", b.elder_id).maybeSingle();
  if (!elder) return json(404, { error: "Lansia tidak ditemukan" });
  if (!(await familyIds(admin, elder)).includes(userId)) return json(403, { error: "Hanya keluarga lansia ini" });

  let volunteerId: string | null = elder.volunteer_id;
  if (!volunteerId) {
    const { data: last } = await admin.from("visits").select("volunteer_id").eq("elder_id", elder.id)
      .not("volunteer_id", "is", null).order("visited_at", { ascending: false }).limit(1).maybeSingle();
    volunteerId = last?.volunteer_id ?? null;
  }
  if (!volunteerId) return json(409, { error: "Belum ada relawan yang mendampingi lansia ini" });

  if (b.kind !== "serius") {
    const since = new Date(Date.now() - 7 * 86400_000).toISOString();
    const { count } = await admin.from("reviews").select("id", { count: "exact", head: true })
      .eq("elder_id", elder.id).eq("author_id", userId).neq("kind", "serius").gte("created_at", since);
    if ((count ?? 0) > 0) {
      return json(429, { error: "Masukan biasa maksimal sekali seminggu. Untuk masalah serius pilih \"Ada masalah serius\"." });
    }
  }

  const { data: row, error } = await admin.from("reviews")
    .insert({ elder_id: elder.id, volunteer_id: volunteerId, author_id: userId, kind: b.kind, body: text })
    .select("id").single();
  if (error) return json(500, { error: error.message });

  try {
    const { data: vol } = await admin.from("volunteers").select("foundation_id, profiles(full_name)")
      .eq("id", volunteerId).single();
    const volName = (vol?.profiles as unknown as { full_name: string } | null)?.full_name ?? "relawan";
    const { data: admins } = await admin.from("profiles").select("id").eq("role", "yayasan")
      .eq("foundation_id", vol?.foundation_id);
    const adminIds = (admins ?? []).map((a: { id: string }) => a.id);
    if (b.kind === "serius") {
      await notify(admin, adminIds, {
        title: `Laporan serius tentang ${volName}`,
        body: `Keluarga ${elder.full_name} melaporkan masalah. Segera tindak lanjuti.`,
        data: { type: "masukan_serius" },
      });
    } else if (b.kind === "perbaikan") {
      await notify(admin, adminIds, {
        title: `Masukan untuk ${volName}`,
        body: `Keluarga ${elder.full_name} memberi masukan perbaikan.`,
        data: { type: "masukan" },
      });
    } else {
      await notify(admin, [volunteerId], {
        title: "Ada ucapan terima kasih untuk Anda",
        body: `Dari keluarga ${elder.full_name}.`,
        data: { type: "apresiasi" },
      });
    }
  } catch (e) {
    console.error("push gagal", e);
  }
  return json(200, { id: row.id });
});
