-- Keluarga minta ganti pendamping (keputusan pengguna 15 Okt): wajib alasan, maks. 1× per 30 hari per lansia,
-- pengganti lewat pencocokan otomatis (bisa dari yayasan lain). Setelah jatah habis, masalah serius lewat laporan
-- serius ke yayasan. Ditulis Edge Function pairing (aksi change); tabel ini juga menjadi riwayat pergantian.
create table public.pairing_changes (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid references public.volunteers (id) on delete set null, -- relawan lama
  requested_by uuid references public.profiles (id) on delete set null,
  reason text not null check (reason in ('jadwal', 'tidak_cocok', 'perbaikan', 'serius')),
  note text check (length(note) <= 300),
  created_at timestamptz not null default now()
);
create index pairing_changes_elder on public.pairing_changes (elder_id, created_at desc);
alter table public.pairing_changes enable row level security;
create policy "keluarga: baca riwayat ganti lansianya" on public.pairing_changes
  for select to authenticated using (public.is_family(elder_id));
create policy "yayasan: baca ganti dari relawannya" on public.pairing_changes
  for select to authenticated using (exists (
    select 1 from public.volunteers v where v.id = volunteer_id and v.foundation_id = public.my_admin_foundation()));
