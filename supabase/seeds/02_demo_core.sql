-- T-007: data demo dasar. Idempoten. Butuh 01_accounts.sql.
-- Jalankan: supabase db query --linked -f supabase/seeds/02_demo_core.sql
-- Koordinat sungguhan di Yogyakarta. Keahlian dibuat berbeda supaya pemasangan punya pilihan.

-- 4 relawan aktif (dua centang oleh pengurus) dan 1 relawan terdaftar.
insert into public.volunteers (id, foundation_id, area_label, lat, lng, available_days, languages,
  can_dementia, can_mobility, id_checked_by, oriented_by)
values
  ('c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'Kotabaru, Yogyakarta',
   -7.7850, 110.3735, '{selasa,jumat}', '{indonesia,jawa}', true, true,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'Demangan, Gondokusuman',
   -7.7826, 110.3905, '{senin,kamis}', '{indonesia}', false, true,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000001', 'Kotagede',
   -7.8297, 110.4003, '{rabu,sabtu}', '{indonesia,jawa}', true, false,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000001', 'Jetis',
   -7.7740, 110.3640, '{sabtu,minggu}', '{indonesia}', false, false,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000005', 'f0000000-0000-0000-0000-000000000001', 'Umbulharjo',
   -7.8105, 110.3840, '{jumat}', '{indonesia,jawa}', true, true, null, null)
on conflict (id) do nothing;

-- Ibu Sri (keluarga 1) sudah berpasangan dengan relawan 1.
insert into public.elders (id, family_id, full_name, address, lat, lng, needs, has_dementia,
  has_mobility_issue, volunteer_id, foundation_id, pairing_state)
values
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Ibu Sri Wahyuni',
   'Jl. Cik Di Tiro No. 12, Terban, Gondokusuman, Yogyakarta', -7.7790, 110.3760,
   'Teman ngobrol dan pengingat minum obat; tinggal sendiri sejak suami meninggal',
   false, false, 'c0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'berpasangan'),
  ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Bapak Harjo Sumarto',
   'Jl. Tamansiswa No. 80, Wirogunan, Mergangsan, Yogyakarta', -7.8090, 110.3770,
   'Sering lupa, butuh pendamping yang sabar', true, false, null, null, 'mencari')
on conflict (id) do nothing;

insert into public.health_profiles (elder_id, conditions, allergies, medications, diet_restrictions,
  mobility_aids, doctor_hospital, emergency_instructions, has_chronic)
values
  ('e0000000-0000-0000-0000-000000000001', 'Hipertensi, diabetes tipe 2', 'Tidak ada alergi obat',
   '[{"name": "Amlodipin 5 mg", "times": ["07.00"]}, {"name": "Metformin 500 mg", "times": ["07.00", "19.00"]}]',
   'Rendah garam dan gula', 'Tongkat untuk jalan jauh', 'Puskesmas Gondokusuman I',
   'Hubungi Rina (anak) 081200000011. Gula darah rendah: beri teh manis.', true)
on conflict (elder_id) do nothing;
