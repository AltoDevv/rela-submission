-- Hapus akun (UU PDP): riwayat kunjungan dan darurat milik lansia tetap ada saat akun relawan dihapus,
-- kolom relawannya dikosongkan. Pasangan aktif dilepas lebih dulu oleh Edge Function `account`.
alter table public.visits alter column volunteer_id drop not null;
alter table public.visits drop constraint visits_volunteer_id_fkey,
  add constraint visits_volunteer_id_fkey foreign key (volunteer_id) references public.volunteers (id) on delete set null;
alter table public.emergencies alter column volunteer_id drop not null;
alter table public.emergencies drop constraint emergencies_volunteer_id_fkey,
  add constraint emergencies_volunteer_id_fkey foreign key (volunteer_id) references public.volunteers (id) on delete set null;
alter table public.elders drop constraint elders_volunteer_id_fkey,
  add constraint elders_volunteer_id_fkey foreign key (volunteer_id) references public.volunteers (id) on delete set null;
