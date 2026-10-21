-- Initial relational model for the survey MVP.
-- Apply only to a development Supabase project during implementation.
create extension if not exists pgcrypto;

create type public.app_role as enum ('admin', 'supervisor', 'surveyor', 'analyst');
create type public.campaign_status as enum ('draft', 'active', 'paused', 'closed');
create type public.assignment_status as enum ('assigned', 'in_progress', 'submitted', 'approved', 'revision_requested');
create type public.submission_status as enum ('draft', 'submitted', 'approved', 'revision_requested');
create type public.measurement_kind as enum ('observed', 'estimated', 'actual');
create type public.availability_status as enum ('available', 'unavailable', 'unknown');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role public.app_role not null default 'surveyor',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.territories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('region', 'depot', 'district')),
  parent_id uuid references public.territories(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (parent_id, kind, name),
  check ((kind = 'region' and parent_id is null) or (kind <> 'region' and parent_id is not null))
);

create table public.profile_territories (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  territory_id uuid not null references public.territories(id) on delete cascade,
  primary key (profile_id, territory_id)
);

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true
);

create table public.outlets (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  territory_id uuid not null references public.territories(id) on delete restrict,
  channel_id uuid not null references public.channels(id) on delete restrict,
  address text,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true
);

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  owner_name text,
  active boolean not null default true
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku_code text not null unique,
  name text not null,
  brand_id uuid not null references public.brands(id) on delete restrict,
  category_id uuid not null references public.categories(id) on delete restrict,
  package_size text not null,
  active boolean not null default true
);

create table public.survey_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status public.campaign_status not null default 'draft',
  starts_on date not null,
  ends_on date not null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table public.survey_assignments (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.survey_campaigns(id) on delete cascade,
  outlet_id uuid not null references public.outlets(id) on delete restrict,
  surveyor_id uuid not null references public.profiles(id) on delete restrict,
  status public.assignment_status not null default 'assigned',
  due_on date,
  assigned_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (campaign_id, outlet_id, surveyor_id)
);

create table public.survey_submissions (
  id uuid primary key, -- client-generated idempotency key
  assignment_id uuid not null references public.survey_assignments(id) on delete restrict,
  status public.submission_status not null default 'draft',
  captured_by uuid not null references public.profiles(id) on delete restrict,
  captured_at timestamptz,
  submitted_at timestamptz,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (status = 'draft' or submitted_at is not null)
);

