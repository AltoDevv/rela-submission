// Cek T-011: Edge Function `pairing` dan RPC get_proposal_card (Alur A, PRD F2 dan F2a).
// Butuh seed 01 dan 02, migration 0300, dan fungsi `pairing` yang sudah di-deploy.
// Jalankan dari root: deno run -A scripts/try_pairing.ts [--keep]
// --keep: Pak Harjo dibiarkan `perlu_yayasan` beserta 3 usulan yang ditolak (dipakai T-019).
import {
  createClient,
  FunctionsHttpError,
  SupabaseClient,
} from "npm:@supabase/supabase-js@2";

const env = Object.fromEntries(
  Deno.readTextFileSync(".env.local").split("\n")
    .filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((
      l,
    ) => [
      l.slice(0, l.indexOf("=")).trim(),
      l.slice(l.indexOf("=") + 1).trim().replace(/^"|"$/g, ""),
    ]),
);
const opts = { auth: { persistSession: false } };
const admin = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  opts,
);
const keep = Deno.args.includes("--keep");

const SRI = "e0000000-0000-0000-0000-000000000001";
const HARJO = "e0000000-0000-0000-0000-000000000002"; // milik keluarga 2

let failed = 0;
function check(name: string, ok: boolean, detail = "") {
  console.log(
    `${ok ? "LULUS" : "GAGAL"}  ${name}${ok || !detail ? "" : `  (${detail})`}`,
  );
  if (!ok) failed++;
}

async function login(email: string): Promise<SupabaseClient> {
  const c = createClient(env.SUPABASE_URL, env.SUPABASE_PUBLISHABLE_KEY, opts);
  const { error } = await c.auth.signInWithPassword({
    email,
    password: "demo1234",
  });
  if (error) throw new Error(`login ${email}: ${error.message}`);
  return c;
}

/** Memanggil fungsi `pairing`, mengembalikan status HTTP dan body. */
async function pairing(c: SupabaseClient, body: Record<string, unknown>) {
  const { data, error } = await c.functions.invoke("pairing", { body });
  if (error instanceof FunctionsHttpError) {
    return {
      status: error.context.status as number,
      body: await error.context.json().catch(() => null),
    };
  }
  if (error) throw error;
  return { status: 200, body: data };
}

async function harjo() {
  const { data } = await admin.from("elders").select(
    "pairing_state, volunteer_id, foundation_id",
  )
    .eq("id", HARJO).single();
  return data!;
}
const harjoProposals = async () =>
  (await admin.from("proposals").select("*").eq("elder_id", HARJO).order(
    "attempt",
  )).data!;

async function reset() {
  await admin.from("proposals").delete().eq("elder_id", HARJO);
  await admin.from("elders").update({
    volunteer_id: null,
    foundation_id: null,
    pairing_state: "mencari",
  })
    .eq("id", HARJO);
}

const k1 = await login("keluarga1@demo.id");
const k2 = await login("keluarga2@demo.id");

// Pak Harjo punya demensia, padahal hanya 2 relawan aktif yang mampu. Supaya bisa ditolak 3 kali,
// syarat demensia dimatikan sementara dan selalu dikembalikan di akhir.
const { data: orig } = await admin.from("elders").select("has_dementia").eq(
  "id",
  HARJO,
).single();
await reset();
await admin.from("elders").update({ has_dementia: false }).eq("id", HARJO);

