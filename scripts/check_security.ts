// Pemeriksaan keamanan regresi (serangan 15 Okt): setiap baris harus AMAN. Membuat lalu menghapus akun/yayasan
// sementara dan mengubah data Ibu Sri; jalankan reset demo setelahnya:
//   deno run -A scripts/check_security.ts
//   supabase db query --linked -f supabase/seeds/04_reset_demo.sql && supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql
import { createClient } from "npm:@supabase/supabase-js@2";
const env = Object.fromEntries((await Deno.readTextFile(new URL("../.env.local", import.meta.url))).split("\n").filter((l) => l.includes("=")).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const login = async (email: string) => { const c = createClient(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false } }); const { data } = await c.auth.signInWithPassword({ email, password: "demo1234" }); return { c, id: data.user!.id }; };
let bad = 0; const report = (n: string, safe: boolean, d = "") => { console.log(`${safe ? "AMAN  " : "CELAH "}  ${n}${d ? "  · " + d : ""}`); if (!safe) bad++; };
const SRI = "e0000000-0000-0000-0000-000000000001", R1 = "c0000000-0000-0000-0000-000000000001";
const r1 = await login("relawan1@demo.id"), k1 = await login("keluarga1@demo.id"), k2 = await login("keluarga2@demo.id"), y = await login("pengurus@demo.id");
const st = async () => (await admin.from("elders").select("pairing_state").eq("id", SRI).single()).data!.pairing_state;

// S2
let e = await r1.c.from("profiles").update({ full_name: "Nama Palsu" }).eq("id", r1.id).select("full_name");
report("S2 relawan terverifikasi mengganti nama → ditolak", !!e.error, e.error?.message);
await r1.c.from("volunteers").update({ photo_path: `${R1}/foto-lain.jpg` }).eq("id", R1);
const vs = (await admin.from("volunteers").select("status").eq("id", R1).single()).data!.status;
report("S2 relawan mengganti foto → harus diverifikasi ulang", vs === "terdaftar", `status: ${vs}`);
// S3
e = await r1.c.from("profiles").update({ phone_verified: true }).eq("id", r1.id).select("phone_verified");
report("S3 menandai nomor sendiri terverifikasi → ditolak", !!e.error, e.error?.message);
// S5 undangan
await k1.c.rpc("add_family_member", { p_elder_id: SRI, p_email: "keluarga2@demo.id" });
const before = (await k2.c.from("elders").select("id").eq("id", SRI)).data?.length ?? 0;
report("S5 diundang tapi belum menerima → tidak melihat apa pun", before === 0);
const inv = (await k2.c.rpc("my_family_invites")).data;
report("S5 undangan muncul untuk yang diundang", inv?.some((i: any) => i.elder_id === SRI), JSON.stringify(inv));
await k2.c.rpc("accept_family_invite", { p_elder_id: SRI });
report("S5 setelah menerima → melihat Ibu Sri", ((await k2.c.from("elders").select("id").eq("id", SRI)).data?.length ?? 0) === 1);
const a1 = await k1.c.rpc("add_family_member", { p_elder_id: SRI, p_email: "relawan2@demo.id" });
const a2 = await k1.c.rpc("add_family_member", { p_elder_id: SRI, p_email: "tidak-ada@demo.id" });
report("S5 jawaban sama untuk email terdaftar/tidak (tanpa enumerasi)", a1.data === a2.data && !a1.error && !a2.error, String(a1.data));
// S4
const end = await k2.c.functions.invoke("pairing", { body: { action: "end", elder_id: SRI, reason: "meninggal" } });
report("S4 anggota (bukan pendaftar) mengakhiri pendampingan → ditolak", !!end.error && (await st()) === "berpasangan");
await k1.c.functions.invoke("pairing", { body: { action: "end", elder_id: SRI, reason: "pindah" } });
const re = await k1.c.functions.invoke("pairing", { body: { action: "reopen", elder_id: SRI } });
report("S4 pendaftar bisa mengaktifkan kembali", !re.error && (await st()) === "mencari", JSON.stringify(re.error ?? re.data));
// S1
await admin.from("elders").update({ pairing_state: "perlu_yayasan", volunteer_id: null, foundation_id: "f0000000-0000-0000-0000-000000000001",
  status: "segera_dikabari", status_reason: "Tanda bahaya: Jatuh." }).eq("id", SRI);
const { data: f2 } = await admin.from("foundations").insert({ name: "Yayasan Penyerang", verified: true, invite_code: "SRANG2" }).select("id").single();
const { data: u2 } = await admin.auth.admin.createUser({ email: "pengurus-penyerang2@demo.id", password: "demo1234", email_confirm: true, user_metadata: { role: "keluarga" } });
await admin.from("profiles").update({ role: "yayasan", foundation_id: f2!.id }).eq("id", u2.user!.id);
const atk = await login("pengurus-penyerang2@demo.id");
const dash = (await atk.c.rpc("foundation_dashboard")).data;
const raw = (await atk.c.from("elders").select("id").eq("id", SRI)).data ?? [];
report("S1 yayasan lain tidak melihat Ibu Sri (dashboard & tabel)", !dash?.elders?.some((x: any) => x.id === SRI) && raw.length === 0);
const own = (await y.c.rpc("foundation_dashboard")).data;
report("S1 yayasannya sendiri tetap melihat (untuk dipasangkan ulang)", own?.elders?.some((x: any) => x.id === SRI && x.pairing_state === "perlu_yayasan"));
// E2 lansia tanpa yayasan: tidak terbaca langsung oleh yayasan mana pun; pasang manual lewat RPC tanpa alamat/koordinat
const HARJO = "e0000000-0000-0000-0000-000000000002";
await admin.from("elders").update({ pairing_state: "perlu_yayasan" }).eq("id", HARJO);
const harjoRaw = (await atk.c.from("elders").select("address, lat").eq("id", HARJO)).data ?? [];
const mp = (await atk.c.rpc("manual_pair_options", { p_elder_id: HARJO })).data;
report("E2 yayasan lain tidak membaca alamat/koordinat lansia tanpa yayasan", harjoRaw.length === 0 &&
  !!mp?.elder && mp.elder.lat === undefined && !String(mp.elder.address).startsWith("Jl"), JSON.stringify(mp?.elder));
