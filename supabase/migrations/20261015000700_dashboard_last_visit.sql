-- Kunjungan terakhir per lansia di dashboard yayasan: tanpa ini, lansia yang tidak lagi dikunjungi
-- tetap tampil "Stabil/Didampingi" selamanya. Isi fungsi sama dengan 000500 + last_visit_at.
create or replace function public.foundation_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  f uuid := public.my_admin_foundation();
begin
  if f is null then
    raise exception 'Khusus pengurus yayasan' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'elders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'full_name', e.full_name,
        'status', e.status,
        'status_reason', e.status_reason,
        'pairing_state', e.pairing_state,
        'has_chronic', coalesce(h.has_chronic, false),
        'last_visit_at', (select max(v.visited_at) from public.visits v
                          where v.elder_id = e.id and v.confirmed_at is not null)
      ) order by e.full_name)
      from public.elders e
      left join public.health_profiles h on h.elder_id = e.id
      where e.foundation_id = f or e.pairing_state in ('tanpa_pendamping', 'perlu_yayasan')
    ), '[]'::jsonb),
    'counts', jsonb_build_object(
      'didampingi', (select count(*) from public.elders where foundation_id = f and pairing_state = 'berpasangan'),
      'tanpa_pendamping', (select count(*) from public.elders where pairing_state = 'tanpa_pendamping'),
      'perlu_yayasan', (select count(*) from public.elders where pairing_state = 'perlu_yayasan')
    ),
    'volunteers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'full_name', p.full_name,
        'status', v.status,
        'max_load', v.max_load,
        'load', (select count(*) from public.elders x where x.volunteer_id = v.id and x.pairing_state = 'berpasangan')
      ) order by p.full_name)
      from public.volunteers v
      join public.profiles p on p.id = v.id
      where v.foundation_id = f
    ), '[]'::jsonb)
  );
end;
$$;
