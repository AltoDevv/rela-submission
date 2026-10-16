-- Usulan yang tidak dijawab 48 jam kedaluwarsa (PRD Non-goals → dikerjakan 15 Okt): relawan dilepas,
-- lansia kembali "mencari", dan tidak dihitung sebagai penolakan. Dipanggil Edge Function pairing tiap permintaan.
create function public.expire_stale_proposals()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  with stale as (
    delete from public.proposals where state = 'pending' and created_at < now() - interval '48 hours'
    returning elder_id
  )
  update public.elders set pairing_state = 'mencari'
    where id in (select elder_id from stale) and pairing_state = 'menunggu_keluarga';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function public.expire_stale_proposals() from public, anon, authenticated;

-- Pengurus menambah pengurus lain untuk yayasannya (sebelumnya hanya satu akun dari seed). Target harus akun
-- keluarga yang belum mendaftarkan lansia, supaya tidak ada akun yang memegang dua peran.
create function public.add_foundation_admin(p_email text)
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
  if target is null then
    raise exception 'Akun tidak memenuhi syarat: harus akun Keluarga baru yang belum memantau lansia.';
  end if;
  update public.profiles set role = 'yayasan', foundation_id = f where id = target;
  return 'Pengurus ditambahkan. Minta ia keluar lalu masuk lagi.';
end;
$$;
revoke execute on function public.add_foundation_admin(text) from public, anon;
grant execute on function public.add_foundation_admin(text) to authenticated;
