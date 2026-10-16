// Edge Function `account`: menghapus akun sendiri beserta datanya (hak penghapusan, UU PDP).
// Body: {action: "delete", confirm: "HAPUS"}.
// - relawan: lansia pasangannya dicocokkan ulang otomatis, usulan pending dibatalkan, foto dihapus; riwayat kunjungan
//   tetap milik lansia (kolom relawan dikosongkan, migration 001000).
// - keluarga: lansia yang juga dipantau anggota lain pindah ke anggota itu; selain itu ikut terhapus (cascade).
// - yayasan: tidak bisa (akun yayasan dikelola platform).
import { createClient } from "npm:@supabase/supabase-js@2";
import { rematchReleased } from "../_shared/propose.ts";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Gunakan POST" });
  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ?? "";
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json(401, { error: "Belum login" });
  const uid = auth.user.id;

  const body = await req.json().catch(() => null) ?? {};
  if (body.action !== "delete" || body.confirm !== "HAPUS") {
    return json(400, { error: 'Kirim {action: "delete", confirm: "HAPUS"}' });
  }
  const { data: me } = await admin.from("profiles").select("role").eq("id", uid).single();
  if (me?.role === "yayasan") return json(403, { error: "Akun yayasan dihapus lewat pengelola platform" });

  try {
    if (me?.role === "relawan") {
      await admin.from("elders").update({ volunteer_id: null, pairing_state: "perlu_yayasan" })
        .eq("volunteer_id", uid).eq("pairing_state", "berpasangan");
      const { data: pending } = await admin.from("proposals").select("elder_id")
        .eq("volunteer_id", uid).eq("state", "pending");
      if (pending?.length) {
        await admin.from("elders").update({ pairing_state: "mencari" }).in("id", pending.map((p) => p.elder_id));
      }
      const { data: files } = await admin.storage.from("volunteer-photos").list(uid);
      if (files?.length) await admin.storage.from("volunteer-photos").remove(files.map((f) => `${uid}/${f.name}`));
    }
    if (me?.role === "keluarga") {
      // Lansia yang juga dipantau anggota keluarga lain tidak ikut terhapus: kepemilikan pindah ke anggota
      // yang paling lama bergabung. Lansia tanpa anggota lain ikut terhapus (cascade).
      const { data: owned } = await admin.from("elders").select("id").eq("family_id", uid);
      for (const e of owned ?? []) {
        const { data: heir } = await admin.from("family_members").select("profile_id").eq("elder_id", e.id)
          .not("accepted_at", "is", null).order("accepted_at").limit(1).maybeSingle();
        if (heir) {
          await admin.from("elders").update({ family_id: heir.profile_id }).eq("id", e.id);
          await admin.from("family_members").delete().eq("elder_id", e.id).eq("profile_id", heir.profile_id);
        }
      }
    }
    const { error } = await admin.auth.admin.deleteUser(uid); // cascade: profiles → volunteers/elders → ...
    if (error) throw error;
    if (me?.role === "relawan") await rematchReleased(admin); // setelah akunnya hilang, jadi tidak diusulkan lagi
    return json(200, { deleted: true });
  } catch (e) {
    console.error(e);
    return json(500, { error: "Gagal menghapus akun" });
  }
});
