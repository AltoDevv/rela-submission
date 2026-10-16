-- Evaluasi 15 Okt (E1–E8).

-- E1: koreksi relawan yang menurunkan penilaian AI (mencabut tanda bahaya / level lebih ringan) dicatat beserta
-- alasannya. Diisi Edge Function visit (service role), dibaca keluarga & yayasan lewat status_reason.
alter table public.visits add column overrides jsonb;

-- E2: lansia yang belum punya yayasan tidak lagi bisa dibaca langsung oleh semua yayasan (alamat, koordinat,
-- kebutuhan). Mereka tetap muncul di foundation_dashboard (nama + ringkasan), dan detail untuk pasang manual
-- lewat manual_pair_options (jarak dihitung server, tanpa alamat/koordinat).
drop policy "yayasan: baca yayasannya dan yang butuh bantuan" on public.elders;
create policy "yayasan: baca lansia yayasannya" on public.elders
  for select to authenticated
  using (public.my_admin_foundation() is not null and foundation_id = public.my_admin_foundation());

create function public.manual_pair_options(p_elder_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  f uuid := public.my_admin_foundation();
  e public.elders;
begin
  if f is null then
    raise exception 'Khusus pengurus yayasan' using errcode = '42501';
  end if;
  select * into e from public.elders where id = p_elder_id
    and (foundation_id = f or (foundation_id is null and pairing_state in ('tanpa_pendamping', 'perlu_yayasan')));
  if e.id is null then
    raise exception 'Lansia tidak ditemukan' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'elder', jsonb_build_object(
      'id', e.id, 'family_id', e.family_id, 'full_name', e.full_name, 'foundation_id', e.foundation_id,
      'address', case when e.foundation_id = f then e.address else 'Alamat terlihat setelah dipasangkan' end,
      'has_dementia', e.has_dementia, 'has_mobility_issue', e.has_mobility_issue,
      'pairing_state', e.pairing_state, 'status', e.status),
    'has_chronic', coalesce((select has_chronic from public.health_profiles where elder_id = e.id), false),
    'volunteers', coalesce((
      select jsonb_agg(to_jsonb(v) - 'lat' - 'lng' || jsonb_build_object(
        'full_name', p.full_name,
        'load', (select count(*) from public.elders x where x.volunteer_id = v.id and x.pairing_state = 'berpasangan'),
        -- haversine, sama dengan _shared/matching.ts
        'km', case when e.lat is null or v.lat is null then null else
          2 * 6371.0088 * asin(sqrt(power(sin(radians(v.lat - e.lat) / 2), 2)
            + cos(radians(e.lat)) * cos(radians(v.lat)) * power(sin(radians(v.lng - e.lng) / 2), 2))) end))
      from public.volunteers v join public.profiles p on p.id = v.id
      where v.foundation_id = f and v.status = 'aktif'
    ), '[]'::jsonb)
  );
end;
$$;

