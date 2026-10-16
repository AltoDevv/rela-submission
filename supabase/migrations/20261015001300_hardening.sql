-- Pengerasan dari serangan 15 Okt (semua terbukti lewat API sebagai pengguna biasa).

-- S1: yayasan lain membaca kutipan kesehatan + alamat lansia perlu_yayasan. Lansia yang pernah punya yayasan
-- hanya terlihat oleh yayasannya; yang belum pernah (foundation_id null) tetap terlihat semua yayasan (PRD F2).
drop policy "yayasan: baca yayasannya dan yang butuh bantuan" on public.elders;
create policy "yayasan: baca yayasannya dan yang butuh bantuan" on public.elders
  for select to authenticated
  using (public.my_admin_foundation() is not null
    and (foundation_id = public.my_admin_foundation()
         or (foundation_id is null and pairing_state in ('tanpa_pendamping', 'perlu_yayasan'))));

-- S3: phone_verified hanya diisi server (join_foundation). Nomor diganti → belum terverifikasi lagi.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, fcm_token) on public.profiles to authenticated;

-- S2: nama relawan terverifikasi tidak bisa diganti sendiri; foto baru → verifikasi ulang (di volunteers_checks).
create function public.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.phone is distinct from old.phone and auth.uid() = old.id then
    new.phone_verified := false;
  end if;
  if new.full_name is distinct from old.full_name and auth.uid() = old.id and old.role = 'relawan'
     and exists (select 1 from public.volunteers where id = old.id and (id_checked_by is not null or oriented_by is not null)) then
    raise exception 'Nama relawan yang sudah diverifikasi hanya bisa diubah lewat pengurus yayasan' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger profiles_guard before update on public.profiles for each row execute function public.profiles_guard();

create or replace function public.volunteers_checks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  check_cols text[] := array['id_checked_by', 'id_checked_at', 'oriented_by', 'oriented_at', 'status'];
  by_self boolean := tg_op = 'UPDATE' and auth.uid() is not null and auth.uid() = old.id;
begin
  if tg_op = 'UPDATE' and auth.uid() is not null then
    if by_self then
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

  -- Keahlian baru atau foto wajah baru yang diisi sendiri → verifikasi ulang tatap muka (S2).
  if by_self and ((new.can_dementia and not old.can_dementia) or (new.can_mobility and not old.can_mobility)
                  or new.photo_path is distinct from old.photo_path) then
    new.id_checked_by := null;
    new.oriented_by := null;
  end if;

  if new.id_checked_by is distinct from old.id_checked_by or tg_op = 'INSERT' then
    new.id_checked_at := case when new.id_checked_by is null then null else coalesce(new.id_checked_at, now()) end;
  end if;
  if new.oriented_by is distinct from old.oriented_by or tg_op = 'INSERT' then
    new.oriented_at := case when new.oriented_by is null then null else coalesce(new.oriented_at, now()) end;
  end if;
  new.status := case when new.id_checked_by is not null and new.oriented_by is not null then 'aktif' else 'terdaftar' end;

  if tg_op = 'UPDATE' then
    if old.status = 'aktif' and new.status = 'terdaftar' and not by_self then
      update public.elders set volunteer_id = null, pairing_state = 'perlu_yayasan'
        where volunteer_id = new.id and pairing_state = 'berpasangan';
      update public.elders set pairing_state = 'mencari'
        where id in (select elder_id from public.proposals where volunteer_id = new.id and state = 'pending');
      delete from public.proposals where volunteer_id = new.id and state = 'pending';
    end if;
    if (old.can_dementia and not new.can_dementia) or (old.can_mobility and not new.can_mobility) then
      update public.elders set volunteer_id = null, pairing_state = 'perlu_yayasan'
        where volunteer_id = new.id and pairing_state = 'berpasangan'
          and ((has_dementia and not new.can_dementia) or (has_mobility_issue and not new.can_mobility));
    end if;
  end if;
  return new;
end;
$$;

-- S5: anggota keluarga harus menerima undangan dulu; yang belum menerima tidak punya akses apa pun.
alter table public.family_members add column accepted_at timestamptz;
update public.family_members set accepted_at = now();

create or replace function public.is_family(e uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.elders where id = e and family_id = auth.uid())
      or exists (select 1 from public.family_members
                 where elder_id = e and profile_id = auth.uid() and accepted_at is not null)
$$;

