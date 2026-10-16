-- Reset data demo ke kondisi seed 01–02 (sebelum gladi/demo). Idempoten: aman dijalankan berulang.
-- Jalankan berurutan:
--   supabase db query --linked -f supabase/seeds/04_reset_demo.sql
--   supabase db query --linked -f supabase/seeds/03_visits_ibu_sri.sql   (6 kunjungan Ibu Sri, darurat dihapus)
-- Catatan: foto relawan uji di bucket volunteer-photos tidak ikut terhapus (hapus lewat dashboard Storage bila perlu).

-- 0) Anggota keluarga tambahan (tidak ada di seed).
delete from public.family_members;

-- 1) Lansia di luar seed (didaftarkan saat uji) beserta datanya.
delete from public.proposals where elder_id not in
  ('e0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002');
delete from public.elders where id not in
  ('e0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002');

-- 2) Akun di luar seed (relawan/keluarga uji). Data yang menunjuk ke relawan uji dihapus dulu.
delete from public.visits where volunteer_id not in (select id from public.volunteers where id::text like 'c0000000-%');
delete from public.emergencies where volunteer_id not in (select id from public.volunteers where id::text like 'c0000000-%');
delete from public.proposals where volunteer_id not in (select id from public.volunteers where id::text like 'c0000000-%');
delete from auth.users where email not in ('pengurus@demo.id', 'keluarga1@demo.id', 'keluarga2@demo.id',
  'relawan1@demo.id', 'relawan2@demo.id', 'relawan3@demo.id', 'relawan4@demo.id', 'relawan5@demo.id');

-- 3a) Keahlian dan centang relawan 1–4 seperti seed 02 (bisa berubah saat uji verifikasi/nonaktif).
update public.volunteers v set can_dementia = s.dem, can_mobility = s.mob,
  id_checked_by = 'a0000000-0000-0000-0000-000000000001', oriented_by = 'a0000000-0000-0000-0000-000000000001'
from (values ('c0000000-0000-0000-0000-000000000001'::uuid, true, true),
             ('c0000000-0000-0000-0000-000000000002'::uuid, false, true),
             ('c0000000-0000-0000-0000-000000000003'::uuid, true, false),
             ('c0000000-0000-0000-0000-000000000004'::uuid, false, false)) as s(id, dem, mob)
where v.id = s.id;
-- Kebutuhan lansia seperti seed 02.
update public.elders set has_dementia = false, has_mobility_issue = false where id = 'e0000000-0000-0000-0000-000000000001';
update public.elders set has_dementia = true, has_mobility_issue = false where id = 'e0000000-0000-0000-0000-000000000002';

-- 3) Pemasangan dan usulan kembali seperti seed: Ibu Sri berpasangan dengan relawan 1, Pak Harjo mencari.
delete from public.proposals;
update public.elders set volunteer_id = 'c0000000-0000-0000-0000-000000000001',
  foundation_id = 'f0000000-0000-0000-0000-000000000001', pairing_state = 'berpasangan',
  ended_reason = null, ended_at = null
  where id = 'e0000000-0000-0000-0000-000000000001';
update public.elders set volunteer_id = null, foundation_id = null, pairing_state = 'mencari',
  status = 'stabil', status_reason = null, ended_reason = null, ended_at = null
  where id = 'e0000000-0000-0000-0000-000000000002';
delete from public.visits where elder_id = 'e0000000-0000-0000-0000-000000000002';
delete from public.emergencies where elder_id = 'e0000000-0000-0000-0000-000000000002';

-- 4) Relawan 5 (Dewi) kembali "terdaftar" supaya verifikasi tatap muka bisa diperagakan.
update public.volunteers set id_checked_by = null, id_checked_at = null, oriented_by = null, oriented_at = null,
  status = 'terdaftar'
  where id = 'c0000000-0000-0000-0000-000000000005';

-- 5) Token push lama dihapus; tiap HP mendaftar ulang saat login.
update public.profiles set fcm_token = null;
delete from public.push_tokens;

-- 6) Tanda "sudah ditangani" dan nama/nomor terverifikasi seperti seed.
update public.elders set status_ack_at = null, status_ack_by = null, status_ack_note = null;
update public.profiles set phone_verified = true where role = 'relawan';

-- E3/E8 (20261015001600): undangan pengurus dan penanda pengingat kunjungan.
delete from public.foundation_admin_invites;
update public.elders set last_reminder_at = null where last_reminder_at is not null;

-- Langganan & verifikasi (20261015002000): lansia seed sudah membayar dan terverifikasi.
update public.elders set paid_until = now() + interval '365 days', verify_state = 'terverifikasi', verify_note = null,
  verified_at = coalesce(verified_at, now()), first_visit_at = coalesce(first_visit_at, now())
  where id in ('e0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002');

-- Masukan & langganan (20261015002200)
delete from public.reviews;
delete from public.payments;

-- Alur relawan (20261015002300)
delete from public.volunteer_codes;
delete from public.stop_requests;
update public.volunteers set status_note = null;

-- Ganti pendamping (20261015002600)
delete from public.pairing_changes;