create table public.survey_items (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.survey_submissions(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  measurement public.measurement_kind not null default 'observed',
  availability public.availability_status not null default 'unknown',
  selling_price numeric(12,2) check (selling_price >= 0),
  promotion_price numeric(12,2) check (promotion_price >= 0),
  visible_stock integer check (visible_stock >= 0),
  facing_count integer check (facing_count >= 0),
  promotion_activity text,
  price_review_required boolean generated always as (
    selling_price is not null and (selling_price < 100 or selling_price > 10000000)
  ) stored,
  created_at timestamptz not null default now(),
  unique (submission_id, product_id, measurement),
  check (selling_price is null or promotion_price is null or promotion_price <= selling_price)
);

create table public.survey_photos (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.survey_submissions(id) on delete cascade,
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  byte_size integer not null check (byte_size between 1 and 10485760),
  uploaded_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.review_logs (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.survey_submissions(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in ('approved', 'revision_requested')),
  note text,
  created_at timestamptz not null default now()
);

create index outlets_territory_idx on public.outlets(territory_id);
create index products_category_brand_idx on public.products(category_id, brand_id);
create index assignments_surveyor_status_idx on public.survey_assignments(surveyor_id, status);
create index assignments_campaign_outlet_idx on public.survey_assignments(campaign_id, outlet_id);
create index submissions_assignment_status_idx on public.survey_submissions(assignment_id, status);
create index submissions_captured_at_idx on public.survey_submissions(captured_at desc);
create index survey_items_product_idx on public.survey_items(product_id);
create index photos_submission_idx on public.survey_photos(submission_id);
create index review_logs_submission_created_idx on public.review_logs(submission_id, created_at desc);

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and active $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() = 'admin', false) $$;

create or replace function public.can_access_assignment(target_assignment uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.is_admin() or exists (
    select 1 from public.survey_assignments a
    where a.id = target_assignment
      and (a.surveyor_id = auth.uid()
        or (public.current_role() in ('supervisor', 'analyst') and exists (
          select 1 from public.outlets o
          join public.profile_territories pt on pt.territory_id = o.territory_id
          where o.id = a.outlet_id and pt.profile_id = auth.uid()
        ))
        or public.current_role() = 'analyst')
  )
$$;

alter table public.profiles enable row level security;
alter table public.territories enable row level security;
alter table public.profile_territories enable row level security;
alter table public.channels enable row level security;
alter table public.outlets enable row level security;
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.products enable row level security;
alter table public.survey_campaigns enable row level security;
alter table public.survey_assignments enable row level security;
alter table public.survey_submissions enable row level security;
alter table public.survey_items enable row level security;
alter table public.survey_photos enable row level security;
alter table public.review_logs enable row level security;

-- Users cannot grant themselves roles; profile writes are reserved for trusted admin/server setup.
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profiles_admin_manage on public.profiles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy territories_authenticated_read on public.territories for select to authenticated using (true);
create policy territories_admin_manage on public.territories for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy profile_territories_self_or_admin_read on public.profile_territories for select to authenticated
  using (profile_id = auth.uid() or public.is_admin());
create policy profile_territories_admin_manage on public.profile_territories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy channels_authenticated_read on public.channels for select to authenticated using (true);
create policy channels_admin_manage on public.channels for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy categories_authenticated_read on public.categories for select to authenticated using (true);
create policy categories_admin_manage on public.categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy brands_authenticated_read on public.brands for select to authenticated using (true);
create policy brands_admin_manage on public.brands for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy products_authenticated_read on public.products for select to authenticated using (true);
create policy products_admin_manage on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy outlets_authorized_read on public.outlets for select to authenticated using (
  public.is_admin() or exists (
    select 1 from public.profile_territories pt where pt.profile_id = auth.uid() and pt.territory_id = outlets.territory_id
  ) or exists (
    select 1 from public.survey_assignments a where a.outlet_id = outlets.id and a.surveyor_id = auth.uid()
  )
);
create policy outlets_admin_manage on public.outlets for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy campaigns_authorized_read on public.survey_campaigns for select to authenticated using (
  public.is_admin() or exists (
    select 1 from public.survey_assignments a where a.campaign_id = survey_campaigns.id and public.can_access_assignment(a.id)
  )
);
create policy campaigns_admin_manage on public.survey_campaigns for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy assignments_authorized_read on public.survey_assignments for select to authenticated using (
  public.is_admin() or surveyor_id = auth.uid() or
  (public.current_role() = 'supervisor' and exists (
    select 1 from public.outlets o join public.profile_territories pt on pt.territory_id = o.territory_id
    where o.id = survey_assignments.outlet_id and pt.profile_id = auth.uid()
  ))
);
create policy assignments_admin_manage on public.survey_assignments for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy submissions_authorized_read on public.survey_submissions for select to authenticated using (
  public.can_access_assignment(assignment_id)
);
create policy surveyor_insert_own_submission on public.survey_submissions for insert to authenticated with check (
  captured_by = auth.uid() and exists (
    select 1 from public.survey_assignments a where a.id = assignment_id and a.surveyor_id = auth.uid()
  )
);
create policy surveyor_update_own_submission on public.survey_submissions for update to authenticated
  using (captured_by = auth.uid() and status in ('draft', 'revision_requested'))
  with check (captured_by = auth.uid());
create policy supervisor_review_submission on public.survey_submissions for update to authenticated
  using (public.current_role() = 'supervisor' and public.can_access_assignment(assignment_id))
  with check (public.current_role() = 'supervisor' and public.can_access_assignment(assignment_id));

create policy items_authorized_read on public.survey_items for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and public.can_access_assignment(s.assignment_id))
);
create policy surveyor_manage_items on public.survey_items for all to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = auth.uid() and s.status in ('draft', 'revision_requested'))
) with check (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = auth.uid() and s.status in ('draft', 'revision_requested'))
);

create policy photos_authorized_read on public.survey_photos for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and public.can_access_assignment(s.assignment_id))
);
create policy surveyor_manage_photos on public.survey_photos for all to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = auth.uid() and s.status in ('draft', 'revision_requested'))
) with check (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = auth.uid() and s.status in ('draft', 'revision_requested'))
);

create policy review_logs_authorized_read on public.review_logs for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and public.can_access_assignment(s.assignment_id))
);
create policy supervisor_insert_review_log on public.review_logs for insert to authenticated with check (
  reviewer_id = auth.uid() and public.current_role() = 'supervisor' and
  exists (select 1 from public.survey_submissions s where s.id = submission_id and public.can_access_assignment(s.assignment_id))
);

-- Append-only review history.
create policy review_logs_no_update on public.review_logs for update to authenticated using (false) with check (false);
create policy review_logs_no_delete on public.review_logs for delete to authenticated using (false);

