-- T-016 (F1a): relawan bergabung ke yayasan lewat kode undangan.
-- security definer karena relawan tidak punya policy INSERT ke volunteers dan tidak boleh mengubah
-- profiles.foundation_id sendiri. Semua syarat dicek di sini, dalam satu transaksi.
create function public.join_foundation(
  p_code text,
  p_full_name text,
  p_area_label text,
  p_lat float8,
  p_lng float8,
  p_available_days text[],
  p_languages text[],
  p_can_dementia boolean,
  p_can_mobility boolean,
  p_photo_path text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  f public.foundations;
begin
  if uid is null then
    raise exception 'Belum login';
  end if;
  if (select role from public.profiles where id = uid) is distinct from 'relawan' then
    raise exception 'Hanya akun relawan yang bisa bergabung ke yayasan';
  end if;

  select * into f from public.foundations where invite_code = upper(trim(p_code));
  if not found then
    raise exception 'Kode undangan tidak dikenal';
  end if;
  if not f.verified then
    raise exception 'Yayasan belum terverifikasi';
  end if;
  if exists (select 1 from public.volunteers where id = uid) then
    raise exception 'Akun ini sudah bergabung ke yayasan';
  end if;

  if coalesce(length(trim(p_full_name)), 0) = 0 or coalesce(length(trim(p_area_label)), 0) = 0 then
    raise exception 'Nama dan area wajib diisi';
  end if;
  if coalesce(cardinality(p_available_days), 0) = 0
     or not p_available_days <@ array['senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'] then
    raise exception 'Hari tersedia tidak valid';
  end if;
  if coalesce(cardinality(p_languages), 0) = 0 then
    raise exception 'Pilih minimal satu bahasa';
  end if;
  -- Foto harus sudah diunggah ke folder milik relawan sendiri (policy storage T-007).
  if p_photo_path is null or p_photo_path not like uid::text || '/%' then
    raise exception 'Foto wajah wajib diambil dari kamera';
  end if;

  insert into public.volunteers (id, foundation_id, area_label, lat, lng, available_days, languages,
    can_dementia, can_mobility, photo_path)
  values (uid, f.id, trim(p_area_label), p_lat, p_lng, p_available_days, p_languages,
    p_can_dementia, p_can_mobility, p_photo_path);

  -- OTP disimulasikan di aplikasi (PRD P2); sampai di sini berarti kode sudah cocok.
  update public.profiles
  set foundation_id = f.id, full_name = trim(p_full_name), phone_verified = true
  where id = uid;

  return f.id;
end;
$$;

revoke execute on function public.join_foundation from public, anon;
grant execute on function public.join_foundation to authenticated;
