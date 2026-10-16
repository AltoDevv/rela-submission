import { assertEquals } from "jsr:@std/assert@1";
import { familyIds, notify, recipientTokens } from "./recipients.ts";

type Row = Record<string, unknown>;
// Client palsu minimal: mendukung select().eq()/.not()/.in() sesuai pemakaian recipients.ts.
function fakeAdmin(tables: Record<string, Row[]>) {
  return {
    from: (t: string) => {
      let rows = tables[t] ?? [];
      const q: any = {
        select: () => q,
        eq: (c: string, v: unknown) => ((rows = rows.filter((r) => r[c] === v)), q),
        not: (c: string) => ((rows = rows.filter((r) => r[c] != null)), q),
        in: (c: string, v: unknown[]) => ((rows = rows.filter((r) => v.includes(r[c]))), q),
        then: (res: (x: { data: Row[] }) => unknown) => res({ data: rows }),
      };
      return q;
    },
  };
}
const elder = { id: "e1", family_id: "k1", foundation_id: "f1" };
const db = () => fakeAdmin({
  family_members: [
    { elder_id: "e1", profile_id: "k2", accepted_at: "2026-10-15" },
    { elder_id: "e1", profile_id: "k3", accepted_at: null }, // undangan belum diterima
  ],
  profiles: [
    { id: "y1", role: "yayasan", foundation_id: "f1" },
    { id: "k2", role: "keluarga", notify_off: ["pengingat"] },
    { id: "y2", role: "yayasan", foundation_id: "f2" },
  ],
  push_tokens: [
    { token: "k1-hp", profile_id: "k1" }, { token: "k1-tablet", profile_id: "k1" }, { token: "k2-hp", profile_id: "k2" },
    { token: "k3-hp", profile_id: "k3" }, { token: "r1-hp", profile_id: "r1" }, { token: "y1-hp", profile_id: "y1" },
    { token: "y2-hp", profile_id: "y2" },
  ],
});

Deno.test("familyIds: pendaftar + anggota yang sudah menerima undangan saja", async () => {
  assertEquals(await familyIds(db(), elder), ["k1", "k2"]);
});

Deno.test("recipientTokens: semua perangkat keluarga + pengurus yayasan ini, bukan undangan pending/yayasan lain", async () => {
  assertEquals((await recipientTokens(db(), elder)).sort(), ["k1-hp", "k1-tablet", "k2-hp", "y1-hp"]);
});

Deno.test("recipientTokens: pemicu tidak dikirimi, relawan bisa ditambahkan, yayasan bisa dimatikan", async () => {
  assertEquals((await recipientTokens(db(), elder, { exclude: "k1", extraIds: ["r1"], foundation: false })).sort(), ["k2-hp", "r1-hp"]);
});

Deno.test("recipientTokens: kategori yang dimatikan dilewati; tanpa kategori (darurat) tetap terkirim", async () => {
  assertEquals((await recipientTokens(db(), elder, { foundation: false, category: "pengingat" })).sort(), ["k1-hp", "k1-tablet"]);
  assertEquals((await recipientTokens(db(), elder, { foundation: false, category: "kondisi" })).sort(), ["k1-hp", "k1-tablet", "k2-hp"]);
  assertEquals((await recipientTokens(db(), elder, { foundation: false })).sort(), ["k1-hp", "k1-tablet", "k2-hp"]);
});

Deno.test("notify: dicatat per akun (juga yang tanpa perangkat), push ke semua perangkatnya", async () => {
  const inserted: Row[] = [];
  const base = fakeAdmin({ push_tokens: [{ token: "k1-hp", profile_id: "k1" }] });
  const admin = { from: (t: string) => t === "notifications" ? { insert: (rows: Row[]) => (inserted.push(...rows), { error: null }) } : base.from(t) };
  let sentTo: string[] = [];
  await notify(admin, ["k1", "k2", "k1", null], { title: "Halo", body: "Isi" }, async (tokens) => {
    sentTo = tokens;
    return { sent: tokens.length, skipped: 0, failed: 0 };
  });
  assertEquals(inserted.map((r) => r.profile_id), ["k1", "k2"]);
  assertEquals(inserted[0].title, "Halo");
  assertEquals(sentTo, ["k1-hp"]);
});
