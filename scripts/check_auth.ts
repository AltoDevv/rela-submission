// Cek T-003: trigger sign-up, RLS profiles, dan seed akun demo.
// Jalankan dari root: deno run -A scripts/check_auth.ts
import { createClient } from "npm:@supabase/supabase-js@2";

const env = Object.fromEntries(
  Deno.readTextFileSync(".env.local").split("\n")
    .filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")).trim(), l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, "")]),
);
const url = env.SUPABASE_URL;
const anonKey = env.SUPABASE_PUBLISHABLE_KEY;
const admin = createClient(url, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const client = () => createClient(url, anonKey, { auth: { persistSession: false } });

let failed = 0;
function check(name: string, ok: boolean, detail = "") {
  console.log(`${ok ? "LULUS" : "GAGAL"}  ${name}${ok || !detail ? "" : `  (${detail})`}`);
  if (!ok) failed++;
}

async function login(email: string) {
  const c = client();
  const { data, error } = await c.auth.signInWithPassword({ email, password: "demo1234" });
  if (error) throw new Error(`login ${email}: ${error.message}`);
  return { c, id: data.user.id };
}

const stamp = Date.now();

// 1. Sign-up sebagai yayasan harus ditolak trigger.
{
  const { data, error } = await client().auth.signUp({
    email: `cek-yayasan-${stamp}@demo.id`,
    password: "demo1234",
    options: { data: { role: "yayasan", full_name: "Penyusup" } },
  });
  check("sign-up role yayasan ditolak", !!error && !data.user, error?.message ?? "tidak ada error");
}

// 2. Sign-up sebagai keluarga berhasil dan membuat baris profiles.
{
  const c = client();
  const { data, error } = await c.auth.signUp({
    email: `cek-keluarga-${stamp}@demo.id`,
    password: "demo1234",
    options: { data: { role: "keluarga", full_name: "Cek Keluarga", phone: "0811" } },
  });
  check("sign-up role keluarga berhasil", !error && !!data.session, error?.message ?? "tidak ada session");
  if (data.user) {
    const { data: rows } = await c.from("profiles").select("role, full_name, phone").eq("id", data.user.id);
    check(
      "profil keluarga dibuat trigger",
      rows?.length === 1 && rows[0].role === "keluarga" && rows[0].full_name === "Cek Keluarga",
      JSON.stringify(rows),
    );
    await admin.auth.admin.deleteUser(data.user.id);
  }
}

// 3. RLS: hanya baris sendiri yang terbaca, role/foundation_id tidak bisa diubah.
{
  const { c, id } = await login("keluarga1@demo.id");
  const { id: otherId } = await login("relawan1@demo.id");

  const { data: all } = await c.from("profiles").select("id");
  check("keluarga1 hanya melihat 1 profil (miliknya)", all?.length === 1 && all[0].id === id, JSON.stringify(all));

  const { data: other } = await c.from("profiles").select("id").eq("id", otherId);
  check("keluarga1 tidak bisa membaca profil relawan1", other?.length === 0, JSON.stringify(other));

  const { error: roleErr } = await c.from("profiles").update({ role: "yayasan" }).eq("id", id);
  check("update role milik sendiri gagal", !!roleErr);

  const { error: fErr } = await c.from("profiles")
    .update({ foundation_id: "f0000000-0000-0000-0000-000000000001" }).eq("id", id);
  check("update foundation_id milik sendiri gagal", !!fErr);

  // Tulis ulang nama yang sama supaya data demo tidak berubah.
  const { data: cur } = await c.from("profiles").select("full_name").eq("id", id).single();
  const { data: upd, error: nameErr } = await c.from("profiles")
    .update({ full_name: cur?.full_name }).eq("id", id).select("full_name");
  check("update full_name milik sendiri berhasil", !nameErr && upd?.length === 1, nameErr?.message);

  const { data: upd2 } = await c.from("profiles").update({ full_name: "Diretas" }).eq("id", otherId).select();
  check("update profil orang lain tidak mengubah apa pun", upd2?.length === 0, JSON.stringify(upd2));

  const { data: me } = await c.from("profiles").select("role").eq("id", id).single();
  check("role keluarga1 tetap keluarga", me?.role === "keluarga", JSON.stringify(me));
}

// 4. Seed: semua akun demo bisa login dengan peran yang benar.
{
  const expected: Record<string, string> = {
    "pengurus@demo.id": "yayasan",
    "keluarga1@demo.id": "keluarga",
    "keluarga2@demo.id": "keluarga",
  };
  for (let i = 1; i <= 5; i++) expected[`relawan${i}@demo.id`] = "relawan";

  for (const [email, role] of Object.entries(expected)) {
    try {
      const { c, id } = await login(email);
      const { data } = await c.from("profiles").select("role").eq("id", id).single();
      check(`seed ${email} login, peran ${role}`, data?.role === role, JSON.stringify(data));
    } catch (e) {
      check(`seed ${email} login`, false, (e as Error).message);
    }
  }

  const { c } = await login("pengurus@demo.id");
  const { data: f } = await c.from("foundations").select("name, verified, invite_code").maybeSingle();
  check(
    "pengurus melihat Yayasan Demo terverifikasi, kode SENJA1",
    f?.verified === true && f?.invite_code === "SENJA1",
    JSON.stringify(f),
  );
}

console.log(failed ? `\n${failed} cek gagal` : "\nSemua cek lulus");
Deno.exit(failed ? 1 : 0);
