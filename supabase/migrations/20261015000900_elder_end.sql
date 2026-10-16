-- Pendampingan bisa diakhiri (lansia meninggal, pindah, tidak lagi membutuhkan). Riwayat tetap tersimpan.
alter table public.elders drop constraint elders_pairing_state_check;
alter table public.elders add constraint elders_pairing_state_check
  check (pairing_state in ('mencari', 'menunggu_keluarga', 'berpasangan', 'tanpa_pendamping', 'perlu_yayasan', 'selesai'));
alter table public.elders
  add column ended_reason text check (length(ended_reason) <= 300),
  add column ended_at timestamptz;
