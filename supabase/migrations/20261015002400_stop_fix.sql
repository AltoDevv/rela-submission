-- Perbaikan 002300: kolom keluaran approve_stop_request (elder_id, volunteer_id) bertabrakan dengan nama kolom
-- tabel di dalam fungsi, sehingga UPDATE elders gagal "ambiguous". Kolom tabel kini diberi alias.
create or replace function public.approve_stop_request(p_id uuid, p_by text)
returns table (elder_id uuid, volunteer_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  r public.stop_requests;
begin
  update public.stop_requests s set decided_at = now(), decided_by = left(p_by, 100)
    where s.id = p_id and s.decided_at is null returning s.* into r;
  if r.id is null then
    return;
  end if;
  update public.elders e set volunteer_id = null, pairing_state = 'perlu_yayasan'
    where e.id = r.elder_id and e.volunteer_id = r.volunteer_id and e.pairing_state = 'berpasangan';
  return query select r.elder_id, r.volunteer_id;
end;
$$;
revoke execute on function public.approve_stop_request from public, anon, authenticated;
