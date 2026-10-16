-- Tampilan yayasan dari Figma (16 Okt): kartu "Pendampingan · ▲N baru minggu ini" dan nama penulis ulasan.

-- (1) Kapan pasangan saat ini dimulai. Diisi trigger setiap kali lansia mendapat pendamping (baru atau ganti).
alter table public.elders add column paired_at timestamptz;
update public.elders e
  set paired_at = coalesce((select min(v.visited_at) from public.visits v
                            where v.elder_id = e.id and v.volunteer_id = e.volunteer_id), e.created_at)
  where e.pairing_state = 'berpasangan';

create function public.elders_paired_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.pairing_state = 'berpasangan' and new.volunteer_id is not null
     and (tg_op = 'INSERT' or old.pairing_state is distinct from 'berpasangan'
          or old.volunteer_id is distinct from new.volunteer_id) then
    new.paired_at := now();
  end if;
  return new;
end;
$$;
create trigger elders_paired_at before insert or update of pairing_state, volunteer_id on public.elders
  for each row execute function public.elders_paired_at();

-- (2) Nama penulis masukan keluarga untuk pengurus yayasan relawan yang diulas (keputusan pengguna 16 Okt).
-- Pengurus sudah melihat KTP keluarga saat verifikasi; RLS profiles tetap tertutup, jadi lewat fungsi ini.
create function public.foundation_review_authors()
returns table (review_id uuid, author_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, p.full_name
  from public.reviews r
  join public.volunteers v on v.id = r.volunteer_id
  join public.profiles p on p.id = r.author_id
  where v.foundation_id = public.my_admin_foundation();
$$;
revoke execute on function public.foundation_review_authors from public, anon;
grant execute on function public.foundation_review_authors to authenticated;