await admin.from("elders").update({ pairing_state: "mencari" }).eq("id", HARJO);
await admin.auth.admin.deleteUser(u2.user!.id); await admin.from("foundations").delete().eq("id", f2!.id);
// P2b sudah ditangani
const ack = await k2.c.rpc("acknowledge_status", { p_elder_id: SRI, p_note: "Sudah ditelepon, besok ke puskesmas" });
const ackRow = (await admin.from("elders").select("status_ack_by, status_ack_note").eq("id", SRI).single()).data;
report("P2b anggota keluarga menandai 'sudah ditangani'", !ack.error && ackRow?.status_ack_note?.startsWith("Sudah ditelepon"), JSON.stringify(ackRow));
const ackBad = await r1.c.rpc("acknowledge_status", { p_elder_id: SRI, p_note: "x" });
report("P2b relawan (bukan pasangan lagi) tidak bisa menandai", !!ackBad.error);
// S7 & S8
await admin.from("elders").update({ pairing_state: "berpasangan", volunteer_id: R1 }).eq("id", SRI);
await admin.from("volunteers").update({ id_checked_by: "a0000000-0000-0000-0000-000000000001", oriented_by: "a0000000-0000-0000-0000-000000000001", photo_path: null }).eq("id", R1);
for (let i = 0; i < 5; i++) await r1.c.functions.invoke("emergency", { body: { elder_id: SRI } });
const n = (await admin.from("emergencies").select("*", { count: "exact", head: true }).eq("elder_id", SRI)).count;
report("S7 Darurat 5× beruntun → hanya 1 kejadian/notifikasi", n === 1, `${n} kejadian`);
const { data: vis } = await r1.c.from("visits").insert({ elder_id: SRI, volunteer_id: R1, answers: { makan: "x" } }).select("id").single();
await admin.from("visits").update({ ai_result: { sudah: true } }).eq("id", vis!.id); // seolah extract pertama sukses
const ex = await r1.c.functions.invoke("visit", { body: { action: "extract", visit_id: vis!.id } });
report("S8 extract kedua tidak memanggil Gemini (hasil lama dikembalikan)", (ex.data as any)?.ai_result?.sudah === true, JSON.stringify(ex.data));
// E1 mencabut tanda bahaya AI: wajib alasan, tercatat, terlihat di status_reason
const aiJatuh = { makan: { level: 0, evidence: "x" }, obat: { level: 0, evidence: "" }, gerak: { level: 2, evidence: "terpeleset" },
  harian: { level: 0, evidence: "" }, ingatan: { level: 0, evidence: "" }, hati: { level: 0, evidence: "" }, umum: { level: 0, evidence: "" },
  red_flags: [{ flag: "jatuh", evidence: "terpeleset" }] };
await admin.from("visits").update({ ai_result: aiJatuh }).eq("id", vis!.id);
const quiet = { ...aiJatuh, gerak: { level: 0, evidence: "terpeleset" }, red_flags: [] };
const c1 = await r1.c.functions.invoke("visit", { body: { action: "confirm", visit_id: vis!.id, final_result: quiet } });
report("E1 mencabut tanda bahaya AI tanpa alasan → ditolak", !!c1.error);
const c2 = await r1.c.functions.invoke("visit", { body: { action: "confirm", visit_id: vis!.id, final_result: quiet, flag_reasons: { jatuh: "Itu kejadian tahun lalu" } } });
const sr = (await k1.c.from("elders").select("status_reason").eq("id", SRI).single()).data?.status_reason ?? "";
report("E1 dengan alasan → tersimpan dan terlihat keluarga", !c2.error && sr.startsWith("Koreksi relawan") && sr.includes("tahun lalu"), sr.slice(0, 120));
// E7 satu kunjungan per hari
const dup = await r1.c.from("visits").insert({ elder_id: SRI, volunteer_id: R1, answers: { makan: "y" } }).select("id");
report("E7 kunjungan kedua hari yang sama → ditolak", !!dup.error, dup.error?.message);
// A8 kuota Gemini: maksimal 3 cerita (belum dikonfirmasi) per lansia per hari
await admin.from("visits").delete().eq("id", vis!.id); // hari ini kosong lagi
const tries: boolean[] = [];
for (let i = 0; i < 4; i++) tries.push(!(await r1.c.from("visits").insert({ elder_id: SRI, volunteer_id: R1, answers: { makan: "z" + i } })).error);
report("A8 cerita ke-4 di hari yang sama → ditolak (kuota Gemini)", JSON.stringify(tries) === "[true,true,true,false]", JSON.stringify(tries));
// A1 koordinat
const half = await k1.c.from("elders").insert({ family_id: k1.id, full_name: "Uji koordinat", address: "x", lat: -7.7, consent_type: "lansia" }).select("id");
const zero = await k1.c.from("elders").insert({ family_id: k1.id, full_name: "Uji koordinat", address: "x", lat: 0, lng: 0, consent_type: "lansia" }).select("id");
report("A1 koordinat setengah / di luar Indonesia → ditolak", !!half.error && !!zero.error);
await admin.from("elders").delete().eq("full_name", "Uji koordinat");
// P2a token multi-perangkat
await k1.c.rpc("register_push_token", { p_token: "uji-hp" }); await k1.c.rpc("register_push_token", { p_token: "uji-tablet" });
const toks = (await admin.from("push_tokens").select("token").eq("profile_id", k1.id)).data?.length;
await k2.c.rpc("register_push_token", { p_token: "uji-tablet" }); // tablet dipakai login akun lain
const moved = (await admin.from("push_tokens").select("profile_id").eq("token", "uji-tablet").single()).data?.profile_id;
report("P2a dua perangkat per akun; perangkat pindah akun ikut pindah pemilik", toks === 2 && moved === k2.id);
const steal = await k2.c.rpc("unregister_push_token", { p_token: "uji-hp" });
report("P2a tidak bisa menghapus token milik akun lain", ((await admin.from("push_tokens").select("token").eq("token", "uji-hp")).data?.length ?? 0) === 1);