try {
  // 1. Keluarga lain tidak bisa menerima usulan lansia keluarga 1.
  const { data: fake, error: fakeErr } = await admin.from("proposals").insert({
    elder_id: SRI,
    volunteer_id: "c0000000-0000-0000-0000-000000000004",
    attempt: 1,
    distance_km: 1,
    reason_text: "uji",
    state: "pending",
  }).select("id").single();
  if (fakeErr) throw fakeErr;
  const forbidden = await pairing(k2, {
    action: "accept",
    proposal_id: fake.id,
  });
  check(
    "keluarga 2 accept usulan lansia keluarga 1 → 403",
    forbidden.status === 403,
    `status ${forbidden.status}`,
  );
  const { data: card2 } = await k2.rpc("get_proposal_card", {
    proposal_id: fake.id,
  });
  check(
    "keluarga 2 tidak bisa membuka kartu usulan keluarga 1",
    (card2 ?? []).length === 0,
  );
  const forbiddenPropose = await pairing(k1, {
    action: "propose",
    elder_id: HARJO,
  });
  check(
    "keluarga 1 propose untuk lansia keluarga 2 → 403",
    forbiddenPropose.status === 403,
  );
  await admin.from("proposals").delete().eq("id", fake.id);

  // 2. Usulan → kartu → terima → relawan melihat lansia.
  const p1 = await pairing(k2, { action: "propose", elder_id: HARJO });
  check("propose → 200", p1.status === 200, JSON.stringify(p1.body));
  check(
    "propose → menunggu_keluarga",
    (await harjo()).pairing_state === "menunggu_keluarga",
  );
  const [first] = await harjoProposals();

  const { data: cards, error: cardErr } = await k2.rpc("get_proposal_card", {
    proposal_id: first.id,
  });
  const card = cards?.[0] ?? {};
  check(
    "kartu usulan terbaca keluarga pemilik",
    !cardErr && !!card.volunteer_name,
    cardErr?.message,
  );
  check(
    "kartu berisi nama, yayasan, keahlian, hari, bahasa, jarak, alasan, verifikasi, foto",
    [
      "volunteer_name",
      "foundation_name",
      "can_dementia",
      "can_mobility",
      "available_days",
      "languages",
      "distance_km",
      "reason_text",
      "verification",
      "photo_path",
    ].every((k) => k in card),
    Object.keys(card).join(","),
  );
  check(
    "kartu tanpa HP dan lat/lng relawan",
    !["phone", "lat", "lng"].some((k) => k in card),
  );

  const badReject = await pairing(k2, {
    action: "reject",
    proposal_id: first.id,
    reason: "lainnya",
  });
  check("tolak 'lainnya' tanpa teks → 400", badReject.status === 400);
  const noReason = await pairing(k2, {
    action: "reject",
    proposal_id: first.id,
  });
  check("tolak tanpa alasan → 400", noReason.status === 400);

  const acc = await pairing(k2, { action: "accept", proposal_id: first.id });
  const after = await harjo();
  check(
    "accept → berpasangan",
    acc.status === 200 && after.pairing_state === "berpasangan",
    JSON.stringify(acc.body),
  );
  const n = first.volunteer_id.slice(-1);
  const relawan = await login(`relawan${n}@demo.id`);
  const { data: seen } = await relawan.from("elders").select("id").eq(
    "id",
    HARJO,
  );
  check(`setelah accept, relawan ${n} melihat Pak Harjo`, seen?.length === 1);
  const again = await pairing(k2, { action: "accept", proposal_id: first.id });
  check("accept usulan yang sudah diterima → 409", again.status === 409);

  // 3. Tolak 3 kali → perlu_yayasan, relawan tidak diulang, tidak ada usulan ke-4.
  await reset();
  await pairing(k2, { action: "propose", elder_id: HARJO });
  const reasons = [{ reason: "jarak" }, { reason: "jadwal" }, {
    reason: "lainnya",
    note: "Ingin relawan perempuan",
  }];
  for (const r of reasons) {
    const pending = (await harjoProposals()).find((p) => p.state === "pending");
    if (!pending) break;
    const res = await pairing(k2, {
      action: "reject",
      proposal_id: pending.id,
      ...r,
    });
    if (res.status !== 200) {
      check(`reject ${r.reason} → 200`, false, JSON.stringify(res.body));
    }
  }
  const all = await harjoProposals();
  check(
    "3 usulan, semuanya ditolak",
    all.length === 3 && all.every((p) => p.state === "rejected"),
    all.map((p) => `${p.attempt}:${p.state}`).join(" "),
  );
  check(
    "relawan yang ditolak tidak diusulkan lagi",
    new Set(all.map((p) => p.volunteer_id)).size === all.length,
  );
  check(
    "tolak 3× → perlu_yayasan",
    (await harjo()).pairing_state === "perlu_yayasan",
  );
  const fourth = await pairing(k2, { action: "propose", elder_id: HARJO });
  check(
    "tidak ada usulan ke-4 (propose → 409)",
    fourth.status === 409 && (await harjoProposals()).length === 3,
  );
  check(
    "alasan 'lainnya' tersimpan dengan teks",
    all[2]?.reject_note === "Ingin relawan perempuan",
  );

  // 4. Pemasangan manual: khusus pengurus yayasan, hanya untuk perlu_yayasan.
  const yay = await login("pengurus@demo.id");
  const rejected = all.map((p) => p.volunteer_id);
  const manualVol = [1, 2, 3, 4].map((i) =>
    `c0000000-0000-0000-0000-00000000000${i}`
  )
    .find((id) => !rejected.includes(id))!;
  const byFamily = await pairing(k2, {
    action: "manual",
    elder_id: HARJO,
    volunteer_id: manualVol,
  });
  check("keluarga memanggil manual → 403", byFamily.status === 403);
  const notNeeded = await pairing(yay, {
    action: "manual",
    elder_id: SRI,
    volunteer_id: manualVol,
  });
  check(
    "manual untuk lansia yang tidak perlu_yayasan → 409",
    notNeeded.status === 409,
  );
  const manual = await pairing(yay, {
    action: "manual",
    elder_id: HARJO,
    volunteer_id: manualVol,
  });
  const m = await harjo();
  check(
    "pengurus memasangkan manual → berpasangan",
    manual.status === 200 && m.pairing_state === "berpasangan" &&
      m.volunteer_id === manualVol,
    JSON.stringify(manual.body),
  );
  // Kembalikan ke perlu_yayasan supaya --keep menyisakan lansia untuk T-019.
  await admin.from("proposals").delete().eq("elder_id", HARJO).eq(
    "state",
    "manual",
  );
  await admin.from("elders").update({
    volunteer_id: null,
    foundation_id: null,
    pairing_state: "perlu_yayasan",
  })
    .eq("id", HARJO);
} finally {
  await admin.from("elders").update({ has_dementia: orig!.has_dementia }).eq(
    "id",
    HARJO,
  );
  if (keep) console.log("--keep: Pak Harjo dibiarkan perlu_yayasan");
  else await reset();
}

console.log(failed === 0 ? "\nSemua cek lulus." : `\n${failed} cek gagal.`);
Deno.exit(failed === 0 ? 0 : 1);
