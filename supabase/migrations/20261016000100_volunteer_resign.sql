-- Relawan mengajukan pengunduran diri dari yayasan (Figma tab Profil). Ditulis Edge Function pairing (aksi resign),
-- bukan klien: kolom ini tidak di-grant update ke authenticated. Selama terisi, relawan tidak diusulkan ke lansia
-- baru; yayasan menuntaskannya dengan "Nonaktifkan" (aksi deactivate mengosongkannya lagi).
alter table public.volunteers
  add column resign_reason text check (length(resign_reason) <= 300),
  add column resign_requested_at timestamptz;

-- Kontak pendaftar (keluarga) untuk relawan pasangan: nama dan HP saja, ditampilkan di tab Lansia supaya relawan
-- bisa menelepon keluarga (mis. saat darurat).
create function public.my_elders_family_contacts()
returns table (elder_id uuid, full_name text, phone text)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, p.full_name, p.phone
  from public.elders e join public.profiles p on p.id = e.family_id
  where e.volunteer_id = auth.uid() and e.pairing_state = 'berpasangan';
$$;
revoke execute on function public.my_elders_family_contacts from public, anon;
grant execute on function public.my_elders_family_contacts to authenticated;

-- Nama yayasan relawan yang login (chip "Terverifikasi · Aktif"). Relawan tidak membaca tabel foundations
-- langsung karena tabel itu berisi kode undangan.
create function public.my_foundation_name()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select f.name from public.volunteers v join public.foundations f on f.id = v.foundation_id where v.id = auth.uid();
$$;
revoke execute on function public.my_foundation_name from public, anon;
grant execute on function public.my_foundation_name to authenticated;