// S6 pewarisan kepemilikan (akun sementara)
const mk = async (email: string) => (await admin.auth.admin.createUser({ email, password: "demo1234", email_confirm: true, user_metadata: { role: "keluarga", full_name: email } })).data.user!.id;
const ownerId = await mk("pemilik-uji@demo.id"), heirId = await mk("pewaris-uji@demo.id");
const { data: tel } = await admin.from("elders").insert({ family_id: ownerId, full_name: "Lansia Pewarisan", address: "Jl. Uji", lat: -7.78, lng: 110.37 }).select("id").single();
await admin.from("family_members").insert({ elder_id: tel!.id, profile_id: heirId, accepted_at: new Date().toISOString() });
const ow = await login("pemilik-uji@demo.id");
await ow.c.functions.invoke("account", { body: { action: "delete", confirm: "HAPUS" } });
const after = (await admin.from("elders").select("family_id").eq("id", tel!.id).maybeSingle()).data;
report("S6 pendaftar hapus akun → lansia pindah ke anggota, tidak terhapus", after?.family_id === heirId, JSON.stringify(after));
await admin.from("elders").delete().eq("id", tel!.id); await admin.auth.admin.deleteUser(heirId); await admin.auth.admin.deleteUser(ownerId).catch(() => {});
// Y1 yayasan tidak membaca cerita kunjungan lengkap; dashboard tetap punya ringkasan
const yv = (await y.c.from("visits").select("answers").eq("elder_id", SRI)).data ?? [];
const yd = (await y.c.rpc("foundation_dashboard")).data;
report("Y1 yayasan tidak membaca cerita kunjungan (answers)", yv.length === 0 && yd?.elders?.some((x: any) => x.id === SRI && x.last_visit_at), `${yv.length} baris`);
// H1 hapus data lansia: hanya pendaftar, semua data ikut terhapus
const pemilik = await mk("pemilik-hapus@demo.id"), anggota = await mk("anggota-hapus@demo.id");
const { data: tl } = await admin.from("elders").insert({ family_id: pemilik, full_name: "Lansia Hapus", address: "Jl. Uji", lat: -7.78, lng: 110.37 }).select("id").single();
await admin.from("health_profiles").insert({ elder_id: tl!.id, conditions: "uji" });
await admin.from("family_members").insert({ elder_id: tl!.id, profile_id: anggota, accepted_at: new Date().toISOString() });
const ang = await login("anggota-hapus@demo.id"), pem = await login("pemilik-hapus@demo.id");
const h1 = await ang.c.functions.invoke("pairing", { body: { action: "delete", elder_id: tl!.id, confirm: "HAPUS" } });
const h2 = await r1.c.functions.invoke("pairing", { body: { action: "delete", elder_id: SRI, confirm: "HAPUS" } });
report("H1 anggota keluarga / relawan tidak bisa menghapus data lansia", !!h1.error && !!h2.error);
const h3 = await pem.c.functions.invoke("pairing", { body: { action: "delete", elder_id: tl!.id } });
report("H1 tanpa konfirmasi HAPUS → ditolak", !!h3.error);
await pem.c.functions.invoke("pairing", { body: { action: "delete", elder_id: tl!.id, confirm: "HAPUS" } });
const left = [(await admin.from("elders").select("id").eq("id", tl!.id)).data?.length, (await admin.from("health_profiles").select("elder_id").eq("elder_id", tl!.id)).data?.length,
  (await admin.from("family_members").select("elder_id").eq("elder_id", tl!.id)).data?.length];
