-- Evaluasi ke-4 (15 Okt).

-- Perbaikan 001700: `lng between …` bernilai NULL bila lng kosong, dan CHECK menganggap NULL lolos.
alter table public.elders drop constraint elders_coords_indonesia;
alter table public.elders add constraint elders_coords_indonesia check (
  (lat is null and lng is null)
  or (lat is not null and lng is not null and lat between -11.2 and 6.3 and lng between 94.7 and 141.2));
alter table public.volunteers drop constraint volunteers_coords_indonesia;
alter table public.volunteers add constraint volunteers_coords_indonesia check (
  (lat is null and lng is null)
  or (lat is not null and lng is not null and lat between -11.2 and 6.3 and lng between 94.7 and 141.2));

-- Setiap kunjungan baru = satu panggilan Gemini (kuota gratis kecil). Cerita yang belum dikonfirmasi dibatasi
-- 3 per lansia per hari supaya kuota tidak bisa dihabiskan satu akun relawan.
create or replace function public.visits_one_per_day()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (new.visited_at at time zone 'Asia/Jakarta')::date;
begin
  if auth.uid() is null then
    return new;
  end if;
  if exists (
    select 1 from public.visits where elder_id = new.elder_id and confirmed_at is not null
      and (visited_at at time zone 'Asia/Jakarta')::date = today
  ) then
    raise exception 'Kunjungan hari ini sudah dicatat. Bila ada yang salah, pakai "Koreksi kunjungan terakhir".'
      using errcode = '23505';
  end if;
  if (select count(*) from public.visits where elder_id = new.elder_id
        and (visited_at at time zone 'Asia/Jakarta')::date = today) >= 3 then
    raise exception 'Sudah 3 kali mencoba menyimpan cerita hari ini. Coba lagi besok atau hubungi yayasan.'
      using errcode = '23505';
  end if;
  return new;
end;
$$;
