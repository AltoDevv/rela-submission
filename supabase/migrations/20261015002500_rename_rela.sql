-- Nama aplikasi menjadi ReLa (relawan lansia). Hanya teks yang terlihat pengguna; kode paket & skema tautan tetap.
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
  return 'Undangan dikirim bila email itu milik akun Keluarga ReLa.';
end;
$$;
