-- T-003: yayasan, profil, dan peran akun.

create table public.foundations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  verified boolean not null default false,
  invite_code text not null unique check (length(invite_code) = 6),
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('keluarga', 'relawan', 'yayasan')),
  full_name text,
  phone text,
  phone_verified boolean not null default false,
  foundation_id uuid references public.foundations (id),
  fcm_token text,
  created_at timestamptz not null default now()
);

-- Sign-up hanya boleh sebagai keluarga atau relawan. Akun yayasan dibuat lewat seed (F0 P3).
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_role text := new.raw_user_meta_data ->> 'role';
begin
  if new_role is null or new_role not in ('keluarga', 'relawan') then
    raise exception 'Peran tidak valid untuk pendaftaran: %', coalesce(new_role, '(kosong)');
  end if;

  insert into public.profiles (id, role, full_name, phone)
  values (new.id, new_role, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'phone');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS: pengguna hanya membaca dan mengubah barisnya sendiri.
alter table public.profiles enable row level security;
alter table public.foundations enable row level security;

create policy "profil sendiri: baca" on public.profiles
  for select to authenticated using (id = auth.uid());

create policy "profil sendiri: ubah" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "yayasan sendiri: baca" on public.foundations
  for select to authenticated
  using (id = (select foundation_id from public.profiles where id = auth.uid()));

-- role dan foundation_id tidak bisa diubah pemiliknya: hanya kolom ini yang boleh di-update dari aplikasi.
-- Perubahan role/foundation_id lewat RPC security definer atau seed.
revoke update on public.profiles from anon, authenticated;
grant update (full_name, phone, phone_verified, fcm_token) on public.profiles to authenticated;
