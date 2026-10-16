-- Persetujuan (UU PDP): lansia sendiri setuju, atau keluarga bertindak sebagai wali bila lansia tidak cakap
-- (mis. demensia). Siapa dan kapan diisi trigger, bukan aplikasi, supaya tidak bisa dipalsukan.
alter table public.elders
  add column consent_type text check (consent_type in ('lansia', 'wali')),
  add column consent_by uuid references public.profiles (id) on delete set null,
  add column consent_at timestamptz;
update public.elders set consent_type = 'lansia', consent_at = now() where consent_type is null; -- data seed

grant insert (consent_type) on public.elders to authenticated;

create function public.elders_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    if new.consent_type is null then
      raise exception 'Persetujuan lansia (atau wali) wajib diisi' using errcode = '23514';
    end if;
    new.consent_by := auth.uid();
    new.consent_at := now();
  end if;
  return new;
end;
$$;
create trigger elders_consent before insert on public.elders for each row execute function public.elders_consent();

-- Persetujuan syarat saat daftar akun (metadata terms_accepted = true dari aplikasi).
alter table public.profiles add column terms_accepted_at timestamptz;
create or replace function public.handle_new_user()
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

  insert into public.profiles (id, role, full_name, phone, terms_accepted_at)
  values (new.id, new_role, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'phone',
          case when new.raw_user_meta_data ->> 'terms_accepted' = 'true' then now() end);
  return new;
end;
$$;
