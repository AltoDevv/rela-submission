-- Keputusan pengguna 15 Okt: dokumen verifikasi tanpa swafoto memegang KTP (cukup KTP keluarga, KTP lansia, KK
-- atau surat RT/RW), dan data kendaraan/plat nomor relawan tidak dikumpulkan.
create or replace function public.submit_verification(p_elder_id uuid)
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
        and name in (p_elder_id || '/ktp_keluarga.jpg', p_elder_id || '/ktp_lansia.jpg', p_elder_id || '/kk.jpg')) < 3 then
    raise exception 'Unggah ketiga dokumen dulu: KTP Anda, KTP lansia, dan Kartu Keluarga (atau surat RT/RW).';
  end if;
  update public.elders set verify_state = 'menunggu', verify_note = null
    where id = p_elder_id and verify_state in ('belum', 'ditolak');
end;
$$;

drop function public.my_volunteer_contact(uuid);
create function public.my_volunteer_contact(p_elder_id uuid)
returns table (full_name text, phone text, photo_path text, foundation_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.full_name, p.phone, v.photo_path, f.name
  from public.elders e join public.volunteers v on v.id = e.volunteer_id
    join public.profiles p on p.id = v.id join public.foundations f on f.id = v.foundation_id
  where e.id = p_elder_id and public.is_family(e.id)
    and e.pairing_state = 'berpasangan' and e.verify_state = 'terverifikasi'
$$;
revoke execute on function public.my_volunteer_contact from public, anon;
grant execute on function public.my_volunteer_contact to authenticated;

-- volunteers_checks masih mengurangi kunci 'vehicle' dari jsonb; tanpa kolom itu tidak berpengaruh.
alter table public.volunteers drop column vehicle;