report("H1 pendaftar menghapus → lansia, profil kesehatan, anggota ikut terhapus", JSON.stringify(left) === "[0,0,0]", JSON.stringify(left));
await admin.auth.admin.deleteUser(pemilik); await admin.auth.admin.deleteUser(anggota);
// V: langganan + verifikasi keluarga (K1/K5)
{
  const fam = await mk("keluarga-verif@demo.id");
  const fc = (await login("keluarga-verif@demo.id")).c;
  const { data: el } = await fc.from("elders").insert({ family_id: fam, full_name: "Lansia Verif", address: "Jl. Uji", lat: -7.78, lng: 110.37, consent_type: "lansia" }).select("id").single();
  const id = el!.id;
  const self = await fc.from("elders").update({ paid_until: "2099-01-01", verify_state: "terverifikasi" } as any).eq("id", id).select("id");
  report("V1 keluarga tidak bisa menandai sendiri sudah bayar/terverifikasi", !!self.error, self.error?.message);
  const p0 = await fc.functions.invoke("pairing", { body: { action: "propose", elder_id: id } });
  report("V2 cari relawan sebelum bayar → ditolak", !!p0.error);
  await fc.rpc("simulate_payment", { p_elder_id: id });
  const p1 = await fc.functions.invoke("pairing", { body: { action: "propose", elder_id: id } });
  const s0 = await fc.rpc("submit_verification", { p_elder_id: id });
  report("V2 sudah bayar tapi dokumen belum lengkap → cari relawan & kirim ditolak", !!p1.error && !!s0.error);
  const jpg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  for (const k of ["ktp_keluarga", "ktp_lansia", "kk"]) await fc.storage.from("elder-docs").upload(`${id}/${k}.jpg`, jpg, { contentType: "image/jpeg", upsert: true });
  const other = await k2.c.storage.from("elder-docs").upload(`${id}/kk.jpg`, jpg, { contentType: "image/jpeg", upsert: true });
  report("V3 keluarga lain tidak bisa mengunggah ke dokumen lansia ini", !!other.error);
  await fc.rpc("submit_verification", { p_elder_id: id });
  const prop = (await fc.functions.invoke("pairing", { body: { action: "propose", elder_id: id } })).data as any;
  const card = ((await fc.rpc("get_proposal_card", { proposal_id: prop?.proposal_id })).data as any[])?.[0];
  report("V4 kartu usulan: jarak dibulatkan km, tanpa nomor HP", card && Number.isInteger(Number(card.distance_km)) && !("phone" in card) && !/\d,\d km/.test(card.reason_text ?? ""), JSON.stringify({ km: card?.distance_km, r: card?.reason_text }));
  await fc.functions.invoke("pairing", { body: { action: "accept", proposal_id: prop?.proposal_id } });
  const e1 = (await admin.from("elders").select("volunteer_id, foundation_id, verify_state").eq("id", id).single()).data!;
  const relEmail = (await admin.auth.admin.getUserById(e1.volunteer_id)).data.user!.email!;
  const rel = await login(relEmail);
  const contact0 = (await fc.rpc("my_volunteer_contact", { p_elder_id: id })).data ?? [];
  const v0 = await rel.c.from("visits").insert({ elder_id: id, volunteer_id: e1.volunteer_id, answers: { makan: "x" } });
  report("V5 sebelum verifikasi: kontak relawan tertutup & relawan belum bisa mencatat kunjungan", contact0.length === 0 && !!v0.error, v0.error?.message);
  const fz = await mk("pengurus-lain-v@demo.id");
  const { data: f3 } = await admin.from("foundations").insert({ name: "Yayasan Lain V", verified: true, invite_code: "LAINV3" }).select("id").single();
  await admin.from("profiles").update({ role: "yayasan", foundation_id: f3!.id }).eq("id", fz);
  const lain = (await login("pengurus-lain-v@demo.id")).c;
  const docOther = await lain.storage.from("elder-docs").createSignedUrl(`${id}/kk.jpg`, 60);
  const docOwn = await y.c.storage.from("elder-docs").createSignedUrl(`${id}/kk.jpg`, 60);
  report("V6 dokumen hanya terbaca yayasan lansia ini", !!docOther.error && !!docOwn.data?.signedUrl, docOther.error?.message);
  const vf1 = await lain.functions.invoke("pairing", { body: { action: "verify", elder_id: id, approve: true } });
  const vf2 = await fc.functions.invoke("pairing", { body: { action: "verify", elder_id: id, approve: true } });
  report("V7 yayasan lain / keluarga sendiri tidak bisa memverifikasi", !!vf1.error && !!vf2.error);
  await y.c.functions.invoke("pairing", { body: { action: "verify", elder_id: id, approve: true } });
  const left = (await admin.storage.from("elder-docs").list(id)).data?.length ?? -1;
  const contact1 = (await fc.rpc("my_volunteer_contact", { p_elder_id: id })).data ?? [];
  report("V8 setelah disetujui: dokumen dihapus, kontak relawan terbuka", left === 0 && contact1.length === 1, JSON.stringify({ left, c: contact1[0] && Object.keys(contact1[0]) }));
  const v1 = await rel.c.from("visits").insert({ elder_id: id, volunteer_id: e1.volunteer_id, answers: { makan: "x" } });
  await rel.c.rpc("confirm_first_visit", { p_elder_id: id });
  const v2 = await rel.c.from("visits").insert({ elder_id: id, volunteer_id: e1.volunteer_id, answers: { makan: "x" } });
  report("V9 kunjungan baru bisa setelah relawan memastikan lansia ada & setuju", !!v1.error && !v2.error, v2.error?.message);
  const lim: boolean[] = [];
  for (let i = 0; i < 3; i++) lim.push(!(await fc.from("elders").insert({ family_id: fam, full_name: "L" + i, address: "x", lat: -7.78, lng: 110.37, consent_type: "lansia" })).error);
  report("V10 maks. 3 lansia per akun keluarga", JSON.stringify(lim) === "[true,true,false]", JSON.stringify(lim));
  await admin.auth.admin.deleteUser(fz); await admin.from("foundations").delete().eq("id", f3!.id);
  await admin.auth.admin.deleteUser(fam);
}
// R: masukan keluarga untuk relawan; B: langganan
{
  const send = (c: any, kind: string, body = "uji masukan") => c.functions.invoke("review", { body: { elder_id: SRI, kind, body } });
  await admin.from("family_members").delete().eq("elder_id", SRI); // k2 bukan anggota lagi
  report("R1 bukan keluarga lansia ini tidak bisa memberi masukan", !!(await send(k2.c, "apresiasi")).error);
  const direct = await k1.c.from("reviews").insert({ elder_id: SRI, volunteer_id: R1, author_id: k1.id, kind: "apresiasi", body: "palsu" } as any);
  report("R2 masukan tidak bisa ditulis langsung ke tabel", !!direct.error);
  const a1 = await send(k1.c, "perbaikan", "Sering datang terlambat");
  const a2 = await send(k1.c, "apresiasi", "Terima kasih");
  const a3 = await send(k1.c, "serius", "Meminta uang");
  report("R3 masukan biasa maks. 1/minggu, laporan serius tetap bisa", !a1.error && !!a2.error && !a3.error);
  await admin.from("reviews").insert({ elder_id: SRI, volunteer_id: R1, author_id: k1.id, kind: "apresiasi", body: "Baik sekali" });
  const seen = ((await r1.c.from("reviews").select("kind")).data ?? []).map((r: any) => r.kind);
  report("R4 relawan hanya melihat apresiasi (bukan perbaikan/serius)", seen.length > 0 && seen.every((k) => k === "apresiasi"), JSON.stringify(seen));
  const fz = await mk("pengurus-lain-r@demo.id");
  const { data: f4 } = await admin.from("foundations").insert({ name: "Yayasan Lain R", verified: true, invite_code: "LAINR4" }).select("id").single();
  await admin.from("profiles").update({ role: "yayasan", foundation_id: f4!.id }).eq("id", fz);
  const lain = (await login("pengurus-lain-r@demo.id")).c;
  const lainSeen = (await lain.from("reviews").select("id")).data?.length ?? 0;
  const ownSeen = (await y.c.from("reviews").select("id")).data?.length ?? 0;
  const serius = (await admin.from("reviews").select("id").eq("kind", "serius").eq("elder_id", SRI).single()).data!.id;
  const h1 = await lain.rpc("handle_review", { p_review_id: serius, p_note: "x" });
  const h2 = await k1.c.rpc("handle_review", { p_review_id: serius, p_note: "x" });
  const h3 = await y.c.rpc("handle_review", { p_review_id: serius, p_note: "Relawan dibina" });
  report("R5 hanya yayasan relawan itu yang membaca & menangani masukan", lainSeen === 0 && ownSeen >= 3 && !!h1.error && !!h2.error && !h3.error, `${lainSeen}/${ownSeen}`);
  await admin.auth.admin.deleteUser(fz); await admin.from("foundations").delete().eq("id", f4!.id);
  await admin.from("reviews").delete().eq("elder_id", SRI);
  const pay = await k1.c.from("payments").insert({ elder_id: SRI, period_end: "2099-01-01" } as any);
  report("B1 riwayat pembayaran tidak bisa dipalsukan keluarga", !!pay.error);
  await admin.from("visits").delete().eq("elder_id", SRI).gte("visited_at", new Date(Date.now() - 86400_000).toISOString());
  await admin.from("elders").update({ paid_until: new Date(Date.now() - 8 * 86400_000).toISOString() }).eq("id", SRI);
  const late = await r1.c.from("visits").insert({ elder_id: SRI, volunteer_id: R1, answers: { makan: "x" } });
  await k1.c.rpc("simulate_payment", { p_elder_id: SRI });
  const renewed = await r1.c.from("visits").insert({ elder_id: SRI, volunteer_id: R1, answers: { makan: "x" } });
  const receipts = (await k1.c.from("payments").select("id").eq("elder_id", SRI)).data?.length ?? 0;
  report("B2 langganan habis >7 hari → kunjungan ditolak; diperpanjang → tercatat & bisa lagi", !!late.error && !renewed.error && receipts === 1, late.error?.message);
}
// W: verifikasi kode tatap muka, permintaan berhenti, penonaktifan
{
  const R4 = "c0000000-0000-0000-0000-000000000005"; // relawan5 berstatus terdaftar
  const r4 = await login("relawan5@demo.id");
  const self = await r4.c.rpc("issue_verification_code", { p_volunteer_id: R4 });
  report("W1 relawan tidak bisa membuat kode verifikasi untuk dirinya", !!self.error);
  const { data: iss } = await y.c.rpc("issue_verification_code", { p_volunteer_id: R4 });
  const code = (iss as any[])?.[0]?.code as string;
  const tries: unknown[] = [];
  for (let i = 0; i < 5; i++) tries.push((await r4.c.rpc("redeem_verification_code", { p_code: String((Number(code) + 1 + i) % 1000000).padStart(6, "0") })).data);
  const late = await r4.c.rpc("redeem_verification_code", { p_code: code });
  report("W2 tebak kode: 5 kali salah → kode hangus walau kemudian benar", tries.every((t) => t === "salah") && !!late.error, JSON.stringify(late.data ?? late.error?.message));
  const stolen = await r1.c.rpc("redeem_verification_code", { p_code: code });
  report("W3 kode milik relawan lain tidak berlaku untuk akun lain", !!stolen.error || stolen.data !== "aktif");
  const direct = await r1.c.functions.invoke("pairing", { body: { action: "release", elder_id: SRI } });
  report("W4 relawan tidak bisa melepas lansia sendiri (harus permintaan)", !!direct.error && (await st()) === "berpasangan");
  await r1.c.functions.invoke("pairing", { body: { action: "request_stop", elder_id: SRI, reason: "Pindah kota" } });
  const dup = await r1.c.functions.invoke("pairing", { body: { action: "request_stop", elder_id: SRI, reason: "lagi" } });
  const { data: reqs } = await y.c.from("stop_requests").select("id").eq("elder_id", SRI).is("decided_at", null);
  const byFam = await k1.c.functions.invoke("pairing", { body: { action: "approve_stop", request_id: reqs?.[0]?.id } });
  report("W5 permintaan berhenti: tidak ganda, terlihat yayasan, keluarga tidak bisa menerimanya", !!dup.error && reqs?.length === 1 && !!byFam.error && (await st()) === "berpasangan");
  await admin.from("stop_requests").update({ created_at: new Date(Date.now() - 8 * 86400_000).toISOString() }).eq("id", reqs![0].id);
  // Otomatis-7-hari diuji lewat RPC yang sama dengan yang dipanggil Edge Function reminders.
  await admin.rpc("approve_stop_request", { p_id: reqs![0].id, p_by: "Otomatis (7 hari tanpa tanggapan)" });
  report("W6 permintaan yang diterima → lansia ke yayasan untuk dipasangkan ulang", (await st()) === "perlu_yayasan");
  await admin.from("elders").update({ pairing_state: "berpasangan", volunteer_id: R1 }).eq("id", SRI);
  const deB = await k1.c.functions.invoke("pairing", { body: { action: "deactivate", volunteer_id: R1, reason: "uji" } });
  const deY = await y.c.functions.invoke("pairing", { body: { action: "deactivate", volunteer_id: R1, reason: "Laporan serius terbukti" } });
  const v1 = (await admin.from("volunteers").select("status, status_note").eq("id", R1).single()).data;
  const s7 = await st();
  report("W7 hanya yayasan yang menonaktifkan; lansia relawan itu langsung dicocokkan ulang otomatis", !!deB.error && !deY.error && v1?.status === "terdaftar" && ["menunggu_keluarga", "tanpa_pendamping"].includes(s7), `${JSON.stringify(v1)} · ${s7}`);
  await admin.from("volunteers").update({ id_checked_by: "a0000000-0000-0000-0000-000000000001", oriented_by: "a0000000-0000-0000-0000-000000000001", status_note: null }).eq("id", R1);
  const restore = async () => {
    await admin.from("proposals").delete().eq("elder_id", SRI).eq("state", "pending");
    await admin.from("elders").update({ pairing_state: "berpasangan", volunteer_id: R1, foundation_id: (await admin.from("volunteers").select("foundation_id").eq("id", R1).single()).data!.foundation_id }).eq("id", SRI);
  };
  await restore();
  // W8: yayasan melepas → usulan otomatis putaran baru ke relawan lain (bukan relawan lama)
  const rel8 = await y.c.functions.invoke("pairing", { body: { action: "release", elder_id: SRI } });
  const p8 = (await admin.from("proposals").select("volunteer_id, attempt").eq("elder_id", SRI).eq("state", "pending").maybeSingle()).data;
  const s8 = await st();
  report("W8 yayasan melepas → sistem langsung mengusulkan relawan lain (putaran baru, usulan ke-1)",
    !rel8.error && (s8 === "tanpa_pendamping" || (s8 === "menunggu_keluarga" && p8?.volunteer_id !== R1 && p8?.attempt === 1)), `${s8} · ${JSON.stringify(p8)}`);
  // W9: usulan ke-3 tidak bisa ditolak
  await admin.from("proposals").delete().eq("elder_id", SRI).eq("state", "pending");
  const other = (await admin.from("volunteers").select("id").neq("id", R1).eq("status", "aktif").limit(1).single()).data!.id;
  await admin.from("proposals").delete().eq("elder_id", SRI).eq("volunteer_id", other);
  const ins = await admin.from("proposals").insert({ elder_id: SRI, volunteer_id: other, attempt: 3, distance_km: 1, reason_text: "uji" }).select("id").single();
  await admin.from("elders").update({ pairing_state: "menunggu_keluarga", volunteer_id: null }).eq("id", SRI);
  const rej9 = await k1.c.functions.invoke("pairing", { body: { action: "reject", proposal_id: ins.data?.id, reason: "jadwal" } });
  const still = (await admin.from("proposals").select("state").eq("id", ins.data?.id).single()).data?.state;
  report("W9 usulan ke-3 tidak bisa ditolak keluarga", !!rej9.error && still === "pending", still);
  await admin.from("proposals").delete().eq("id", ins.data?.id);
  await admin.from("elders").update({ match_round_at: null }).eq("id", SRI);
  await restore();
}
// M: pengunduran diri relawan & kontak keluarga untuk relawan
{
  const famCt = (await k1.c.rpc("my_elders_family_contacts")).data ?? [];
  const yCt = (await y.c.rpc("my_elders_family_contacts")).data ?? [];
  const rCt = (await r1.c.rpc("my_elders_family_contacts")).data ?? [];
  report("M1 kontak keluarga hanya untuk relawan pasangannya", famCt.length === 0 && yCt.length === 0 && rCt.some((c: any) => c.elder_id === SRI), JSON.stringify(rCt));
  const direct = await r1.c.from("volunteers").update({ resign_requested_at: new Date().toISOString() }).eq("id", R1).select("id");
  report("M2 relawan tidak bisa menulis kolom pengunduran diri langsung", !!direct.error || (direct.data?.length ?? 0) === 0, direct.error?.message);
  const byFam = await k1.c.functions.invoke("pairing", { body: { action: "resign", reason: "uji" } });
  const res = await r1.c.functions.invoke("pairing", { body: { action: "resign", reason: "Pindah kota" } });
  const dupR = await r1.c.functions.invoke("pairing", { body: { action: "resign", reason: "lagi" } });
  const { data: sr } = await admin.from("stop_requests").select("id").eq("elder_id", SRI).is("decided_at", null);
  report("M3 resign: hanya relawan, tidak ganda, lansianya jadi permintaan berhenti (tetap didampingi)",
    !!byFam.error && !res.error && !!dupR.error && sr?.length === 1 && (await st()) === "berpasangan", JSON.stringify(res.data ?? res.error?.message));
  await admin.from("stop_requests").delete().eq("elder_id", SRI).is("decided_at", null);
  await admin.from("volunteers").update({ resign_reason: null, resign_requested_at: null, status_note: null }).eq("id", R1);
}
// Y2–Y3: nama penulis masukan & waktu kunjungan hanya untuk pengurus yayasan relawan yang diulas
{
  const yA = (await y.c.rpc("foundation_review_authors")).data ?? [];
  const kA = (await k1.c.rpc("foundation_review_authors")).data ?? [];
  const rA = (await r1.c.rpc("foundation_review_authors")).data ?? [];
  const own = (await y.c.from("reviews").select("id")).data?.length ?? 0;
  report("Y2 nama penulis masukan: pengurus melihat masukan relawannya saja; keluarga & relawan tidak", yA.length === own && kA.length === 0 && rA.length === 0, `${yA.length}/${own}`);
  const since = new Date(Date.now() - 365 * 86400_000).toISOString();
  const wY = (await y.c.rpc("foundation_week_visits", { p_since: since })).data ?? [];
  const wK = (await k1.c.rpc("foundation_week_visits", { p_since: since })).data ?? [];
  const old = (wY as string[]).filter((t) => Date.now() - Date.parse(t) > 9 * 86400_000).length;
  report("Y3 waktu kunjungan untuk yayasan: hanya 8 hari terakhir, keluarga tidak dapat", wK.length === 0 && old === 0, `${wY.length} baris`);
}
// F: data baru Figma keluarga (16 Okt)
{
  const badNotif = await k1.c.from("profiles").update({ notify_off: ["darurat"] }).eq("id", k1.id).select("id");
  report("F1 darurat tidak bisa dimatikan (kategori notifikasi tak dikenal ditolak)", !!badNotif.error, badNotif.error?.message);
  const age = await r1.c.from("profiles").update({ birth_date: "2015-01-01" }).eq("id", r1.id).select("id");
  report("F2 relawan terverifikasi tidak bisa mengubah tanggal lahirnya sendiri", !!age.error, age.error?.message);
  const png = new Uint8Array([137, 80, 78, 71]);
  const upY = await y.c.storage.from("elder-photos").upload(`${SRI}/foto.jpg`, png, { upsert: true, contentType: "image/jpeg" });
  const upR = await r1.c.storage.from("elder-photos").upload(`${SRI}/foto.jpg`, png, { upsert: true, contentType: "image/jpeg" });
  report("F3 yayasan & relawan tidak bisa mengunggah foto lansia", !!upY.error && !!upR.error, `${upY.error?.message} · ${upR.error?.message}`);
}
// N & J: kotak masuk notifikasi dan jadwal kunjungan (16 Okt)
{
  const fake = await k1.c.from("notifications").insert({ profile_id: k1.id, title: "palsu", body: "x" }).select("id");
  report("N1 akun tidak bisa menulis notifikasi sendiri (hanya server)", !!fake.error, fake.error?.message);
  await admin.from("notifications").insert({ profile_id: r1.id, title: "rahasia relawan", body: "x" });
  const peek = (await k1.c.from("notifications").select("id").eq("profile_id", r1.id)).data ?? [];
  report("N2 tidak bisa membaca notifikasi akun lain", peek.length === 0);
  const mine = (await r1.c.from("notifications").select("id").limit(1).single()).data;
  const edit = await r1.c.from("notifications").update({ title: "diubah" }).eq("id", mine?.id).select("id");
  const read = await r1.c.from("notifications").update({ read_at: new Date().toISOString() }).eq("id", mine?.id).select("id");
  report("N3 notifikasi hanya bisa ditandai dibaca, isinya tidak bisa diubah", !!edit.error && !read.error, edit.error?.message);
  await admin.from("notifications").delete().eq("title", "rahasia relawan");

  const byFam = await k1.c.functions.invoke("pairing", { body: { action: "schedule_propose", elder_id: SRI, weekday: 3, time: "10:00" } });
  const direct = await r1.c.from("elders").update({ schedule_status: "disetujui" }).eq("id", SRI).select("id");
  report("J1 keluarga tidak bisa mengusulkan jadwal; kolom jadwal tidak bisa ditulis langsung", !!byFam.error && (!!direct.error || (direct.data?.length ?? 0) === 0));
  const prop = await r1.c.functions.invoke("pairing", { body: { action: "schedule_propose", elder_id: SRI, weekday: 3, time: "10:00" } });
  const selfOk = await r1.c.functions.invoke("pairing", { body: { action: "schedule_answer", elder_id: SRI, approve: true } });
  const ok = await k1.c.functions.invoke("pairing", { body: { action: "schedule_answer", elder_id: SRI, approve: true } });
  const sch = (await admin.from("elders").select("schedule_weekday, schedule_status").eq("id", SRI).single()).data;
  report("J2 relawan usul → hanya keluarga yang menyetujui", !prop.error && !!selfOk.error && !ok.error && sch?.schedule_status === "disetujui", JSON.stringify(sch));
  const far = await r1.c.functions.invoke("pairing", { body: { action: "schedule_shift", elder_id: SRI, at: new Date(Date.now() + 10 * 86400_000).toISOString() } });
  const near = await r1.c.functions.invoke("pairing", { body: { action: "schedule_shift", elder_id: SRI, at: new Date(Date.now() + 2 * 86400_000).toISOString() } });
  const famShift = await k1.c.functions.invoke("pairing", { body: { action: "schedule_shift", elder_id: SRI, at: new Date(Date.now() + 86400_000).toISOString() } });
  report("J3 geser maks. 7 hari dan hanya oleh relawan pasangan", !!far.error && !near.error && !!famShift.error);
  const inbox = (await k1.c.from("notifications").select("title").ilike("title", "%jadwal%")).data ?? [];
  report("J4 usulan jadwal masuk kotak masuk keluarga", inbox.length > 0, `${inbox.length} notifikasi`);
  await admin.from("elders").update({ schedule_weekday: null, schedule_time: null, schedule_status: null, schedule_shift_at: null }).eq("id", SRI);
}
// G: keluarga minta ganti pendamping (maks. 1× per 30 hari, pengganti otomatis)
{
  const rel = await k1.c.functions.invoke("pairing", { body: { action: "release", elder_id: SRI } });
  report("G1 keluarga tidak bisa melepas langsung (harus Minta ganti beralasan)", !!rel.error && (await st()) === "berpasangan");
  const noReason = await k1.c.functions.invoke("pairing", { body: { action: "change", elder_id: SRI } });
  const stranger = await k2.c.functions.invoke("pairing", { body: { action: "change", elder_id: SRI, reason: "jadwal" } });
  report("G2 ganti tanpa alasan / oleh bukan keluarga → ditolak", !!noReason.error && !!stranger.error);
  const ch = await k1.c.functions.invoke("pairing", { body: { action: "change", elder_id: SRI, reason: "jadwal", note: "uji" } });
  const pid = (ch.data as any)?.proposal_id;
  const prop = pid ? (await admin.from("proposals").select("volunteer_id, attempt").eq("id", pid).single()).data : null;
  const oldSees = (await r1.c.from("elders").select("id").eq("id", SRI)).data?.length ?? 0;
  report("G3 ganti → relawan lama kehilangan akses, usulan baru otomatis (bukan relawan lama, hitungan mulai 1)",
    !ch.error && !!prop && prop.volunteer_id !== R1 && prop.attempt === 1 && oldSees === 0, JSON.stringify(ch.error?.message ?? prop));
  if (pid) await k1.c.functions.invoke("pairing", { body: { action: "accept", proposal_id: pid } });
  const fv = (await admin.from("elders").select("first_visit_at, volunteer_id").eq("id", SRI).single()).data;
  const again = await k1.c.functions.invoke("pairing", { body: { action: "change", elder_id: SRI, reason: "tidak_cocok" } });
  report("G4 relawan baru wajib konfirmasi kunjungan pertama; ganti kedua (jatah 1× per lansia) → ditolak",
    fv?.first_visit_at === null && !!again.error && (await st()) === "berpasangan", JSON.stringify(fv));
  const sr = await k1.c.functions.invoke("review", { body: { elder_id: SRI, kind: "serius", body: "Relawan meminta uang" } });
  report("G5 jatah ganti habis → laporan serius ke yayasan tetap bisa", !sr.error);
}
// E3 & E6: akun baru dibuat lewat API (tanpa syarat), lalu diundang jadi pengurus
const calonId = await mk("calon-pengurus@demo.id");
const calon = await login("calon-pengurus@demo.id");
const prof = async () => (await admin.from("profiles").select("role, terms_accepted_at").eq("id", calonId).single()).data!;
report("E6 akun API tanpa persetujuan → terms_accepted_at kosong (aplikasi meminta setuju)", (await prof()).terms_accepted_at === null);
await calon.c.rpc("accept_terms");
report("E6 accept_terms mencatat persetujuan", (await prof()).terms_accepted_at !== null);
await y.c.rpc("add_foundation_admin", { p_email: "calon-pengurus@demo.id" });
report("E3 diundang jadi pengurus → peran belum berubah tanpa persetujuan", (await prof()).role === "keluarga");
const ai = (await calon.c.rpc("my_admin_invite")).data;
await calon.c.rpc("answer_admin_invite", { p_accept: true });
report("E3 menerima undangan → menjadi pengurus", ai?.length === 1 && (await prof()).role === "yayasan", JSON.stringify(ai));
await admin.auth.admin.deleteUser(calonId);
console.log(bad ? `\n${bad} CELAH TERSISA` : "\nSemua serangan gagal (AMAN)");
