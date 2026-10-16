-- Celah: tabel visits tidak dibatasi per kolom, sehingga relawan bisa menulis ai_result, final_result,
-- confirmed_at, dan visited_at langsung lewat API (memalsukan kunjungan terkonfirmasi atau mengubah hasil AI).
-- Relawan hanya boleh membuat kunjungan berisi cerita. Kolom lain diisi Edge Function `visit` (service_role).
revoke insert, update on public.visits from anon, authenticated;
grant insert (elder_id, volunteer_id, answers) on public.visits to authenticated;
-- Policy "relawan: ubah kunjungan pasangannya" tidak dipakai lagi: koreksi lewat server (aksi revise di visit).
drop policy "relawan: ubah kunjungan pasangannya" on public.visits;
