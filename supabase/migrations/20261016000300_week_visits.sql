-- Beranda yayasan (Figma "Ringkasan minggu ini"): hanya WAKTU kunjungan terkonfirmasi lansia yayasan ini, maksimal
-- 8 hari ke belakang. Yayasan tetap tidak membaca tabel visits (prinsip data minimal, migration 001900).
create function public.foundation_week_visits(p_since timestamptz)
returns setof timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select v.visited_at
  from public.visits v join public.elders e on e.id = v.elder_id
  where e.foundation_id = public.my_admin_foundation()
    and v.confirmed_at is not null
    and v.visited_at >= greatest(p_since, now() - interval '8 days');
$$;
revoke execute on function public.foundation_week_visits from public, anon;
grant execute on function public.foundation_week_visits to authenticated;
