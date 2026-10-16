-- Langganan + verifikasi keluarga/lansia (keputusan pengguna 15 Okt, serangan K1/K5):
-- relawan diverifikasi tatap muka oleh yayasan; keluarga & lansia diverifikasi ONLINE dari dokumen oleh pengurus
-- yayasan relawan yang diterima. Alur: bayar (simulasi) → unggah dokumen → relawan diusulkan → keluarga menerima →
-- yayasan memeriksa dokumen → kontak lengkap relawan terbuka → kunjungan pertama: relawan memastikan lansia ada & setuju.

alter table public.elders
  add column paid_until timestamptz,
  add column paid_by uuid references public.profiles (id) on delete set null,
  add column verify_state text not null default 'belum'
    check (verify_state in ('belum', 'menunggu', 'terverifikasi', 'ditolak')),
  add column verify_note text check (length(verify_note) <= 300),
  add column verified_by uuid references public.profiles (id) on delete set null,
  add column verified_at timestamptz,
  add column first_visit_at timestamptz; -- relawan memastikan lansia ada & setuju (kunjungan pertama)
-- Data seed (demo) dianggap sudah membayar dan terverifikasi.
update public.elders set paid_until = now() + interval '365 days', verify_state = 'terverifikasi',
  verified_at = now(), first_visit_at = now();

alter table public.volunteers add column vehicle text check (length(vehicle) <= 100); -- mis. "Honda Beat merah · AB 1234 XY"
grant update (vehicle) on public.volunteers to authenticated;
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
          - 'can_dementia' - 'can_mobility' - 'photo_path' - 'vehicle')
         is distinct from
         (to_jsonb(old) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path' - 'vehicle') then
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

-- Maks. 3 lansia per akun keluarga (akun palsu tidak bisa membuat banyak lansia umpan).
create function public.elders_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and (select count(*) from public.elders where family_id = new.family_id) >= 3 then
    raise exception 'Satu akun keluarga maksimal mendaftarkan 3 lansia.' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger elders_limit before insert on public.elders for each row execute function public.elders_limit();

-- ponytail: pembayaran disimulasikan untuk demo (seperti OTP relawan). Produksi: payment gateway berizin
-- (Midtrans/Xendit) memanggil webhook di Edge Function yang mengisi paid_until; RPC ini dihapus.
create function public.simulate_payment(p_elder_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  until timestamptz;
begin
  update public.elders set paid_until = greatest(coalesce(paid_until, now()), now()) + interval '30 days',
      paid_by = auth.uid()
    where id = p_elder_id and family_id = auth.uid()
    returning paid_until into until;
  if until is null then
    raise exception 'Hanya keluarga yang mendaftarkan lansia ini' using errcode = '42501';
  end if;
  return until;
end;
$$;

-- Dokumen verifikasi di bucket privat `elder-docs/<elder_id>/<jenis>.jpg`.
insert into storage.buckets (id, name, public) values ('elder-docs', 'elder-docs', false) on conflict do nothing;
create policy "keluarga: unggah dokumen lansianya" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'elder-docs' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1] and e.family_id = auth.uid()));
create policy "keluarga: ganti dokumen lansianya" on storage.objects
  for update to authenticated
  using (bucket_id = 'elder-docs' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1] and e.family_id = auth.uid()));
create policy "keluarga & yayasan: baca dokumen" on storage.objects
  for select to authenticated
  using (bucket_id = 'elder-docs' and exists (
    select 1 from public.elders e where e.id::text = (storage.foldername(name))[1]
      and (e.family_id = auth.uid()
           or (e.foundation_id = public.my_admin_foundation() and e.verify_state = 'menunggu'))));

