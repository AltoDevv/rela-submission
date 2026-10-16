// Cek T-007: RLS dan constraint skema inti (architecture.md bagian 6).
// Butuh seed 01 dan 02. Jalankan dari root: deno run -A scripts/check_rls.ts
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const env = Object.fromEntries(
  Deno.readTextFileSync(".env.local").split("\n")
    .filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, "")]),
);
const opts = { auth: { persistSession: false } };
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, opts);

const FOUNDATION = "f0000000-0000-0000-0000-000000000001";
const PENGURUS = "a0000000-0000-0000-0000-000000000001";
const KELUARGA1 = "b0000000-0000-0000-0000-000000000001";
const KELUARGA2 = "b0000000-0000-0000-0000-000000000002";
const R = (n: number) => `c0000000-0000-0000-0000-00000000000${n}`;
const SRI = "e0000000-0000-0000-0000-000000000001";
const HARJO = "e0000000-0000-0000-0000-000000000002";

let failed = 0;
function check(name: string, ok: boolean, detail = "") {
  console.log(`${ok ? "LULUS" : "GAGAL"}  ${name}${ok || !detail ? "" : `  (${detail})`}`);
  if (!ok) failed++;
}

async function login(email: string): Promise<SupabaseClient> {
  const c = createClient(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY, opts);
  const { error } = await c.auth.signInWithPassword({ email, password: "demo1234" });
  if (error) throw new Error(`login ${email}: ${error.message}`);
  return c;
}

async function ids(c: SupabaseClient, table: string, col = "id"): Promise<string[]> {
  const { data, error } = await c.from(table).select(col);
  if (error) return [`ERROR ${error.message}`];
  return (data as unknown as Record<string, string>[]).map((r) => r[col]);
}

const k1 = await login("keluarga1@demo.id");
const k2 = await login("keluarga2@demo.id");
const r1 = await login("relawan1@demo.id");
const r2 = await login("relawan2@demo.id");
const r3 = await login("relawan3@demo.id");
const r5 = await login("relawan5@demo.id");
const yay = await login("pengurus@demo.id");

// Data sementara untuk uji, dihapus di akhir.
const { data: prop, error: propErr } = await admin.from("proposals").insert({
  elder_id: HARJO, volunteer_id: R(3), attempt: 1, distance_km: 2.1, reason_text: "uji", state: "pending",
}).select("id").single();
if (propErr) throw propErr;
const { data: emg, error: emgErr } = await admin.from("emergencies")
  .insert({ elder_id: SRI, volunteer_id: R(1), lat: -7.77, lng: 110.38, summary: "uji" }).select("id").single();
if (emgErr) throw emgErr;
const cleanup: (() => Promise<unknown>)[] = [
  () => admin.from("proposals").delete().eq("id", prop.id),
  () => admin.from("emergencies").delete().eq("id", emg.id),
];

