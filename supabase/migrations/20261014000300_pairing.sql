-- T-011: kartu usulan relawan untuk keluarga (PRD F2a, architecture.md Alur A langkah 3).
-- Keluarga tidak punya akses ke tabel volunteers, jadi kartu dibaca lewat RPC security definer ini.
-- HP dan lat/lng relawan sengaja tidak ikut.

create function public.get_proposal_card(proposal_id uuid)
returns table (
  id uuid,
  attempt int,
  state text,
  rejects_left int,
  volunteer_name text,
  foundation_name text,
  photo_path text,
  can_dementia boolean,
  can_mobility boolean,
  available_days text[],
  languages text[],
  distance_km numeric,
  reason_text text,
  verification text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.attempt, p.state, 3 - p.attempt,
    pr.full_name, f.name, v.photo_path, v.can_dementia, v.can_mobility, v.available_days, v.languages,
    p.distance_km, p.reason_text,
    concat_ws(' · ',
      case when v.id_checked_by is not null then 'Identitas dicek tatap muka oleh pengurus ' || f.name end,
      case when v.oriented_by is not null then 'Sudah mengikuti orientasi' end)
  from public.proposals p
  join public.elders e on e.id = p.elder_id
  join public.volunteers v on v.id = p.volunteer_id
  join public.profiles pr on pr.id = v.id
  join public.foundations f on f.id = v.foundation_id
  where p.id = get_proposal_card.proposal_id
    and e.family_id = auth.uid() -- hanya keluarga pemilik lansia; selain itu hasilnya kosong
$$;

revoke execute on function public.get_proposal_card(uuid) from public, anon;
grant execute on function public.get_proposal_card(uuid) to authenticated;

-- Foto relawan: signed URL tidak bisa dibuat dari SQL, jadi RPC mengembalikan photo_path dan aplikasi
-- memanggil createSignedUrl. Policy ini mengizinkannya hanya untuk relawan yang pernah diusulkan
-- ke lansia milik keluarga pemanggil.
create policy "keluarga: baca foto relawan yang diusulkan" on storage.objects
  for select to authenticated
  using (bucket_id = 'volunteer-photos' and exists (
    select 1 from public.proposals p
    join public.elders e on e.id = p.elder_id
    where p.volunteer_id::text = (storage.foldername(name))[1] and e.family_id = auth.uid()));