create function public.submit_verification(p_elder_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.elders where id = p_elder_id and family_id = auth.uid()) then
    raise exception 'Hanya keluarga yang mendaftarkan lansia ini' using errcode = '42501';
  end if;
  if (select count(*) from storage.objects where bucket_id = 'elder-docs'
        and name in (p_elder_id || '/ktp_keluarga.jpg', p_elder_id || '/selfie_ktp.jpg',
                     p_elder_id || '/ktp_lansia.jpg', p_elder_id || '/kk.jpg')) < 4 then
    raise exception 'Unggah keempat dokumen dulu: KTP Anda, swafoto memegang KTP, KTP lansia, dan Kartu Keluarga.';
  end if;
  update public.elders set verify_state = 'menunggu', verify_note = null
    where id = p_elder_id and verify_state in ('belum', 'ditolak');
end;
$$;

-- Kunjungan pertama: relawan memastikan lansia benar ada dan setuju didampingi (persetujuan langsung).
create function public.confirm_first_visit(p_elder_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.elders set first_visit_at = now()
  where id = p_elder_id and volunteer_id = auth.uid() and verify_state = 'terverifikasi' and first_visit_at is null
$$;

-- Kontak lengkap relawan untuk keluarga, seperti Gojek setelah pesanan diterima: hanya bila berpasangan dan
-- dokumen keluarga sudah terverifikasi.
create function public.my_volunteer_contact(p_elder_id uuid)
returns table (full_name text, phone text, vehicle text, photo_path text, foundation_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.full_name, p.phone, v.vehicle, v.photo_path, f.name
  from public.elders e join public.volunteers v on v.id = e.volunteer_id
    join public.profiles p on p.id = v.id join public.foundations f on f.id = v.foundation_id
  where e.id = p_elder_id and public.is_family(e.id)
    and e.pairing_state = 'berpasangan' and e.verify_state = 'terverifikasi'
$$;

-- Kunjungan baru hanya setelah keluarga terverifikasi dan kunjungan pertama dikonfirmasi relawan.
create function public.visits_need_verified()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not exists (
    select 1 from public.elders where id = new.elder_id and verify_state = 'terverifikasi' and first_visit_at is not null
  ) then
    raise exception 'Keluarga belum terverifikasi atau kunjungan pertama belum dikonfirmasi.' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger visits_need_verified before insert on public.visits
  for each row execute function public.visits_need_verified();

-- Kartu usulan (sebelum diterima): jarak dibulatkan ke km supaya rumah relawan tidak bisa ditriangulasi dari
-- beberapa lansia palsu. Nomor HP & kendaraan tidak ikut (lihat my_volunteer_contact).
create or replace function public.get_proposal_card(proposal_id uuid)
returns table (
  id uuid, attempt int, state text, rejects_left int, volunteer_name text, foundation_name text, photo_path text,
  can_dementia boolean, can_mobility boolean, available_days text[], languages text[], distance_km numeric,
  reason_text text, verification text
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
      case when v.oriented_by is not null then 'Sudah mengikuti orientasi' end)
  from public.proposals p
  join public.elders e on e.id = p.elder_id
  join public.volunteers v on v.id = p.volunteer_id
  join public.profiles pr on pr.id = v.id
  join public.foundations f on f.id = v.foundation_id
  where p.id = get_proposal_card.proposal_id
    and e.family_id = auth.uid()
$$;

-- Foto relawan: hanya selama usulan masih menunggu jawaban atau sudah diterima (bukan setelah ditolak).
drop policy "keluarga: baca foto relawan yang diusulkan" on storage.objects;
create policy "keluarga: baca foto relawan yang diusulkan" on storage.objects
  for select to authenticated
  using (bucket_id = 'volunteer-photos' and exists (
    select 1 from public.proposals p
    join public.elders e on e.id = p.elder_id
    where p.volunteer_id::text = (storage.foldername(name))[1] and p.state in ('pending', 'accepted', 'manual')
      and public.is_family(e.id)));

revoke execute on function public.simulate_payment, public.submit_verification, public.confirm_first_visit,
  public.my_volunteer_contact from public, anon;
grant execute on function public.simulate_payment, public.submit_verification, public.confirm_first_visit,
  public.my_volunteer_contact to authenticated;

-- Dashboard: status verifikasi keluarga (antrean pemeriksaan dokumen).
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
