-- Siklus hidup relawan dan lansia setelah pemasangan (perbaikan dari kritik alur 15 Okt).

-- Relawan: sama dengan 000200 ditambah (a) status ikut turun bila centang dicabut, (b) yayasan menonaktifkan
-- relawan → lansia pasangannya ke perlu_yayasan dan usulan pending dibatalkan, (c) relawan menambah keahlian
-- sendiri → harus diverifikasi ulang, (d) relawan mencabut keahlian yang dibutuhkan pasangannya → lansia dilepas.
-- security definer karena efek samping menulis elders/proposals (relawan dan yayasan tidak punya hak itu).
create or replace function public.volunteers_checks()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  check_cols text[] := array['id_checked_by', 'id_checked_at', 'oriented_by', 'oriented_at', 'status'];
  by_self boolean := tg_op = 'UPDATE' and auth.uid() is not null and auth.uid() = old.id;
begin
  if tg_op = 'UPDATE' and auth.uid() is not null then
    if by_self then
      if (to_jsonb(new) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path')
         is distinct from
         (to_jsonb(old) - 'area_label' - 'lat' - 'lng' - 'available_days' - 'languages'
          - 'can_dementia' - 'can_mobility' - 'photo_path') then
        raise exception 'Relawan tidak bisa memverifikasi dirinya sendiri';
      end if;
    elsif (to_jsonb(new) - check_cols) is distinct from (to_jsonb(old) - check_cols) then
      raise exception 'Yayasan hanya boleh mengubah centang verifikasi';
    end if;
  end if;

  -- (c) keahlian baru yang diisi sendiri → verifikasi ulang oleh yayasan
  if by_self and ((new.can_dementia and not old.can_dementia) or (new.can_mobility and not old.can_mobility)) then
    new.id_checked_by := null;
    new.oriented_by := null;
  end if;

  if new.id_checked_by is distinct from old.id_checked_by or tg_op = 'INSERT' then
    new.id_checked_at := case when new.id_checked_by is null then null else coalesce(new.id_checked_at, now()) end;
  end if;
  if new.oriented_by is distinct from old.oriented_by or tg_op = 'INSERT' then
    new.oriented_at := case when new.oriented_by is null then null else coalesce(new.oriented_at, now()) end;
  end if;
  -- (a) status selalu mengikuti dua centang
  new.status := case when new.id_checked_by is not null and new.oriented_by is not null then 'aktif' else 'terdaftar' end;

  if tg_op = 'UPDATE' then
    -- (b) dinonaktifkan oleh yayasan (bukan karena menambah keahlian sendiri)
    if old.status = 'aktif' and new.status = 'terdaftar' and not by_self then
      update public.elders set volunteer_id = null, pairing_state = 'perlu_yayasan'
        where volunteer_id = new.id and pairing_state = 'berpasangan';
      update public.elders set pairing_state = 'mencari'
        where id in (select elder_id from public.proposals where volunteer_id = new.id and state = 'pending');
      delete from public.proposals where volunteer_id = new.id and state = 'pending';
    end if;
    -- (d) keahlian dicabut padahal pasangannya membutuhkan
    if (old.can_dementia and not new.can_dementia) or (old.can_mobility and not new.can_mobility) then
      update public.elders set volunteer_id = null, pairing_state = 'perlu_yayasan'
        where volunteer_id = new.id and pairing_state = 'berpasangan'
          and ((has_dementia and not new.can_dementia) or (has_mobility_issue and not new.can_mobility));
    end if;
  end if;
  return new;
end;
$$;

-- Lansia: kebutuhan berubah (demensia/mobilitas) dan relawannya tidak mampu → diteruskan ke yayasan.
create function public.elders_requirements()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.pairing_state = 'berpasangan' and new.volunteer_id is not null
     and exists (select 1 from public.volunteers v where v.id = new.volunteer_id
                 and ((new.has_dementia and not v.can_dementia) or (new.has_mobility_issue and not v.can_mobility))) then
    new.volunteer_id := null;
    new.pairing_state := 'perlu_yayasan';
  end if;
  return new;
end;
$$;

create trigger elders_requirements
  before update of has_dementia, has_mobility_issue on public.elders
  for each row execute function public.elders_requirements();
