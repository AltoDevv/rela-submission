-- T-003: akun demo. Idempoten, aman dijalankan berulang.
-- Jalankan: supabase db query --linked -f supabase/seeds/01_accounts.sql
-- Semua password: demo1234. UUID tetap supaya seed berikutnya bisa merujuknya.

insert into public.foundations (id, name, verified, invite_code)
values ('f0000000-0000-0000-0000-000000000001', 'Yayasan Demo', true, 'SENJA1')
on conflict do nothing;

-- Trigger sign-up menolak role yayasan, jadi pengurus dibuat sebagai relawan lalu diubah di bawah.
with accounts (id, email, role, full_name, phone) as (
  values
    ('a0000000-0000-0000-0000-000000000001'::uuid, 'pengurus@demo.id',  'relawan',  'Pengurus Yayasan Demo', '081200000001'),
    ('b0000000-0000-0000-0000-000000000001'::uuid, 'keluarga1@demo.id', 'keluarga', 'Rina (anak Ibu Sri)',   '081200000011'),
    ('b0000000-0000-0000-0000-000000000002'::uuid, 'keluarga2@demo.id', 'keluarga', 'Budi',                  '081200000012'),
    ('c0000000-0000-0000-0000-000000000001'::uuid, 'relawan1@demo.id',  'relawan',  'Maria',                 '081200000021'),
    ('c0000000-0000-0000-0000-000000000002'::uuid, 'relawan2@demo.id',  'relawan',  'Yohanes',               '081200000022'),
    ('c0000000-0000-0000-0000-000000000003'::uuid, 'relawan3@demo.id',  'relawan',  'Siti',                  '081200000023'),
    ('c0000000-0000-0000-0000-000000000004'::uuid, 'relawan4@demo.id',  'relawan',  'Agus',                  '081200000024'),
    ('c0000000-0000-0000-0000-000000000005'::uuid, 'relawan5@demo.id',  'relawan',  'Dewi',                  '081200000025')
),
new_users as (
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  select
    '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
    extensions.crypt('demo1234', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('role', role, 'full_name', full_name, 'phone', phone), now(), now(),
    '', '', '', ''
  from accounts
  on conflict do nothing
  returning id, email
)
insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text, 'email',
  jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), now(), now(), now()
from new_users
on conflict do nothing;

update public.profiles set role = 'yayasan', phone_verified = true,
  foundation_id = 'f0000000-0000-0000-0000-000000000001'
where id = 'a0000000-0000-0000-0000-000000000001';

update public.profiles set phone_verified = true,
  foundation_id = 'f0000000-0000-0000-0000-000000000001'
where id in (
  'c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002',
  'c0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004',
  'c0000000-0000-0000-0000-000000000005'
);
