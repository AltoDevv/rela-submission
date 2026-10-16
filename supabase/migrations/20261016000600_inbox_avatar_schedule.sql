-- Perbaikan 16 Okt: kotak masuk notifikasi, foto profil akun, jadwal kunjungan rutin.

-- (1) Kotak masuk: setiap push juga dicatat per akun (Edge Function, helper notify di _shared/recipients.ts).
--     Pengguna hanya membaca miliknya dan hanya bisa menandai sudah dibaca.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(title) <= 200),
  body text not null check (length(body) <= 1000),
  data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_profile on public.notifications (profile_id, created_at desc);
alter table public.notifications enable row level security;
create policy "akun: baca notifikasinya" on public.notifications
  for select to authenticated using (profile_id = auth.uid());
create policy "akun: tandai dibaca" on public.notifications
  for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;
alter publication supabase_realtime add table public.notifications;

-- (2) Foto profil akun keluarga & yayasan di bucket privat `avatars/<profile_id>/<file>` (hanya pemiliknya).
--     Foto relawan tetap foto wajah verifikasi (volunteer-photos) dan tidak diganti dari sini.
alter table public.profiles add column avatar_path text check (length(avatar_path) <= 200);
grant update (avatar_path) on public.profiles to authenticated;
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', false) on conflict do nothing;
create policy "akun: kelola foto profilnya" on storage.objects
  for all to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- (3) Jadwal kunjungan rutin (keputusan pengguna 16 Okt): relawan mengusulkan hari & jam, keluarga menyetujui;
--     relawan bisa menggeser satu kunjungan (schedule_shift_at). Ditulis Edge Function pairing (service role).
alter table public.elders
  add column schedule_weekday smallint check (schedule_weekday between 1 and 7), -- 1 = Senin … 7 = Minggu
  add column schedule_time time,
  add column schedule_status text check (schedule_status in ('diusulkan', 'disetujui')),
  add column schedule_shift_at timestamptz;

-- Pendamping berganti → jadwal lama tidak berlaku lagi.
create function public.elders_schedule_reset()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.volunteer_id is distinct from old.volunteer_id then
    new.schedule_weekday := null;
    new.schedule_time := null;
    new.schedule_status := null;
    new.schedule_shift_at := null;
  end if;
  return new;
end;
$$;
create trigger elders_schedule_reset before update of volunteer_id on public.elders
  for each row execute function public.elders_schedule_reset();
