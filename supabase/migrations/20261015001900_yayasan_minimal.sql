-- Prinsip data minimal (UU PDP) dan sesuai Syarat & Persetujuan: yayasan melihat ringkasan, bukan cerita lengkap
-- relawan (`visits.answers`) atau hasil AI per kunjungan. Dashboard tetap mendapat ringkasan lewat
-- foundation_dashboard (security definer); Edge Function memakai service role.
drop policy "yayasan: baca kunjungan yayasannya" on public.visits;
