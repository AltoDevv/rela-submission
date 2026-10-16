-- (1) Masukan keluarga untuk relawan (bukan bintang). Kategori menentukan siapa yang melihat:
--   apresiasi → relawan + yayasan; perbaikan → yayasan saja (yayasan yang membina); serius → yayasan saja,
--   langsung lewat push, relawan tidak melihat (melindungi keluarga dari pembalasan).
-- Ditulis lewat Edge Function `review` (batas frekuensi + push); ditandai ditangani lewat RPC handle_review.
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  volunteer_id uuid not null references public.volunteers (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('apresiasi', 'perbaikan', 'serius')),
  body text not null check (length(trim(body)) between 3 and 500),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by text check (length(handled_by) <= 100),
  handled_note text check (length(handled_note) <= 300)
);
create index reviews_volunteer on public.reviews (volunteer_id, created_at desc);
alter table public.reviews enable row level security;
create policy "keluarga: baca masukan lansianya" on public.reviews
  for select to authenticated using (public.is_family(elder_id));
create policy "relawan: baca apresiasi untuknya" on public.reviews
  for select to authenticated using (volunteer_id = auth.uid() and kind = 'apresiasi');
create policy "yayasan: baca masukan relawannya" on public.reviews
  for select to authenticated using (exists (
    select 1 from public.volunteers v where v.id = volunteer_id and v.foundation_id = public.my_admin_foundation()));
-- Tanpa policy insert/update: hanya Edge Function (service role) dan RPC di bawah.

create function public.handle_review(p_review_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me record;
begin
  select full_name, foundation_id into me from public.profiles where id = auth.uid() and role = 'yayasan';
  update public.reviews r set handled_at = now(), handled_by = me.full_name, handled_note = left(trim(p_note), 300)
    from public.volunteers v
    where r.id = p_review_id and v.id = r.volunteer_id and v.foundation_id = me.foundation_id and r.handled_at is null;
  if not found then
    raise exception 'Masukan tidak ditemukan atau sudah ditangani' using errcode = '42501';
  end if;
end;
$$;

-- (2) Riwayat pembayaran langganan (bukti untuk keluarga). Diisi simulate_payment; produksi: webhook gateway.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  elder_id uuid not null references public.elders (id) on delete cascade,
  paid_by uuid references public.profiles (id) on delete set null,
  period_end timestamptz not null,
  provider text not null default 'simulasi',
  created_at timestamptz not null default now()
);
alter table public.payments enable row level security;
create policy "keluarga: baca pembayaran lansianya" on public.payments
  for select to authenticated using (public.is_family(elder_id));

create or replace function public.simulate_payment(p_elder_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  until timestamptz;
begin
  update public.elders set paid_until = greatest(coalesce(paid_until, now()), now()) + interval '30 days',
      paid_by = auth.uid()
    where id = p_elder_id and family_id = auth.uid()
    returning paid_until into until;
  if until is null then
    raise exception 'Hanya keluarga yang mendaftarkan lansia ini' using errcode = '42501';
  end if;
  insert into public.payments (elder_id, paid_by, period_end) values (p_elder_id, auth.uid(), until);
  return until;
end;
$$;

-- (3) Langganan habis: pendampingan berjalan selama masa tenggang 7 hari, setelah itu kunjungan baru ditolak.
create or replace function public.visits_need_verified()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  e record;
begin
  if auth.uid() is null then
    return new;
  end if;
  select verify_state, first_visit_at, paid_until into e from public.elders where id = new.elder_id;
  if e.verify_state is distinct from 'terverifikasi' or e.first_visit_at is null then
    raise exception 'Keluarga belum terverifikasi atau kunjungan pertama belum dikonfirmasi.' using errcode = '42501';
  end if;
  if e.paid_until is null or e.paid_until < now() - interval '7 days' then
    raise exception 'Langganan lansia ini sudah berakhir lebih dari 7 hari. Keluarga perlu memperpanjang.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.handle_review from public, anon;
grant execute on function public.handle_review to authenticated;