-- E3: menambah pengurus = undangan; akun baru berpindah peran hanya setelah pemiliknya menerima.
create table public.foundation_admin_invites (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  foundation_id uuid not null references public.foundations (id) on delete cascade,
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.foundation_admin_invites enable row level security; -- tanpa policy: hanya lewat RPC

create or replace function public.add_foundation_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  f uuid := public.my_admin_foundation();
  target uuid;
begin
  if f is null then
    raise exception 'Khusus pengurus yayasan' using errcode = '42501';
  end if;
  select u.id into target from auth.users u join public.profiles p on p.id = u.id
    where lower(u.email) = lower(trim(p_email)) and p.role = 'keluarga'
      and not exists (select 1 from public.elders where family_id = u.id)
      and not exists (select 1 from public.family_members where profile_id = u.id);
  if target is not null then
    insert into public.foundation_admin_invites (profile_id, foundation_id, invited_by) values (target, f, auth.uid())
      on conflict (profile_id) do update set foundation_id = f, invited_by = auth.uid(), created_at = now();
  end if;
  -- Jawaban sama apa pun hasilnya (tidak bisa dipakai menebak email).
  return 'Undangan dikirim bila email itu milik akun Keluarga baru yang belum memantau lansia. '
      || 'Minta ia membuka aplikasi dan menerima undangan.';
end;
$$;

create function public.my_admin_invite()
returns table (foundation_id uuid, foundation_name text, inviter_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select i.foundation_id, f.name, p.full_name
  from public.foundation_admin_invites i join public.foundations f on f.id = i.foundation_id
    left join public.profiles p on p.id = i.invited_by
  where i.profile_id = auth.uid()
$$;

create function public.answer_admin_invite(p_accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  f uuid;
begin
  delete from public.foundation_admin_invites where profile_id = auth.uid() returning foundation_id into f;
  if f is null or not p_accept then
    return;
  end if;
  -- Syarat dicek ulang saat menerima: sejak diundang ia mungkin sudah memantau lansia.
  if exists (select 1 from public.elders where family_id = auth.uid())
     or exists (select 1 from public.family_members where profile_id = auth.uid()) then
    raise exception 'Akun ini sudah memantau lansia, jadi tidak bisa menjadi pengurus yayasan.';
  end if;
  update public.profiles set role = 'yayasan', foundation_id = f where id = auth.uid() and role = 'keluarga';
end;
$$;

-- E6: akun yang dibuat tanpa menyetujui syarat (mis. lewat API) diminta menyetujui saat masuk aplikasi.
create function public.accept_terms()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles set terms_accepted_at = now() where id = auth.uid() and terms_accepted_at is null
$$;

-- E7: satu kunjungan terkonfirmasi per lansia per hari (WIB); salah isi diperbaiki lewat "Koreksi kunjungan
-- terakhir". Cerita yang belum dikonfirmasi (mis. ekstraksi gagal) tidak menghalangi. Seed (auth.uid() null) bebas.
create function public.visits_one_per_day()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and exists (
    select 1 from public.visits where elder_id = new.elder_id and confirmed_at is not null
      and (visited_at at time zone 'Asia/Jakarta')::date = (new.visited_at at time zone 'Asia/Jakarta')::date
  ) then
    raise exception 'Kunjungan hari ini sudah dicatat. Bila ada yang salah, pakai "Koreksi kunjungan terakhir".'
      using errcode = '23505';
  end if;
  return new;
end;
$$;
create trigger visits_one_per_day before insert on public.visits for each row execute function public.visits_one_per_day();

-- E8: pengingat bila lansia berpasangan tidak dikunjungi lebih dari 7 hari (dihitung dari kunjungan terakhir,
-- atau sejak dipasangkan). Dipanggil Edge Function `reminders` (service role) setiap hari lewat pg_cron.
alter table public.elders add column last_reminder_at timestamptz;

create function public.due_visit_reminders()
returns table (id uuid, full_name text, family_id uuid, foundation_id uuid, volunteer_id uuid, days integer)
language sql
security definer
set search_path = ''
as $$
  with due as (
    select e.id, e.full_name, e.family_id, e.foundation_id, e.volunteer_id,
      coalesce((select max(v.visited_at) from public.visits v where v.elder_id = e.id and v.confirmed_at is not null),
               (select max(p.created_at) from public.proposals p
                  where p.elder_id = e.id and p.volunteer_id = e.volunteer_id and p.state in ('accepted', 'manual')),
               e.created_at) as since
    from public.elders e
    where e.pairing_state = 'berpasangan' and e.volunteer_id is not null
      and (e.last_reminder_at is null or e.last_reminder_at < now() - interval '20 hours')
  ),
  marked as (
    update public.elders x set last_reminder_at = now() from due
    where x.id = due.id and due.since < now() - interval '7 days'
    returning due.*
  )
  select id, full_name, family_id, foundation_id, volunteer_id, extract(day from now() - since)::integer from marked
$$;

revoke execute on function public.manual_pair_options, public.my_admin_invite, public.answer_admin_invite,
  public.accept_terms from public, anon;
grant execute on function public.manual_pair_options, public.my_admin_invite, public.answer_admin_invite,
  public.accept_terms to authenticated;
revoke execute on function public.due_visit_reminders from public, anon, authenticated;

-- Jadwal harian 08.00 WIB (01.00 UTC). Rahasia pemanggil disimpan di Vault (dibuat di luar git, lihat CLAUDE.md).
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.schedule('visit-reminders', '0 1 * * *', $$
  select net.http_post(
    url := 'https://zysrjsbykllpjemvbbuf.supabase.co/functions/v1/reminders',
    headers := jsonb_build_object('x-cron-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'reminders_cron_secret'))
  )
$$);