create or replace function public.add_family_member(p_elder_id uuid, p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid;
begin
  if not exists (select 1 from public.elders where id = p_elder_id and family_id = auth.uid()) then
    raise exception 'Hanya keluarga yang mendaftarkan lansia ini' using errcode = '42501';
  end if;
  select u.id into target from auth.users u join public.profiles p on p.id = u.id
    where lower(u.email) = lower(trim(p_email)) and p.role = 'keluarga';
  if target = auth.uid() then
    raise exception 'Itu akun Anda sendiri';
  end if;
  -- Jawaban sama apa pun hasilnya, supaya tidak bisa dipakai menebak email siapa yang terdaftar.
  if target is not null then
    insert into public.family_members (elder_id, profile_id) values (p_elder_id, target) on conflict do nothing;
  end if;
  return 'Undangan dikirim bila email itu milik akun Keluarga TemanSenja.';
end;
$$;

-- Undangan untuk pengguna yang login: nama lansia + nama pendaftar.
create function public.my_family_invites()
returns table (elder_id uuid, elder_name text, inviter_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select m.elder_id, e.full_name, p.full_name
  from public.family_members m join public.elders e on e.id = m.elder_id join public.profiles p on p.id = e.family_id
  where m.profile_id = auth.uid() and m.accepted_at is null
$$;

create function public.accept_family_invite(p_elder_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.family_members set accepted_at = now()
  where elder_id = p_elder_id and profile_id = auth.uid() and accepted_at is null
$$;

drop function public.family_member_list(uuid);
create function public.family_member_list(p_elder_id uuid)
returns table (profile_id uuid, full_name text, is_owner boolean, accepted boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select e.family_id, p.full_name, true, true from public.elders e join public.profiles p on p.id = e.family_id
    where e.id = p_elder_id and public.is_family(p_elder_id)
  union all
  select m.profile_id, p.full_name, false, m.accepted_at is not null
    from public.family_members m join public.profiles p on p.id = m.profile_id
    where m.elder_id = p_elder_id and public.is_family(p_elder_id)
$$;

-- P2a: token push untuk beberapa perangkat per akun. Satu token = satu perangkat; pindah akun → pindah pemilik.
create table public.push_tokens (
  token text primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  updated_at timestamptz not null default now()
);
alter table public.push_tokens enable row level security; -- tanpa policy: hanya lewat RPC / server
insert into public.push_tokens (token, profile_id) select fcm_token, id from public.profiles where fcm_token is not null
  on conflict do nothing;

create function public.register_push_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.push_tokens (token, profile_id) values (p_token, auth.uid())
  on conflict (token) do update set profile_id = auth.uid(), updated_at = now()
$$;

create function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.push_tokens where token = p_token and profile_id = auth.uid()
$$;

-- P2b: status "Perlu perhatian"/"Segera dikabari" bisa ditandai sudah ditangani (keluarga atau yayasannya).
-- Tanda ini hilang otomatis saat status berubah lagi (Edge Function visit).
alter table public.elders
  add column status_ack_at timestamptz,
  add column status_ack_by text check (length(status_ack_by) <= 100),
  add column status_ack_note text check (length(status_ack_note) <= 300);

create function public.acknowledge_status(p_elder_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me record;
begin
  select role, full_name, foundation_id into me from public.profiles where id = auth.uid();
  if not (public.is_family(p_elder_id)
          or exists (select 1 from public.elders where id = p_elder_id and foundation_id = me.foundation_id
                     and me.role = 'yayasan')) then
    raise exception 'Tidak berhak' using errcode = '42501';
  end if;
  update public.elders set status_ack_at = now(), status_ack_by = me.full_name, status_ack_note = left(trim(p_note), 300)
    where id = p_elder_id and status <> 'stabil';
end;
$$;

revoke execute on function public.family_member_list, public.my_family_invites, public.accept_family_invite, public.register_push_token,
  public.unregister_push_token, public.acknowledge_status from public, anon;
grant execute on function public.family_member_list, public.my_family_invites, public.accept_family_invite, public.register_push_token,
  public.unregister_push_token, public.acknowledge_status to authenticated;

-- Dashboard: aturan S1 + tanda sudah ditangani.
create or replace function public.foundation_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  f uuid := public.my_admin_foundation();
begin
  if f is null then
    raise exception 'Khusus pengurus yayasan' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'elders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'full_name', e.full_name, 'status', e.status, 'status_reason', e.status_reason,
        'pairing_state', e.pairing_state, 'has_chronic', coalesce(h.has_chronic, false),
        'status_ack_at', e.status_ack_at, 'status_ack_by', e.status_ack_by,
        'last_visit_at', (select max(v.visited_at) from public.visits v where v.elder_id = e.id and v.confirmed_at is not null)
      ) order by e.full_name)
      from public.elders e left join public.health_profiles h on h.elder_id = e.id
      where e.foundation_id = f
         or (e.foundation_id is null and e.pairing_state in ('tanpa_pendamping', 'perlu_yayasan'))
    ), '[]'::jsonb),
    'counts', jsonb_build_object(
      'didampingi', (select count(*) from public.elders where foundation_id = f and pairing_state = 'berpasangan'),
      'tanpa_pendamping', (select count(*) from public.elders where pairing_state = 'tanpa_pendamping'
                           and (foundation_id = f or foundation_id is null)),
      'perlu_yayasan', (select count(*) from public.elders where pairing_state = 'perlu_yayasan'
                        and (foundation_id = f or foundation_id is null))
    ),
    'volunteers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'full_name', p.full_name, 'status', v.status, 'max_load', v.max_load,
        'load', (select count(*) from public.elders x where x.volunteer_id = v.id and x.pairing_state = 'berpasangan')
      ) order by p.full_name)
      from public.volunteers v join public.profiles p on p.id = v.id where v.foundation_id = f
    ), '[]'::jsonb)
  );
end;
$$;
