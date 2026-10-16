-- Alur relawan baru (keputusan pengguna 15 Okt):
-- (1) Relawan memilih yayasan dari daftar (tautan undangan tetap bisa memilihkan) dan apply.
-- (2) Verifikasi tatap muka: pengurus mengisi butir pemeriksaan lalu menampilkan KODE SEKALI PAKAI (6 digit,
--     berlaku 2 menit, seperti authenticator); relawan memasukkannya di aplikasinya → Aktif. Membuktikan keduanya
--     benar-benar bertemu. Centang tidak bisa lagi diisi langsung oleh yayasan.
-- (3) Relawan berhenti dari seorang lansia lewat PERMINTAAN ke yayasan; otomatis diterima setelah 7 hari.
-- (4) Yayasan bisa menonaktifkan relawan aktif dengan alasan (Edge Function pairing aksi deactivate).

create extension if not exists pgcrypto with schema extensions;

-- (1) Daftar yayasan & apply ----------------------------------------------------------------------------
create function public.list_foundations(p_query text default '')
returns table (id uuid, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id, f.name from public.foundations f
  where f.verified and f.name ilike '%' || coalesce(trim(p_query), '') || '%'
  order by f.name limit 30
$$;

create function public.foundation_by_code(p_code text)
returns table (id uuid, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select f.id, f.name from public.foundations f where f.verified and f.invite_code = upper(trim(p_code))
$$;

create function public.apply_foundation(
  p_foundation_id uuid, p_full_name text, p_area_label text, p_lat float8, p_lng float8,
  p_available_days text[], p_languages text[], p_can_dementia boolean, p_can_mobility boolean, p_photo_path text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  code text;
begin
  select invite_code into code from public.foundations where id = p_foundation_id and verified;
  if code is null then
    raise exception 'Yayasan tidak ditemukan atau belum terverifikasi';
  end if;
  return public.join_foundation(code, p_full_name, p_area_label, p_lat, p_lng, p_available_days, p_languages,
    p_can_dementia, p_can_mobility, p_photo_path);
end;
$$;

-- (2) Kode verifikasi tatap muka -------------------------------------------------------------------------
alter table public.volunteers add column status_note text check (length(status_note) <= 300);
grant update (status_note) on public.volunteers to authenticated; -- dipakai yayasan saat menonaktifkan

create table public.volunteer_codes (
  volunteer_id uuid primary key references public.volunteers (id) on delete cascade,
  code_hash text not null,
  issued_by uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null,
  attempts int not null default 0
);
alter table public.volunteer_codes enable row level security; -- tanpa policy: hanya lewat RPC

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
    if by_self and coalesce(current_setting('app.verify_code', true), '') <> 'ok' then
      if (to_jsonb(new) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path' - 'vehicle')
         is distinct from
         (to_jsonb(old) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path' - 'vehicle') then
        raise exception 'Relawan tidak bisa memverifikasi dirinya sendiri';
      end if;
    elsif (to_jsonb(new) - check_cols - 'status_note') is distinct from (to_jsonb(old) - check_cols - 'status_note') then
      raise exception 'Yayasan hanya boleh mengubah centang verifikasi';
    elsif ((new.id_checked_by is not null and old.id_checked_by is null)
           or (new.oriented_by is not null and old.oriented_by is null))
          and coalesce(current_setting('app.verify_code', true), '') <> 'ok' then
      -- Verifikasi hanya lewat kode tatap muka (redeem_verification_code); mencabut centang tetap boleh.
      raise exception 'Verifikasi relawan dilakukan lewat kode tatap muka';
    end if;
  end if;

  -- Keahlian baru atau foto wajah baru yang diisi sendiri → verifikasi ulang tatap muka (S2).
  if by_self and coalesce(current_setting('app.verify_code', true), '') <> 'ok' and ((new.can_dementia and not old.can_dementia) or (new.can_mobility and not old.can_mobility)
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

-- Pengurus memanggil ini SETELAH mengisi semua butir pemeriksaan di aplikasi. Kode hanya dikembalikan sekali.
create function public.issue_verification_code(p_volunteer_id uuid)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  c text := lpad((floor(random() * 1000000))::int::text, 6, '0');
  exp timestamptz := now() + interval '2 minutes';
begin
  if not exists (select 1 from public.volunteers v where v.id = p_volunteer_id
                 and v.foundation_id = public.my_admin_foundation() and v.status = 'terdaftar') then
    raise exception 'Relawan tidak ditemukan atau sudah aktif' using errcode = '42501';
  end if;
  insert into public.volunteer_codes (volunteer_id, code_hash, issued_by, expires_at)
    values (p_volunteer_id, extensions.crypt(c, extensions.gen_salt('bf')), auth.uid(), exp)
    on conflict (volunteer_id) do update
      set code_hash = excluded.code_hash, issued_by = excluded.issued_by, expires_at = excluded.expires_at, attempts = 0;
  return query select c, exp;
end;
$$;

-- Relawan memasukkan kode dari layar pengurus. Maks. 5 percobaan per kode (6 digit, 2 menit → tebakan sia-sia).
create function public.redeem_verification_code(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  vc public.volunteer_codes;
begin
  select * into vc from public.volunteer_codes where volunteer_id = auth.uid();
  if vc.volunteer_id is null or vc.expires_at < now() or vc.attempts >= 5 then
    raise exception 'Kode tidak berlaku. Minta pengurus menampilkan kode baru.';
  end if;
  if vc.code_hash <> extensions.crypt(trim(p_code), vc.code_hash) then
    update public.volunteer_codes set attempts = attempts + 1 where volunteer_id = vc.volunteer_id;
    return 'salah';
  end if;
  perform set_config('app.verify_code', 'ok', true);
  update public.volunteers set id_checked_by = vc.issued_by, oriented_by = vc.issued_by, status_note = null
    where id = vc.volunteer_id;
  perform set_config('app.verify_code', '', true);
  delete from public.volunteer_codes where volunteer_id = vc.volunteer_id;
  return 'aktif';
end;
$$;

-- (3) Permintaan berhenti mendampingi --------------------------------------------------------------------
create table public.stop_requests (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid not null references public.volunteers (id) on delete cascade,
  reason text not null check (length(trim(reason)) between 3 and 300),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by text check (length(decided_by) <= 100)
);
create unique index stop_requests_pending on public.stop_requests (elder_id) where decided_at is null;
alter table public.stop_requests enable row level security;
create policy "relawan: baca permintaannya" on public.stop_requests
  for select to authenticated using (volunteer_id = auth.uid());
create policy "yayasan: baca permintaan relawannya" on public.stop_requests
  for select to authenticated using (exists (
    select 1 from public.volunteers v where v.id = volunteer_id and v.foundation_id = public.my_admin_foundation()));

-- Dipakai Edge Function pairing (yayasan menerima) dan reminders (otomatis 7 hari). Service role saja.
create function public.approve_stop_request(p_id uuid, p_by text)
returns table (elder_id uuid, volunteer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.stop_requests;
begin
  update public.stop_requests set decided_at = now(), decided_by = left(p_by, 100)
    where id = p_id and decided_at is null returning * into r;
  if r.id is null then
    return;
  end if;
  update public.elders set volunteer_id = null, pairing_state = 'perlu_yayasan'
    where id = r.elder_id and volunteer_id = r.volunteer_id and pairing_state = 'berpasangan';
  return query select r.elder_id, r.volunteer_id;
end;
$$;

-- Dashboard: permintaan berhenti yang menunggu.
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
        'verify_state', e.verify_state, 'first_visit_at', e.first_visit_at,
        'stop_request', (select jsonb_build_object('id', s.id, 'reason', s.reason, 'created_at', s.created_at)
                         from public.stop_requests s where s.elder_id = e.id and s.decided_at is null),
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
        'id', v.id, 'full_name', p.full_name, 'status', v.status, 'max_load', v.max_load, 'status_note', v.status_note,
        'load', (select count(*) from public.elders x where x.volunteer_id = v.id and x.pairing_state = 'berpasangan')
      ) order by p.full_name)
      from public.volunteers v join public.profiles p on p.id = v.id where v.foundation_id = f
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.list_foundations, public.foundation_by_code, public.apply_foundation,
  public.issue_verification_code, public.redeem_verification_code from public, anon;
grant execute on function public.list_foundations, public.foundation_by_code, public.apply_foundation,
  public.issue_verification_code, public.redeem_verification_code to authenticated;
revoke execute on function public.approve_stop_request from public, anon, authenticated;
