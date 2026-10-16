-- Regresi 001100: INSERT ... RETURNING memeriksa policy SELECT terhadap baris baru, tetapi is_family()
-- belum bisa melihat baris yang sedang disisipkan oleh perintah yang sama. Pendaftar dicek langsung dari kolom.
drop policy "keluarga: baca miliknya" on public.elders;
create policy "keluarga: baca miliknya" on public.elders
  for select to authenticated using (family_id = auth.uid() or public.is_family(id));
