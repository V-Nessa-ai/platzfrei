-- Profile infos (z.B. Pferdename)
create table public.profile_infos (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  label      text not null,
  created_at timestamptz not null default now()
);

alter table public.profile_infos enable row level security;

create policy "Users manage own infos"
  on public.profile_infos for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy "Members read infos in same org"
  on public.profile_infos for select
  using (
    exists (
      select 1 from public.memberships m1
        join public.memberships m2 on m1.organization_id = m2.organization_id
      where m1.profile_id = auth.uid() and m1.status = 'active'
        and m2.profile_id = profile_infos.profile_id and m2.status = 'active'
    )
  );

-- Öffnungszeiten pro Platz
alter table public.courts
  add column if not exists open_from time not null default '07:00',
  add column if not exists open_until time not null default '22:00';

-- Gewählte Info bei einer Buchung
alter table public.bookings
  add column if not exists info_id uuid references public.profile_infos(id) on delete set null;
