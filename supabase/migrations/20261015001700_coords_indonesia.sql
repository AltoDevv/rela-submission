-- Titik lokasi dari peta (aplikasi) atau API: harus lengkap (lat & lng) dan berada di Indonesia, supaya jarak
-- pemasangan tidak bisa dirusak koordinat asal (mis. 0,0 atau luar negeri).
alter table public.elders add constraint elders_coords_indonesia check (
  (lat is null and lng is null) or (lat between -11.2 and 6.3 and lng between 94.7 and 141.2));
alter table public.volunteers add constraint volunteers_coords_indonesia check (
  (lat is null and lng is null) or (lat between -11.2 and 6.3 and lng between 94.7 and 141.2));
