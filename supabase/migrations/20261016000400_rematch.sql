-- Pencocokan ulang otomatis (keputusan pengguna 16 Okt): saat relawan lepas (berhenti, mengundurkan diri,
-- dinonaktifkan, dilepas yayasan, akun dihapus), lansia mendapat putaran baru 3 usulan dari semua yayasan.
-- Kolom ini menandai awal putaran; usulan sebelumnya tidak dihitung lagi (lihat _shared/propose.ts).
alter table public.elders add column match_round_at timestamptz;
