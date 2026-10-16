-- Lebih dari satu anggota keluarga per lansia (mis. tiga anak di kota berbeda). Pendaftar (elders.family_id)
-- menambahkan akun keluarga lain lewat email. Anggota melihat dan mengubah data lansia yang sama serta menerima
-- notifikasi; keputusan menerima/menolak usulan relawan tetap hanya pendaftar.
create table public.family_members (
  elder_id uuid not null references public.elders (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (elder_id, profile_id)
);
alter table public.family_members enable row level security;

create function public.is_family(e uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.elders where id = e and family_id = auth.uid())
      or exists (select 1 from public.family_members where elder_id = e and profile_id = auth.uid())
$$;

create policy "keluarga: lihat anggota keluarga lansianya" on public.family_members
  for select to authenticated using (public.is_family(elder_id));

drop policy "keluarga: baca miliknya" on public.elders;
create policy "keluarga: baca miliknya" on public.elders
  for select to authenticated using (public.is_family(id));
drop policy "keluarga: ubah miliknya" on public.elders;
create policy "keluarga: ubah miliknya" on public.elders
  for update to authenticated using (public.is_family(id)) with check (public.is_family(id));
drop policy "keluarga: kelola profil kesehatan" on public.health_profiles;
create policy "keluarga: kelola profil kesehatan" on public.health_profiles
  for all to authenticated using (public.is_family(elder_id)) with check (public.is_family(elder_id));
drop policy "keluarga: baca usulan lansianya" on public.proposals;
create policy "keluarga: baca usulan lansianya" on public.proposals
  for select to authenticated using (public.is_family(elder_id));
drop policy "keluarga: baca kunjungan lansianya" on public.visits;
create policy "keluarga: baca kunjungan lansianya" on public.visits
  for select to authenticated using (public.is_family(elder_id));
drop policy "keluarga: baca darurat lansianya" on public.emergencies;
create policy "keluarga: baca darurat lansianya" on public.emergencies
  for select to authenticated using (public.is_family(elder_id));

-- Tambah anggota: hanya pendaftar; yang ditambahkan harus akun keluarga yang sudah ada.
create function public.add_family_member(p_elder_id uuid, p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid;
  target_name text;
begin
  if not exists (select 1 from public.elders where id = p_elder_id and family_id = auth.uid()) then
    raise exception 'Hanya keluarga yang mendaftarkan lansia ini' using errcode = '42501';
  end if;
  select u.id, p.full_name into target, target_name
    from auth.users u join public.profiles p on p.id = u.id
    where lower(u.email) = lower(trim(p_email)) and p.role = 'keluarga';
  if target is null then
    raise exception 'Akun keluarga dengan email itu tidak ditemukan. Minta ia mendaftar sebagai Keluarga dulu.';
  end if;
  if target = auth.uid() then
    raise exception 'Itu akun Anda sendiri';
  end if;
  insert into public.family_members (elder_id, profile_id) values (p_elder_id, target) on conflict do nothing;
  return coalesce(target_name, p_email);
end;
$$;

-- Hapus anggota: pendaftar boleh menghapus siapa pun, anggota boleh keluar sendiri.
create function public.remove_family_member(p_elder_id uuid, p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (p_profile_id = auth.uid()
          or exists (select 1 from public.elders where id = p_elder_id and family_id = auth.uid())) then
    raise exception 'Tidak berhak' using errcode = '42501';
  end if;
  delete from public.family_members where elder_id = p_elder_id and profile_id = p_profile_id;
end;
$$;

-- Daftar anggota beserta nama (profiles tidak bisa dibaca antar-pengguna).
create function public.family_member_list(p_elder_id uuid)
returns table (profile_id uuid, full_name text, is_owner boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select e.family_id, p.full_name, true from public.elders e join public.profiles p on p.id = e.family_id
    where e.id = p_elder_id and public.is_family(p_elder_id)
  union all
  select m.profile_id, p.full_name, false from public.family_members m join public.profiles p on p.id = m.profile_id
    where m.elder_id = p_elder_id and public.is_family(p_elder_id)
$$;

revoke execute on function public.add_family_member, public.remove_family_member, public.family_member_list,
  public.is_family from public, anon;
grant execute on function public.add_family_member, public.remove_family_member, public.family_member_list,
  public.is_family to authenticated;
