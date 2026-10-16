-- T-007: skema inti MVP, RLS (architecture.md bagian 6), bucket foto, dan Realtime.
-- Tulisan yang dilindungi (proposals, emergencies, pasangan lansia, status) dilakukan Edge Function
-- dengan service_role, jadi tabel-tabel itu sengaja tidak punya policy tulis untuk aplikasi.

-- Foundation milik pemanggil bila dia pengurus yayasan, selain itu null.
-- security definer supaya policy tidak saling memanggil RLS tabel lain (rekursi).
create function public.my_admin_foundation()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select foundation_id from public.profiles where id = auth.uid() and role = 'yayasan'
$$;

create table public.volunteers (
  id uuid primary key references public.profiles (id) on delete cascade,
  foundation_id uuid not null references public.foundations (id),
  status text not null default 'terdaftar' check (status in ('terdaftar', 'aktif')),
  area_label text check (length(area_label) <= 100),
  lat float8,
  lng float8,
  available_days text[] not null default '{}',
  languages text[] not null default '{}',
  can_dementia boolean not null default false,
  can_mobility boolean not null default false,
  photo_path text,
  id_checked_by uuid references public.profiles (id),
  id_checked_at timestamptz,
  oriented_by uuid references public.profiles (id),
  oriented_at timestamptz,
  max_load int not null default 3 check (max_load > 0),
  created_at timestamptz not null default now()
);

create table public.elders (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.profiles (id) on delete cascade,
  full_name text not null check (length(full_name) between 1 and 100),
  address text not null check (length(address) <= 300),
  lat float8,
  lng float8,
  needs text check (length(needs) <= 500),
  has_dementia boolean not null default false,
  has_mobility_issue boolean not null default false,
  volunteer_id uuid references public.volunteers (id),
  foundation_id uuid references public.foundations (id),
  pairing_state text not null default 'mencari'
    check (pairing_state in ('mencari', 'menunggu_keluarga', 'berpasangan', 'tanpa_pendamping', 'perlu_yayasan')),
  status text not null default 'stabil' check (status in ('stabil', 'perlu_perhatian', 'segera_dikabari')),
  status_reason text check (length(status_reason) <= 1000),
  created_at timestamptz not null default now()
);

create table public.health_profiles (
  elder_id uuid primary key references public.elders (id) on delete cascade,
  conditions text,
  allergies text,
  medications jsonb not null default '[]' check (jsonb_typeof(medications) = 'array'),
  diet_restrictions text,
  mobility_aids text,
  doctor_hospital text,
  emergency_instructions text,
  has_chronic boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid not null references public.volunteers (id) on delete cascade,
  attempt int not null check (attempt between 1 and 3),
  distance_km numeric not null,
  reason_text text not null,
  state text not null default 'pending' check (state in ('pending', 'accepted', 'rejected', 'manual')),
  reject_reason text check (reject_reason in ('jarak', 'jadwal', 'bahasa', 'lainnya')),
  reject_note text check (length(reject_note) <= 300),
  created_at timestamptz not null default now(),
  unique (elder_id, volunteer_id),
  check (reject_reason is distinct from 'lainnya' or coalesce(length(trim(reject_note)), 0) > 0)
);

-- Relawan yang sedang "dipesan" tidak bisa diusulkan ke lansia lain.
create unique index proposals_one_pending_per_volunteer on public.proposals (volunteer_id) where state = 'pending';

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid not null references public.volunteers (id),
  visited_at timestamptz not null default now(),
  answers jsonb not null default '{}' check (jsonb_typeof(answers) = 'object'),
  ai_result jsonb,
  final_result jsonb,
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);
create index visits_elder_idx on public.visits (elder_id, visited_at);

create table public.emergencies (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid not null references public.volunteers (id),
  lat float8,
  lng float8,
  summary text,
  notified boolean not null default false,
  created_at timestamptz not null default now()
);