try {
  // --- elders
  check("keluarga1 hanya melihat Ibu Sri", JSON.stringify(await ids(k1, "elders")) === JSON.stringify([SRI]));
  check("keluarga2 tidak melihat Ibu Sri", JSON.stringify(await ids(k2, "elders")) === JSON.stringify([HARJO]));
  check("relawan1 (pasangan) hanya melihat Ibu Sri", JSON.stringify(await ids(r1, "elders")) === JSON.stringify([SRI]));
  check("relawan2 tidak melihat lansia mana pun", (await ids(r2, "elders")).length === 0);
  check("yayasan melihat Ibu Sri (yayasannya)", (await ids(yay, "elders")).includes(SRI));
  await admin.from("elders").update({ pairing_state: "perlu_yayasan" }).eq("id", HARJO);
  // E2: lansia tanpa yayasan tidak terbaca langsung (alamat/koordinat); dashboard & manual_pair_options tetap ada.
  check("yayasan tidak membaca langsung lansia perlu_yayasan tanpa yayasan", !(await ids(yay, "elders")).includes(HARJO));
  {
    const dash = (await yay.rpc("foundation_dashboard")).data;
    const mp = (await yay.rpc("manual_pair_options", { p_elder_id: HARJO })).data;
    check("lansia perlu_yayasan muncul di dashboard dan bisa dipasang manual (jarak dari server)",
      dash?.elders?.some((e: { id: string }) => e.id === HARJO) && mp?.elder?.id === HARJO &&
        mp.volunteers.some((v: { km: number | null }) => typeof v.km === "number"), JSON.stringify(mp?.volunteers?.[0]));
  }
  await admin.from("elders").update({ pairing_state: "mencari" }).eq("id", HARJO);
  check("yayasan tidak melihat lansia mencari di luar yayasannya", !(await ids(yay, "elders")).includes(HARJO));

  {
    const { data, error } = await k1.from("elders").insert({
      family_id: KELUARGA1, full_name: "Uji", address: "Jl. Uji", lat: -7.78, lng: 110.37,
      has_dementia: false, has_mobility_issue: false, consent_type: "lansia",
    }).select("id, pairing_state, status, consent_by, consent_at").single();
    check("keluarga mendaftarkan lansia (default mencari, stabil)",
      !error && data?.pairing_state === "mencari" && data?.status === "stabil", error?.message);
    check("persetujuan dicatat server: oleh siapa dan kapan", data?.consent_by === KELUARGA1 && !!data?.consent_at, JSON.stringify(data));
    if (data) cleanup.push(() => admin.from("elders").delete().eq("id", data.id));
  }
  {
    const { error } = await k1.from("elders").insert({ family_id: KELUARGA1, full_name: "Uji", address: "x" });
    check("mendaftarkan lansia tanpa persetujuan lansia/wali ditolak", !!error);
  }
  {
    const { error } = await k1.from("elders").insert({ family_id: KELUARGA2, full_name: "Uji", address: "x", consent_type: "lansia" });
    check("keluarga tidak bisa mendaftarkan lansia atas nama keluarga lain", !!error);
  }
  {
    const { error } = await k1.from("elders").insert({ family_id: KELUARGA1, full_name: "Uji", address: "x", volunteer_id: R(1), consent_type: "lansia" });
    check("keluarga tidak bisa mengisi volunteer_id sendiri", !!error);
  }
  {
    const { error } = await k1.from("elders").update({ status: "stabil" }).eq("id", SRI);
    check("keluarga tidak bisa mengubah status lansia", !!error);
  }

  // --- health_profiles
  check("keluarga1 membaca profil kesehatan Ibu Sri", JSON.stringify(await ids(k1, "health_profiles", "elder_id")) === JSON.stringify([SRI]));
  check("relawan1 membaca profil kesehatan Ibu Sri", JSON.stringify(await ids(r1, "health_profiles", "elder_id")) === JSON.stringify([SRI]));
  check("yayasan membaca health_profiles → 0 baris", (await ids(yay, "health_profiles", "elder_id")).length === 0);
  check("relawan2 membaca health_profiles → 0 baris", (await ids(r2, "health_profiles", "elder_id")).length === 0);
  check("keluarga2 tidak membaca profil Ibu Sri", !(await ids(k2, "health_profiles", "elder_id")).includes(SRI));

  // --- proposals
  check("relawan membaca proposals → 0 baris (relawan3 yang diusulkan)", (await ids(r3, "proposals")).length === 0);
  check("keluarga2 melihat usulan lansianya", (await ids(k2, "proposals")).includes(prop.id));
  check("keluarga1 tidak melihat usulan lansia lain", (await ids(k1, "proposals")).length === 0);
  check("yayasan melihat usulan relawan yayasannya", (await ids(yay, "proposals")).includes(prop.id));
  {
    const { error } = await k2.from("proposals").update({ state: "accepted" }).eq("id", prop.id);
    const { data } = await admin.from("proposals").select("state").eq("id", prop.id).single();
    check("keluarga tidak bisa mengubah proposal langsung", !!error || data?.state === "pending");
  }

  // --- visits
  {
    const { data, error } = await r1.from("visits").insert({ elder_id: SRI, volunteer_id: R(1), answers: { makan: "uji" } })
      .select("id").single();
    check("relawan1 menulis kunjungan Ibu Sri", !error, error?.message);
    if (data) cleanup.push(() => admin.from("visits").delete().eq("id", data.id));
    const { error: e2 } = await r2.from("visits").insert({ elder_id: SRI, volunteer_id: R(2), answers: {} });
    check("relawan2 tidak bisa menulis kunjungan Ibu Sri", !!e2);
    // Hasil AI, konfirmasi, dan tanggal hanya boleh diisi server (Edge Function visit).
    const { error: e3 } = await r1.from("visits")
      .insert({ elder_id: SRI, volunteer_id: R(1), answers: {}, final_result: {}, confirmed_at: new Date().toISOString() });
    check("relawan tidak bisa membuat kunjungan 'terkonfirmasi' sendiri", !!e3);
    if (data) {
      await r1.from("visits").update({ ai_result: { palsu: true } }).eq("id", data.id);
      const { data: after } = await admin.from("visits").select("ai_result").eq("id", data.id).single();
      check("relawan tidak bisa mengubah ai_result", after?.ai_result === null, JSON.stringify(after));
    }
    if (data) {
      check("keluarga1 membaca kunjungan Ibu Sri", (await ids(k1, "visits")).includes(data.id));
      // Prinsip data minimal: yayasan tidak membaca cerita kunjungan; ringkasannya lewat foundation_dashboard.
      check("yayasan tidak membaca kunjungan langsung", (await ids(yay, "visits")).length === 0);
      check("keluarga2 tidak membaca kunjungan Ibu Sri", !(await ids(k2, "visits")).includes(data.id));
      check("relawan2 tidak membaca kunjungan Ibu Sri", !(await ids(r2, "visits")).includes(data.id));
    }
  }

  // --- emergencies
  check("keluarga1 membaca darurat Ibu Sri", (await ids(k1, "emergencies")).includes(emg.id));
  check("yayasan membaca darurat yayasannya", (await ids(yay, "emergencies")).includes(emg.id));
  check("keluarga2 tidak membaca darurat Ibu Sri", !(await ids(k2, "emergencies")).includes(emg.id));
  {
    const { error } = await r1.from("emergencies").insert({ elder_id: SRI, volunteer_id: R(1), lat: 0, lng: 0 });
    check("relawan tidak bisa membuat darurat langsung (harus lewat fungsi)", !!error);
  }

  // --- volunteers + trigger dua centang
  check("relawan1 hanya melihat dirinya", JSON.stringify(await ids(r1, "volunteers")) === JSON.stringify([R(1)]));
  check("keluarga tidak membaca volunteers", (await ids(k1, "volunteers")).length === 0);
  check("yayasan melihat 5 relawan yayasannya", (await ids(yay, "volunteers")).length === 5);
  {
    const { error } = await r1.from("volunteers").update({ status: "terdaftar" }).eq("id", R(1));
    check("relawan tidak bisa mengubah status sendiri", !!error);
    const { error: e2 } = await r5.from("volunteers").update({ id_checked_by: R(5) }).eq("id", R(5));
    check("relawan tidak bisa mencentang dirinya sendiri", !!e2);
    const { error: e3 } = await r1.from("volunteers").update({ area_label: "Kotabaru, Yogyakarta" }).eq("id", R(1));
    check("relawan mengubah area sendiri", !e3, e3?.message);
  }
  {
    // Sejak 000800 status selalu dihitung trigger dari dua centang, jadi nilai di luar enum tidak bisa tersimpan:
    // ditolak CHECK atau ditimpa trigger. Yang diuji: hasil akhirnya tetap sah.
    const { error } = await admin.from("volunteers").update({ status: "diterima" }).eq("id", R(5));
    const { data: v5 } = await admin.from("volunteers").select("status").eq("id", R(5)).single();
    check("status relawan di luar enum tidak bisa tersimpan", !!error || v5?.status === "terdaftar", JSON.stringify(v5));
  }
  {
    cleanup.push(() =>
      admin.from("volunteers").update({
        status: "terdaftar", id_checked_by: null, id_checked_at: null, oriented_by: null, oriented_at: null,
        can_dementia: true,
      }).eq("id", R(5))
    );
    // Sejak 002300 verifikasi hanya lewat kode tatap muka (issue → redeem), bukan centang langsung.
    const { error: e1 } = await yay.from("volunteers").update({ id_checked_by: PENGURUS }).eq("id", R(5));
    check("yayasan tidak bisa mencentang langsung (harus kode tatap muka)", !!e1, e1?.message);
    const { data: issued, error: ei } = await yay.rpc("issue_verification_code", { p_volunteer_id: R(5) });
    const code = (issued as { code: string }[] | null)?.[0]?.code ?? "";
    const wrong = await r5.rpc("redeem_verification_code", { p_code: code === "000000" ? "111111" : "000000" });
    const right = await r5.rpc("redeem_verification_code", { p_code: code });
    const { data: b } = await admin.from("volunteers").select("status, id_checked_by, oriented_by").eq("id", R(5)).single();
    check("kode salah ditolak, kode benar → aktif dan dicatat atas nama pengurus",
      !ei && wrong.data === "salah" && right.data === "aktif" && b?.status === "aktif" && b?.id_checked_by === PENGURUS
        && b?.oriented_by === PENGURUS, ei?.message ?? JSON.stringify({ w: wrong.data, r: right.data, b }));
    const again = await r5.rpc("redeem_verification_code", { p_code: code });
    check("kode sekali pakai", !!again.error);
    const { error: e3 } = await yay.from("volunteers").update({ can_dementia: false }).eq("id", R(5));
    check("yayasan tidak bisa mengubah data diri relawan", !!e3);
  }

  // --- constraint
  {
    const { error } = await admin.from("elders").update({ status: "kritis" }).eq("id", SRI);
    check("status lansia di luar enum ditolak", !!error && error.code === "23514", error?.message);
    const { error: e3 } = await admin.from("proposals").insert({
      elder_id: SRI, volunteer_id: R(3), attempt: 1, distance_km: 1, reason_text: "uji", state: "pending",
    });
    check("dua proposal pending untuk relawan yang sama ditolak", !!e3 && e3.code === "23505", e3?.message);
    const { error: e4 } = await admin.from("proposals").update({ state: "rejected", reject_reason: "lainnya" }).eq("id", prop.id);
    check("tolak 'lainnya' tanpa catatan ditolak", !!e4 && e4.code === "23514", e4?.message);
    const { error: e5 } = await admin.from("proposals").update({ attempt: 4 }).eq("id", prop.id);
    check("attempt di luar 1..3 ditolak", !!e5 && e5.code === "23514", e5?.message);
  }

  // --- storage
  {
    const { data: bucket } = await admin.storage.getBucket("volunteer-photos");
    check("bucket volunteer-photos privat", bucket?.public === false, JSON.stringify(bucket));
    const file = new Blob([new Uint8Array([0xff, 0xd8, 0xff])], { type: "image/jpeg" });
    const own = `${R(1)}/uji.jpg`;
    const { error: up } = await r1.storage.from("volunteer-photos").upload(own, file, { upsert: true });
    check("relawan mengunggah foto ke foldernya", !up, up?.message);
    cleanup.push(() => admin.storage.from("volunteer-photos").remove([own]));
    const { error: up2 } = await r1.storage.from("volunteer-photos").upload(`${R(2)}/uji.jpg`, file);
    check("relawan tidak bisa mengunggah ke folder relawan lain", !!up2);
    const { error: dl } = await yay.storage.from("volunteer-photos").download(own);
    check("yayasan membaca foto relawannya", !dl, dl?.message);
    const { error: dl2 } = await k1.storage.from("volunteer-photos").download(own);
    check("keluarga tidak membaca foto langsung", !!dl2);
  }

  // --- anggota keluarga (family_members, migration 001100)
  {
    const K2 = (await k2.auth.getUser()).data.user!.id;
    check("keluarga2 belum anggota → tidak melihat Ibu Sri", (await ids(k2, "elders")).length === 1); // hanya Pak Harjo
    const { error } = await k1.rpc("add_family_member", { p_elder_id: SRI, p_email: "keluarga2@demo.id" });
    check("pendaftar menambah anggota keluarga", !error, error?.message);
    cleanup.push(() => admin.from("family_members").delete().eq("elder_id", SRI));
    check("diundang tapi belum menerima → belum melihat Ibu Sri", (await ids(k2, "elders")).length === 1);
    await k2.rpc("accept_family_invite", { p_elder_id: SRI });
    check("setelah menerima undangan: melihat Ibu Sri dan kunjungannya",
      (await ids(k2, "elders")).length === 2 && (await ids(k2, "visits")).length > 0);
    const { error: e2 } = await k2.rpc("add_family_member", { p_elder_id: SRI, p_email: "keluarga1@demo.id" });
    check("anggota (bukan pendaftar) tidak bisa menambah anggota", !!e2);
    await k2.rpc("remove_family_member", { p_elder_id: SRI, p_profile_id: K2 });
    check("anggota yang keluar tidak melihat Ibu Sri lagi", (await ids(k2, "elders")).length === 1);
  }

  // --- realtime
  {
    const out = new Deno.Command("supabase", {
      args: ["db", "query", "--linked",
        "select string_agg(tablename, ',' order by tablename) t from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'"],
    }).outputSync();
    const text = new TextDecoder().decode(out.stdout);
    check("Realtime aktif untuk elders dan visits", text.includes("elders") && text.includes("visits"), text.slice(0, 200));
  }
} finally {
  for (const f of cleanup.reverse()) await f();
}

console.log(failed ? `\n${failed} cek gagal` : "\nSemua cek lulus");
Deno.exit(failed ? 1 : 0);
