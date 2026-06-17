-- ============================================================
-- Platzfrei – Initial Schema
-- ============================================================

-- Enable UUID generation
create extension if not exists "pgcrypto";

-- ============================================================
-- TABLES
-- ============================================================

create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  phone       text,
  display_name text,
  role        text not null default 'member' check (role in ('member', 'admin', 'superadmin')),
  created_at  timestamptz not null default now()
);

create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  sport_type  text not null check (sport_type in ('tennis', 'horse_riding', 'other')),
  invite_code text not null unique default upper(substring(gen_random_uuid()::text, 1, 8)),
  owner_id    uuid not null references public.profiles(id) on delete restrict,
  open_from   time,
  open_until  time,
  created_at  timestamptz not null default now()
);

create table public.memberships (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id      uuid not null references public.profiles(id) on delete cascade,
  status          text not null default 'pending' check (status in ('pending', 'active', 'suspended')),
  joined_at       timestamptz,
  created_at      timestamptz not null default now(),
  unique (organization_id, profile_id)
);

create table public.courts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name            text not null,
  is_active       boolean not null default true,
  slot_minutes    integer not null default 60 check (slot_minutes > 0),
  created_at      timestamptz not null default now()
);

create table public.bookings (
  id          uuid primary key default gen_random_uuid(),
  court_id    uuid not null references public.courts(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  start_time  timestamptz not null,
  end_time    timestamptz not null,
  status      text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
  created_at  timestamptz not null default now(),
  constraint bookings_start_before_end check (end_time > start_time)
);

create table public.app_licenses (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  license_key     text not null unique,
  status          text not null default 'inactive' check (status in ('inactive', 'active', 'expired', 'revoked')),
  activated_at    timestamptz,
  expires_at      timestamptz,
  created_at      timestamptz not null default now()
);

-- ============================================================
-- INDEXES
-- ============================================================

create index on public.memberships (organization_id);
create index on public.memberships (profile_id);
create index on public.courts (organization_id);
create index on public.bookings (court_id, start_time);
create index on public.bookings (profile_id);
create index on public.app_licenses (organization_id);

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'phone'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- HELPER: is_org_admin
-- Returns true if the current user owns or is an admin member
-- ============================================================

create or replace function public.is_org_admin(org_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.organizations
    where id = org_id and owner_id = auth.uid()
  )
  or exists (
    select 1 from public.memberships
    where organization_id = org_id
      and profile_id = auth.uid()
      and status = 'active'
    -- extend here if you add per-membership roles
  );
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles      enable row level security;
alter table public.organizations enable row level security;
alter table public.memberships   enable row level security;
alter table public.courts        enable row level security;
alter table public.bookings      enable row level security;
alter table public.app_licenses  enable row level security;

-- ---------- profiles ----------

create policy "Users can read their own profile"
  on public.profiles for select
  using (id = auth.uid());

create policy "Users can update their own profile"
  on public.profiles for update
  using (id = auth.uid());

-- Org admins need to read member profiles
create policy "Org admins can read member profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.memberships m
        join public.organizations o on o.id = m.organization_id
      where m.profile_id = profiles.id
        and o.owner_id = auth.uid()
    )
  );

-- ---------- organizations ----------

create policy "Anyone can read organizations"
  on public.organizations for select
  using (true);

create policy "Authenticated users can create organizations"
  on public.organizations for insert
  with check (auth.uid() is not null and owner_id = auth.uid());

create policy "Owner can update their organization"
  on public.organizations for update
  using (owner_id = auth.uid());

create policy "Owner can delete their organization"
  on public.organizations for delete
  using (owner_id = auth.uid());

-- ---------- memberships ----------

create policy "Members can read memberships in their orgs"
  on public.memberships for select
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.organizations
      where id = memberships.organization_id and owner_id = auth.uid()
    )
  );

create policy "Users can request membership"
  on public.memberships for insert
  with check (profile_id = auth.uid());

create policy "Org owner can manage memberships"
  on public.memberships for update
  using (
    exists (
      select 1 from public.organizations
      where id = memberships.organization_id and owner_id = auth.uid()
    )
  );

create policy "Owner or member can delete membership"
  on public.memberships for delete
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.organizations
      where id = memberships.organization_id and owner_id = auth.uid()
    )
  );

-- ---------- courts ----------

create policy "Active members can read courts"
  on public.courts for select
  using (
    exists (
      select 1 from public.memberships
      where organization_id = courts.organization_id
        and profile_id = auth.uid()
        and status = 'active'
    )
    or exists (
      select 1 from public.organizations
      where id = courts.organization_id and owner_id = auth.uid()
    )
  );

create policy "Org owner can manage courts"
  on public.courts for insert
  with check (
    exists (
      select 1 from public.organizations
      where id = courts.organization_id and owner_id = auth.uid()
    )
  );

create policy "Org owner can update courts"
  on public.courts for update
  using (
    exists (
      select 1 from public.organizations
      where id = courts.organization_id and owner_id = auth.uid()
    )
  );

create policy "Org owner can delete courts"
  on public.courts for delete
  using (
    exists (
      select 1 from public.organizations
      where id = courts.organization_id and owner_id = auth.uid()
    )
  );

-- ---------- bookings ----------

create policy "Members can read bookings in their orgs"
  on public.bookings for select
  using (
    exists (
      select 1 from public.courts c
        join public.memberships m on m.organization_id = c.organization_id
      where c.id = bookings.court_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
    or exists (
      select 1 from public.courts c
        join public.organizations o on o.id = c.organization_id
      where c.id = bookings.court_id and o.owner_id = auth.uid()
    )
  );

create policy "Active members can create bookings"
  on public.bookings for insert
  with check (
    profile_id = auth.uid()
    and exists (
      select 1 from public.courts c
        join public.memberships m on m.organization_id = c.organization_id
      where c.id = bookings.court_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );

create policy "Booking owner can cancel their booking"
  on public.bookings for update
  using (profile_id = auth.uid());

create policy "Org owner can manage all bookings"
  on public.bookings for update
  using (
    exists (
      select 1 from public.courts c
        join public.organizations o on o.id = c.organization_id
      where c.id = bookings.court_id and o.owner_id = auth.uid()
    )
  );

-- ---------- app_licenses ----------

create policy "Org owner can read their licenses"
  on public.app_licenses for select
  using (
    exists (
      select 1 from public.organizations
      where id = app_licenses.organization_id and owner_id = auth.uid()
    )
  );

-- License creation/management is done server-side via service_role only