-- Dua centang (F1b): relawan tidak bisa mencentang dirinya, yayasan hanya boleh mengubah centang,
-- dan begitu kedua centang terisi status menjadi aktif. Seed dan service_role (auth.uid() null) bebas.
create function public.volunteers_checks()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  check_cols text[] := array['id_checked_by', 'id_checked_at', 'oriented_by', 'oriented_at', 'status'];
begin
  if tg_op = 'UPDATE' and auth.uid() is not null then
    if auth.uid() = old.id then
      if (to_jsonb(new) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path')
         is distinct from
         (to_jsonb(old) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path') then
        raise exception 'Relawan tidak bisa memverifikasi dirinya sendiri';
      end if;
    elsif (to_jsonb(new) - check_cols) is distinct from (to_jsonb(old) - check_cols) then
      raise exception 'Yayasan hanya boleh mengubah centang verifikasi';
    end if;
  end if;

  if new.id_checked_by is distinct from old.id_checked_by or tg_op = 'INSERT' then
    new.id_checked_at := case when new.id_checked_by is null then null else coalesce(new.id_checked_at, now()) end;
  end if;
  if new.oriented_by is distinct from old.oriented_by or tg_op = 'INSERT' then
    new.oriented_at := case when new.oriented_by is null then null else coalesce(new.oriented_at, now()) end;
  end if;
  if new.id_checked_by is not null and new.oriented_by is not null then
    new.status := 'aktif';
  end if;
  return new;
end;
$$;

create trigger volunteers_checks
  before insert or update on public.volunteers
  for each row execute function public.volunteers_checks();

-- Hak kolom: aplikasi hanya boleh menulis kolom yang memang diisi pengguna.
revoke insert, update on public.volunteers, public.elders from anon, authenticated;
grant update (area_label, lat, lng, available_days, languages, can_dementia, can_mobility, photo_path,
  id_checked_by, oriented_by) on public.volunteers to authenticated;
grant insert (family_id, full_name, address, lat, lng, needs, has_dementia, has_mobility_issue)
  on public.elders to authenticated;
grant update (full_name, address, lat, lng, needs, has_dementia, has_mobility_issue)
  on public.elders to authenticated;

alter table public.volunteers enable row level security;
alter table public.elders enable row level security;
alter table public.health_profiles enable row level security;
alter table public.proposals enable row level security;
alter table public.visits enable row level security;
alter table public.emergencies enable row level security;

-- volunteers: relawan dirinya; yayasan relawan di yayasannya (termasuk dua centang). Keluarga lewat RPC.
create policy "relawan: baca diri" on public.volunteers
  for select to authenticated using (id = auth.uid());
create policy "relawan: ubah diri" on public.volunteers
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "yayasan: baca relawannya" on public.volunteers
  for select to authenticated using (foundation_id = public.my_admin_foundation());
create policy "yayasan: centang relawannya" on public.volunteers
  for update to authenticated
  using (foundation_id = public.my_admin_foundation())
  with check (foundation_id = public.my_admin_foundation());

-- elders
create policy "keluarga: baca miliknya" on public.elders
  for select to authenticated using (family_id = auth.uid());
create policy "keluarga: daftarkan" on public.elders
  for insert to authenticated
  with check (family_id = auth.uid()
    and (select role from public.profiles where id = auth.uid()) = 'keluarga');
create policy "keluarga: ubah miliknya" on public.elders
  for update to authenticated using (family_id = auth.uid()) with check (family_id = auth.uid());
create policy "relawan: baca pasangannya" on public.elders
  for select to authenticated using (volunteer_id = auth.uid());
create policy "yayasan: baca yayasannya dan yang butuh bantuan" on public.elders
  for select to authenticated
  using (public.my_admin_foundation() is not null
    and (foundation_id = public.my_admin_foundation() or pairing_state in ('tanpa_pendamping', 'perlu_yayasan')));

-- health_profiles: keluarga dan relawan pasangan. Yayasan tidak punya policy sama sekali.
create policy "keluarga: kelola profil kesehatan" on public.health_profiles
  for all to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.family_id = auth.uid()))
  with check (exists (select 1 from public.elders e where e.id = elder_id and e.family_id = auth.uid()));
create policy "relawan: baca profil kesehatan pasangannya" on public.health_profiles
  for select to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.volunteer_id = auth.uid()));

-- proposals: hanya baca. Relawan tidak punya policy, supaya tidak tahu dirinya ditolak.
create policy "keluarga: baca usulan lansianya" on public.proposals
  for select to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.family_id = auth.uid()));
create policy "yayasan: baca usulan relawannya" on public.proposals
  for select to authenticated
  using (exists (select 1 from public.volunteers v
                 where v.id = volunteer_id and v.foundation_id = public.my_admin_foundation()));

-- visits
create policy "keluarga: baca kunjungan lansianya" on public.visits
  for select to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.family_id = auth.uid()));
create policy "relawan: baca kunjungan pasangannya" on public.visits
  for select to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.volunteer_id = auth.uid()));
create policy "relawan: tulis kunjungan pasangannya" on public.visits
  for insert to authenticated
  with check (volunteer_id = auth.uid()
    and exists (select 1 from public.elders e where e.id = elder_id and e.volunteer_id = auth.uid()));
create policy "relawan: ubah kunjungan pasangannya" on public.visits
  for update to authenticated
  using (volunteer_id = auth.uid()
    and exists (select 1 from public.elders e where e.id = elder_id and e.volunteer_id = auth.uid()))
  with check (volunteer_id = auth.uid());
create policy "yayasan: baca kunjungan yayasannya" on public.visits
  for select to authenticated
  using (exists (select 1 from public.elders e
                 where e.id = elder_id and e.foundation_id = public.my_admin_foundation()));

-- emergencies: dibuat oleh fungsi emergency (service_role).
create policy "keluarga: baca darurat lansianya" on public.emergencies
  for select to authenticated
  using (exists (select 1 from public.elders e where e.id = elder_id and e.family_id = auth.uid()));
create policy "yayasan: baca darurat yayasannya" on public.emergencies
  for select to authenticated
  using (exists (select 1 from public.elders e
                 where e.id = elder_id and e.foundation_id = public.my_admin_foundation()));

-- Foto relawan: bucket privat, path `<volunteer_id>/<file>`. Keluarga lewat signed URL dari RPC.
insert into storage.buckets (id, name, public) values ('volunteer-photos', 'volunteer-photos', false)
on conflict (id) do nothing;

create policy "relawan: kelola foto sendiri" on storage.objects
  for all to authenticated
  using (bucket_id = 'volunteer-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'volunteer-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "yayasan: baca foto relawannya" on storage.objects
  for select to authenticated
  using (bucket_id = 'volunteer-photos' and exists (
    select 1 from public.volunteers v
    where v.id::text = (storage.foldername(name))[1] and v.foundation_id = public.my_admin_foundation()));

alter publication supabase_realtime add table public.elders, public.visits;
