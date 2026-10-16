// Permintaan berhenti mendampingi yang diterima (oleh yayasan atau otomatis setelah 7 hari): kabari keluarga dan
// relawan. Dipakai pairing (approve_stop) dan reminders (otomatis).
// deno-lint-ignore-file no-explicit-any
import { notify, recipientIds } from "./recipients.ts";

export async function approveStop(admin: any, requestId: string, by: string): Promise<boolean> {
  const { data } = await admin.rpc("approve_stop_request", { p_id: requestId, p_by: by });
  const row = (data ?? [])[0];
  if (!row) return false;
  try {
    const { data: elder } = await admin.from("elders").select("id, full_name, family_id, foundation_id")
      .eq("id", row.elder_id).single();
    await notify(admin, await recipientIds(admin, elder, { extraIds: [row.volunteer_id], foundation: false, category: "pendamping" }), {
      title: `Pendamping ${elder.full_name} berganti`,
      body: "Relawan berhenti mendampingi. Sistem mencarikan relawan pengganti; usulannya akan muncul di aplikasi.",
      data: { elder_id: elder.id, type: "pendamping_dilepas" },
    });
  } catch (e) {
    console.error("push gagal", e);
  }
  return true;
}
