-- Tampilan keluarga dari Figma (keputusan pengguna 16 Okt).

-- (1) Lansia: tanggal lahir (usia dihitung aplikasi) dan foto.
alter table public.elders
  add column birth_date date check (birth_date >= '1900-01-01'),
  add column photo_path text check (length(photo_path) <= 200);
grant insert (birth_date, photo_path) on public.elders to authenticated;
grant update (birth_date, photo_path) on public.elders to authenticated;

-- (2) Profil kesehatan: "Kemampuan bergerak" dipisah dari "Alat bantu" (mobility_aids kini hanya alat bantu).
alter table public.health_profiles add column mobility text check (length(mobility) <= 300);

-- (3) Profil: nama panggilan & tanggal lahir (ditampilkan ke keluarga untuk relawan), pengaturan notifikasi.
--     notify_off berisi kategori yang dimatikan: kondisi · pendamping · pengingat. Darurat tidak bisa dimatikan.
alter table public.profiles
  add column nickname text check (length(nickname) <= 40),
  add column birth_date date check (birth_date >= '1900-01-01'),
  add column notify_off text[] not null default '{}'
    check (notify_off <@ array['kondisi', 'pendamping', 'pengingat']);
grant update (nickname, birth_date, notify_off) on public.profiles to authenticated;

-- S2 diperluas: tanggal lahir relawan terverifikasi (usia ≥ 18 dicek dari KTP) juga dikunci seperti namanya.
create or replace function public.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.phone is distinct from old.phone and auth.uid() = old.id then
    new.phone_verified := false;
  end if;
  if (new.full_name is distinct from old.full_name or new.birth_date is distinct from old.birth_date)
     and auth.uid() = old.id and old.role = 'relawan'
     and exists (select 1 from public.volunteers where id = old.id and (id_checked_by is not null or oriented_by is not null)) then
    raise exception 'Nama dan tanggal lahir relawan yang sudah diverifikasi hanya bisa diubah lewat pengurus yayasan'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- (4) Status lansia setelah tiap kunjungan dikonfirmasi (Riwayat keluarga: "3 Okt · Stabil"). Diisi Edge Function
--     visit (confirm); kunjungan lama kosong.
alter table public.visits add column status_after text
  check (status_after in ('stabil', 'perlu_perhatian', 'segera_dikabari'));

-- (5) Foto lansia di bucket privat `elder-photos/<elder_id>/<file>`: keluarga mengelola, relawan pasangan membaca.
insert into storage.buckets (id, name, public) values ('elder-photos', 'elder-photos', false) on conflict do nothing;
create policy "keluarga: unggah foto lansianya" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'elder-photos' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1] and public.is_family(e.id)));
create policy "keluarga: ganti foto lansianya" on storage.objects
  for update to authenticated
  using (bucket_id = 'elder-photos' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1] and public.is_family(e.id)));
create policy "keluarga: hapus foto lansianya" on storage.objects
  for delete to authenticated
  using (bucket_id = 'elder-photos' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1] and public.is_family(e.id)));
create policy "keluarga & relawan pasangan: baca foto lansia" on storage.objects
  for select to authenticated
  using (bucket_id = 'elder-photos' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1]
      and (public.is_family(e.id) or (e.volunteer_id = auth.uid() and e.pairing_state = 'berpasangan'))));

-- (6) Kontak relawan untuk keluarga (setelah dokumen diverifikasi): + nama panggilan, tanggal lahir, keahlian, jadwal.
drop function public.my_volunteer_contact(uuid);
create function public.my_volunteer_contact(p_elder_id uuid)
returns table (full_name text, phone text, photo_path text, foundation_name text, nickname text, birth_date date,
               can_dementia boolean, can_mobility boolean, available_days text[], volunteer_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select p.full_name, p.phone, v.photo_path, f.name, p.nickname, p.birth_date,
         v.can_dementia, v.can_mobility, v.available_days, v.id
  from public.elders e join public.volunteers v on v.id = e.volunteer_id
    join public.profiles p on p.id = v.id join public.foundations f on f.id = v.foundation_id
  where e.id = p_elder_id and public.is_family(e.id)
    and e.pairing_state = 'berpasangan' and e.verify_state = 'terverifikasi'
$$;
revoke execute on function public.my_volunteer_contact from public, anon;
grant execute on function public.my_volunteer_contact to authenticated;

-- (7) Kartu usulan: + nama panggilan dan tanggal lahir relawan (Figma "Pencarian Relawan").
drop function public.get_proposal_card(uuid);
create function public.get_proposal_card(proposal_id uuid)
returns table (
  id uuid, attempt int, state text, rejects_left int, volunteer_name text, foundation_name text, photo_path text,
  can_dementia boolean, can_mobility boolean, available_days text[], languages text[], distance_km numeric,
  reason_text text, verification text, nickname text, birth_date date, elder_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.attempt, p.state, 3 - p.attempt,
    pr.full_name, f.name, v.photo_path, v.can_dementia, v.can_mobility, v.available_days, v.languages,
    greatest(1, round(p.distance_km)),
    regexp_replace(p.reason_text, 'Jarak [0-9]+,[0-9] km', 'Jarak ± ' || greatest(1, round(p.distance_km))::int || ' km'),
    concat_ws(' · ',
      case when v.id_checked_by is not null then 'Identitas dicek tatap muka oleh pengurus ' || f.name end,
      case when v.oriented_by is not null then 'Sudah mengikuti orientasi' end),
    pr.nickname, pr.birth_date, e.full_name
  from public.proposals p
  join public.elders e on e.id = p.elder_id
  join public.volunteers v on v.id = p.volunteer_id
  join public.profiles pr on pr.id = v.id
  join public.foundations f on f.id = v.foundation_id
  where p.id = get_proposal_card.proposal_id
    and e.family_id = auth.uid()
$$;
revoke execute on function public.get_proposal_card(uuid) from public, anon;
grant execute on function public.get_proposal_card(uuid) to authenticated;
