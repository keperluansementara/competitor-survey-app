-- Admin Control Center foundation. Generated with `supabase migration new`.
-- This is a local migration file only; it has not been applied to a remote project.

alter type public.campaign_status add value if not exists 'archived';
alter type public.assignment_status add value if not exists 'in_review';
alter type public.submission_status add value if not exists 'in_review';

-- Expand the territory tree for the Tangerang Utara pilot without deleting history.
alter table public.territories drop constraint if exists territories_kind_check;
alter table public.territories drop constraint if exists territories_check;
update public.territories set kind = 'kecamatan' where kind = 'district';
alter table public.territories add constraint territories_kind_check
  check (kind in ('region', 'depot', 'kecamatan', 'kelurahan'));
alter table public.territories add constraint territories_parent_check
  check ((kind = 'region' and parent_id is null) or (kind <> 'region' and parent_id is not null));

alter table public.profiles add column employee_identifier text unique;
alter table public.brands add column brand_type text not null default 'competitor'
  check (brand_type in ('garudafood', 'competitor', 'other'));
alter table public.products add column pack_quantity numeric(12,3) check (pack_quantity is null or pack_quantity > 0);

create table public.units (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.products add column unit_id uuid references public.units(id) on delete restrict;

alter table public.survey_campaigns
  add column allow_multiple_surveyors_per_outlet boolean not null default false,
  add column prevent_active_campaign_conflicts boolean not null default true,
  add column completion_requires_photo boolean not null default false;

create type public.form_version_state as enum ('draft', 'published', 'archived');
create type public.form_field_type as enum ('text', 'number', 'currency', 'select', 'multi_select', 'yes_no', 'date', 'photo');
create type public.import_kind as enum ('outlet_master', 'campaign_assignment');
create type public.import_state as enum ('uploaded', 'previewed', 'committing', 'committed', 'failed', 'rollback_pending', 'rolled_back');
create type public.import_row_state as enum ('ready', 'new', 'updated', 'unchanged', 'duplicate', 'invalid', 'committed', 'rollback_conflict', 'rolled_back');

create table public.profile_campaign_access (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  campaign_id uuid not null references public.survey_campaigns(id) on delete restrict,
  access_level text not null check (access_level in ('survey', 'review', 'analyze')),
  granted_by uuid not null references public.profiles(id) on delete restrict,
  granted_at timestamptz not null default now(),
  primary key (profile_id, campaign_id, access_level)
);

create table public.survey_form_versions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.survey_campaigns(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  state public.form_version_state not null default 'draft',
  name text not null,
  description text,
  photo_required_count smallint not null default 0 check (photo_required_count between 0 and 3),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  archived_at timestamptz,
  unique (campaign_id, version_number),
  check ((state = 'draft' and published_at is null and archived_at is null)
      or (state = 'published' and published_at is not null and archived_at is null)
      or (state = 'archived' and published_at is not null and archived_at is not null))
);

create table public.survey_form_fields (
  id uuid primary key default gen_random_uuid(),
  form_version_id uuid not null references public.survey_form_versions(id) on delete restrict,
  section_key text not null,
  field_key text not null,
  label text not null,
  help_text text,
  field_type public.form_field_type not null,
  required boolean not null default false,
  visible boolean not null default true,
  sort_order integer not null check (sort_order >= 0),
  choice_options jsonb not null default '[]'::jsonb check (jsonb_typeof(choice_options) = 'array'),
  validation_rules jsonb not null default '{}'::jsonb check (jsonb_typeof(validation_rules) = 'object'),
  visibility_condition jsonb check (visibility_condition is null or (
    jsonb_typeof(visibility_condition) = 'object' and visibility_condition ? 'field_key'
      and visibility_condition ? 'equals' and jsonb_typeof(visibility_condition -> 'field_key') = 'string'
  )),
  created_at timestamptz not null default now(),
  unique (form_version_id, field_key),
  check (field_type not in ('select', 'multi_select') or jsonb_array_length(choice_options) > 0)
);

create table public.survey_form_categories (
  form_version_id uuid not null references public.survey_form_versions(id) on delete restrict,
  category_id uuid not null references public.categories(id) on delete restrict,
  primary key (form_version_id, category_id)
);

create table public.survey_form_products (
  form_version_id uuid not null references public.survey_form_versions(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  primary key (form_version_id, product_id)
);

create table public.survey_field_responses (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.survey_submissions(id) on delete restrict,
  field_id uuid not null references public.survey_form_fields(id) on delete restrict,
  value jsonb not null,
  answered_at timestamptz not null default now(),
  unique (submission_id, field_id)
);

alter table public.survey_submissions
  add column form_version_id uuid references public.survey_form_versions(id) on delete restrict,
  add column review_note text;
create unique index survey_submissions_one_per_assignment_idx on public.survey_submissions(assignment_id);

alter table public.review_logs drop constraint if exists review_logs_action_check;
alter table public.review_logs add constraint review_logs_action_check
  check (action in ('in_review', 'approved', 'revision_requested'));

create table public.survey_submission_revisions (
  id bigint generated always as identity primary key,
  submission_id uuid not null references public.survey_submissions(id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  actor_id uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  unique (submission_id, revision_number)
);

create table public.survey_quality_flags (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.survey_submissions(id) on delete restrict,
  rule_code text not null,
  severity text not null check (severity in ('info', 'warning', 'critical')),
  description text not null,
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (submission_id, rule_code)
);

create table public.survey_sync_receipts (
  submission_id uuid primary key references public.survey_submissions(id) on delete restrict,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  client_synced_at timestamptz,
  server_received_at timestamptz not null default now()
);

create table public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  kind public.import_kind not null,
  state public.import_state not null default 'uploaded',
  source_filename text not null,
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  previewed_at timestamptz,
  committed_at timestamptz,
  rolled_back_at timestamptz,
  total_rows integer not null default 0 check (total_rows >= 0),
  valid_rows integer not null default 0 check (valid_rows >= 0),
  invalid_rows integer not null default 0 check (invalid_rows >= 0),
  new_rows integer not null default 0 check (new_rows >= 0),
  updated_rows integer not null default 0 check (updated_rows >= 0),
  duplicate_rows integer not null default 0 check (duplicate_rows >= 0),
  summary jsonb not null default '{}'::jsonb check (jsonb_typeof(summary) = 'object'),
  check (valid_rows + invalid_rows <= total_rows)
);

create table public.import_job_rows (
  id uuid primary key default gen_random_uuid(),
  import_job_id uuid not null references public.import_jobs(id) on delete restrict,
  row_number integer not null check (row_number > 0),
  state public.import_row_state not null default 'ready',
  source_values jsonb not null check (jsonb_typeof(source_values) = 'object'),
  normalized_values jsonb check (normalized_values is null or jsonb_typeof(normalized_values) = 'object'),
  validation_errors jsonb not null default '[]'::jsonb check (jsonb_typeof(validation_errors) = 'array'),
  operation text check (operation is null or operation in ('insert', 'update', 'skip')),
  entity_id uuid,
  before_snapshot jsonb check (before_snapshot is null or jsonb_typeof(before_snapshot) = 'object'),
  after_snapshot jsonb check (after_snapshot is null or jsonb_typeof(after_snapshot) = 'object'),
  rollback_note text,
  created_at timestamptz not null default now(),
  unique (import_job_id, row_number)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity text not null,
  entity_id text,
  changed_fields text[] not null default '{}',
  occurred_at timestamptz not null default now(),
  request_id text
);

create table public.system_settings (
  key text primary key,
  value jsonb not null,
  description text not null,
  updated_by uuid references public.profiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(value) in ('object', 'array', 'string', 'number', 'boolean'))
);

create index territories_parent_kind_idx on public.territories(parent_id, kind);
create index products_unit_active_idx on public.products(unit_id, active);
create index profile_campaign_access_campaign_idx on public.profile_campaign_access(campaign_id, profile_id);
create index form_versions_campaign_state_idx on public.survey_form_versions(campaign_id, state, version_number desc);
create index form_fields_version_order_idx on public.survey_form_fields(form_version_id, sort_order);
create index submissions_form_version_idx on public.survey_submissions(form_version_id);
create index field_responses_submission_idx on public.survey_field_responses(submission_id);
create index quality_flags_open_idx on public.survey_quality_flags(created_at desc) where resolved_at is null;
create index sync_receipts_received_idx on public.survey_sync_receipts(server_received_at desc);
create index import_jobs_uploaded_idx on public.import_jobs(uploaded_at desc);
create index import_job_rows_job_state_idx on public.import_job_rows(import_job_id, state);
create index audit_logs_entity_time_idx on public.audit_logs(entity, entity_id, occurred_at desc);
create index audit_logs_actor_time_idx on public.audit_logs(actor_id, occurred_at desc);

-- Non-exposed authorization helpers. These inspect only the signed-in user's DB grants.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.user_role()
returns public.app_role
language sql stable security definer set search_path = ''
as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.active
$$;

create or replace function private.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((select private.user_role()) = 'admin', false) $$;

create or replace function private.has_territory_access(target_territory uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profile_territories pt
    where pt.profile_id = (select auth.uid()) and pt.territory_id = target_territory
      and private.user_role() is not null
  )
$$;

create or replace function private.can_access_assignment(target_assignment uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    private.is_admin() or exists (
      select 1
      from public.survey_assignments a
      join public.outlets o on o.id = a.outlet_id
      where a.id = target_assignment
        and (
          (private.user_role() = 'surveyor' and a.surveyor_id = (select auth.uid()))
          or (
            private.user_role() = 'supervisor'
            and private.has_territory_access(o.territory_id)
            and exists (select 1 from public.profile_campaign_access pca
              where pca.profile_id = (select auth.uid()) and pca.campaign_id = a.campaign_id and pca.access_level = 'review')
          )
          or (
            private.user_role() = 'analyst'
            and private.has_territory_access(o.territory_id)
            and exists (select 1 from public.profile_campaign_access pca
              where pca.profile_id = (select auth.uid()) and pca.campaign_id = a.campaign_id and pca.access_level = 'analyze')
          )
        )
    ), false
  )
$$;

revoke all on function private.user_role() from public, anon;
revoke all on function private.is_admin() from public, anon;
revoke all on function private.has_territory_access(uuid) from public, anon;
revoke all on function private.can_access_assignment(uuid) from public, anon;
grant execute on function private.user_role() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.has_territory_access(uuid) to authenticated;
grant execute on function private.can_access_assignment(uuid) to authenticated;

-- Replace public SECURITY DEFINER policy helpers from the first migration with private helpers.
drop policy if exists profiles_read_self_or_admin on public.profiles;
drop policy if exists profiles_admin_manage on public.profiles;
drop policy if exists territories_authenticated_read on public.territories;
drop policy if exists territories_admin_manage on public.territories;
drop policy if exists profile_territories_self_or_admin_read on public.profile_territories;
drop policy if exists profile_territories_admin_manage on public.profile_territories;
drop policy if exists channels_authenticated_read on public.channels;
drop policy if exists channels_admin_manage on public.channels;
drop policy if exists categories_authenticated_read on public.categories;
drop policy if exists categories_admin_manage on public.categories;
drop policy if exists brands_authenticated_read on public.brands;
drop policy if exists brands_admin_manage on public.brands;
drop policy if exists products_authenticated_read on public.products;
drop policy if exists products_admin_manage on public.products;
drop policy if exists outlets_authorized_read on public.outlets;
drop policy if exists outlets_admin_manage on public.outlets;
drop policy if exists campaigns_authorized_read on public.survey_campaigns;
drop policy if exists campaigns_admin_manage on public.survey_campaigns;
drop policy if exists assignments_authorized_read on public.survey_assignments;
drop policy if exists assignments_admin_manage on public.survey_assignments;
drop policy if exists submissions_authorized_read on public.survey_submissions;
drop policy if exists surveyor_insert_own_submission on public.survey_submissions;
drop policy if exists surveyor_update_own_submission on public.survey_submissions;
drop policy if exists supervisor_review_submission on public.survey_submissions;
drop policy if exists items_authorized_read on public.survey_items;
drop policy if exists surveyor_manage_items on public.survey_items;
drop policy if exists photos_authorized_read on public.survey_photos;
drop policy if exists surveyor_manage_photos on public.survey_photos;
drop policy if exists review_logs_authorized_read on public.review_logs;
drop policy if exists supervisor_insert_review_log on public.review_logs;
drop policy if exists review_logs_no_update on public.review_logs;
drop policy if exists review_logs_no_delete on public.review_logs;
drop function if exists public.can_access_assignment(uuid);
drop function if exists public.is_admin();
drop function if exists public.current_role();

-- Table privileges and RLS work together. No client can delete historical master data.
grant select, insert, update on public.profiles, public.territories, public.profile_territories,
  public.profile_campaign_access, public.channels, public.outlets, public.categories,
  public.brands, public.products, public.units, public.survey_campaigns,
  public.survey_assignments, public.survey_form_versions, public.survey_form_fields,
  public.survey_form_categories, public.survey_form_products, public.survey_submissions,
  public.survey_items, public.survey_photos, public.survey_field_responses, public.import_jobs,
  public.import_job_rows, public.system_settings to authenticated;
grant select on public.audit_logs to authenticated;
grant select on public.review_logs to authenticated;
grant select on public.survey_submission_revisions, public.survey_quality_flags, public.survey_sync_receipts to authenticated;
grant insert, update on public.survey_quality_flags to authenticated;
grant insert on public.survey_sync_receipts to authenticated;

alter table public.profile_campaign_access enable row level security;
alter table public.units enable row level security;
alter table public.survey_form_versions enable row level security;
alter table public.survey_form_fields enable row level security;
alter table public.survey_form_categories enable row level security;
alter table public.survey_form_products enable row level security;
alter table public.survey_field_responses enable row level security;
alter table public.import_jobs enable row level security;
alter table public.import_job_rows enable row level security;
alter table public.audit_logs enable row level security;
alter table public.system_settings enable row level security;
alter table public.survey_submission_revisions enable row level security;
alter table public.survey_quality_flags enable row level security;
alter table public.survey_sync_receipts enable row level security;

-- Evidence stays private. Objects are only usable when a matching authorized photo row exists.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('survey-evidence', 'survey-evidence', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
create policy survey_evidence_authorized_read on storage.objects for select to authenticated using (
  bucket_id = 'survey-evidence' and exists (
    select 1 from public.survey_photos p
    join public.survey_submissions s on s.id = p.submission_id
    where p.storage_path = storage.objects.name and (select private.can_access_assignment(s.assignment_id))
  )
);
create policy survey_evidence_owner_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'survey-evidence' and exists (
    select 1 from public.survey_photos p
    join public.survey_submissions s on s.id = p.submission_id
    where p.storage_path = storage.objects.name and s.captured_by = (select auth.uid())
      and s.status in ('draft', 'revision_requested')
  )
);
create policy survey_evidence_owner_delete on storage.objects for delete to authenticated using (
  bucket_id = 'survey-evidence' and exists (
    select 1 from public.survey_photos p
    join public.survey_submissions s on s.id = p.submission_id
    where p.storage_path = storage.objects.name and s.captured_by = (select auth.uid())
      and s.status in ('draft', 'revision_requested')
  )
);

create policy profiles_read_self_or_admin on public.profiles for select to authenticated
  using ((select auth.uid()) = id or (select private.is_admin()));
create policy profiles_admin_manage on public.profiles for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy territories_authenticated_read on public.territories for select to authenticated using (true);
create policy territories_admin_manage on public.territories for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy profile_territories_self_or_admin_read on public.profile_territories for select to authenticated
  using (profile_id = (select auth.uid()) or (select private.is_admin()));
create policy profile_territories_admin_manage on public.profile_territories for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy profile_campaign_access_self_or_admin_read on public.profile_campaign_access for select to authenticated
  using (profile_id = (select auth.uid()) or (select private.is_admin()));
create policy profile_campaign_access_admin_manage on public.profile_campaign_access for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy channels_authenticated_read on public.channels for select to authenticated using (true);
create policy channels_admin_manage on public.channels for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy categories_authenticated_read on public.categories for select to authenticated using (true);
create policy categories_admin_manage on public.categories for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy brands_authenticated_read on public.brands for select to authenticated using (true);
create policy brands_admin_manage on public.brands for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy products_authenticated_read on public.products for select to authenticated using (true);
create policy products_admin_manage on public.products for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy units_authenticated_read on public.units for select to authenticated using (true);
create policy units_admin_manage on public.units for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy outlets_authorized_read on public.outlets for select to authenticated using (
  (select private.is_admin()) or (select private.has_territory_access(territory_id)) or exists (
    select 1 from public.survey_assignments a where a.outlet_id = outlets.id and a.surveyor_id = (select auth.uid())
      and (select private.user_role()) = 'surveyor'
  )
);
create policy outlets_admin_manage on public.outlets for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy campaigns_authorized_read on public.survey_campaigns for select to authenticated using (
  (select private.is_admin()) or exists (
    select 1 from public.survey_assignments a where a.campaign_id = survey_campaigns.id
      and (select private.can_access_assignment(a.id))
  )
);
create policy campaigns_admin_manage on public.survey_campaigns for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy assignments_authorized_read on public.survey_assignments for select to authenticated using (
  (select private.can_access_assignment(id))
);
create policy assignments_admin_manage on public.survey_assignments for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy submissions_authorized_read on public.survey_submissions for select to authenticated
  using ((select private.can_access_assignment(assignment_id)));
create policy surveyor_insert_own_submission on public.survey_submissions for insert to authenticated with check (
  captured_by = (select auth.uid()) and (select private.user_role()) = 'surveyor' and status = 'draft' and exists (
    select 1 from public.survey_assignments a where a.id = assignment_id and a.surveyor_id = (select auth.uid())
  )
);
create policy surveyor_update_own_submission on public.survey_submissions for update to authenticated
  using (captured_by = (select auth.uid()) and (select private.user_role()) = 'surveyor' and status in ('draft', 'revision_requested'))
  with check (captured_by = (select auth.uid()) and (select private.user_role()) = 'surveyor' and status in ('draft', 'revision_requested', 'submitted') and exists (
    select 1 from public.survey_assignments a where a.id = assignment_id and a.surveyor_id = (select auth.uid())
  ));
create policy supervisor_review_submission on public.survey_submissions for update to authenticated
  using ((select private.user_role()) = 'supervisor' and (select private.can_access_assignment(assignment_id)))
  with check ((select private.user_role()) = 'supervisor' and (select private.can_access_assignment(assignment_id)));
create policy items_authorized_read on public.survey_items for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy surveyor_manage_items on public.survey_items for all to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
) with check (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
);
create policy photos_authorized_read on public.survey_photos for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy surveyor_manage_photos on public.survey_photos for all to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
) with check (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
);
create policy field_responses_authorized_read on public.survey_field_responses for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy surveyor_manage_field_responses on public.survey_field_responses for all to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
) with check (
  exists (select 1 from public.survey_submissions s where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status in ('draft', 'revision_requested'))
);
create policy review_logs_authorized_read on public.review_logs for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);

create policy form_versions_authorized_read on public.survey_form_versions for select to authenticated using (
  (select private.is_admin()) or exists (
    select 1 from public.survey_assignments a where a.campaign_id = survey_form_versions.campaign_id
      and (select private.can_access_assignment(a.id))
  )
);
create policy form_versions_admin_manage on public.survey_form_versions for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy form_fields_authorized_read on public.survey_form_fields for select to authenticated using (
  exists (select 1 from public.survey_form_versions v where v.id = form_version_id
    and ((select private.is_admin()) or exists (
      select 1 from public.survey_assignments a where a.campaign_id = v.campaign_id and (select private.can_access_assignment(a.id))
    )))
);
create policy form_fields_admin_manage on public.survey_form_fields for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy form_categories_authorized_read on public.survey_form_categories for select to authenticated using (
  exists (select 1 from public.survey_form_versions v where v.id = form_version_id
    and ((select private.is_admin()) or exists (
      select 1 from public.survey_assignments a where a.campaign_id = v.campaign_id and (select private.can_access_assignment(a.id))
    )))
);
create policy form_categories_admin_manage on public.survey_form_categories for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy form_products_authorized_read on public.survey_form_products for select to authenticated using (
  exists (select 1 from public.survey_form_versions v where v.id = form_version_id
    and ((select private.is_admin()) or exists (
      select 1 from public.survey_assignments a where a.campaign_id = v.campaign_id and (select private.can_access_assignment(a.id))
    )))
);
create policy form_products_admin_manage on public.survey_form_products for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy import_jobs_admin_read on public.import_jobs for select to authenticated using ((select private.is_admin()));
create policy import_jobs_admin_write on public.import_jobs for insert to authenticated with check (
  (select private.is_admin()) and uploaded_by = (select auth.uid())
);
create policy import_jobs_admin_update on public.import_jobs for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy import_rows_admin_read on public.import_job_rows for select to authenticated using ((select private.is_admin()));
create policy import_rows_admin_insert on public.import_job_rows for insert to authenticated with check (
  (select private.is_admin()) and exists (select 1 from public.import_jobs j where j.id = import_job_id)
);
create policy import_rows_admin_update on public.import_job_rows for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy audit_logs_admin_read on public.audit_logs for select to authenticated using ((select private.is_admin()));
create policy settings_admin_manage on public.system_settings for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy submission_revisions_authorized_read on public.survey_submission_revisions for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy quality_flags_authorized_read on public.survey_quality_flags for select to authenticated using (
  exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy quality_flags_admin_update on public.survey_quality_flags for update to authenticated
  using ((select private.is_admin()) or ((select private.user_role()) = 'supervisor' and exists (
    select 1 from public.survey_submissions s where s.id = survey_quality_flags.submission_id
      and (select private.can_access_assignment(s.assignment_id))
  )))
  with check ((select private.is_admin()) or ((select private.user_role()) = 'supervisor' and exists (
    select 1 from public.survey_submissions s where s.id = submission_id and (select private.can_access_assignment(s.assignment_id))
  )));
create policy sync_receipts_authorized_read on public.survey_sync_receipts for select to authenticated using (
  (select private.is_admin()) or exists (select 1 from public.survey_submissions s where s.id = submission_id
    and (select private.can_access_assignment(s.assignment_id)))
);
create policy sync_receipts_owner_insert on public.survey_sync_receipts for insert to authenticated with check (
  actor_id = (select auth.uid()) and exists (select 1 from public.survey_submissions s
    where s.id = submission_id and s.captured_by = (select auth.uid()) and s.status = 'submitted')
);

-- Published versions and their child configuration are immutable; archive is the only allowed state change.
create or replace function private.guard_form_version_change()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.state <> 'draft' then raise exception 'Form versions must start as draft'; end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if old.state <> 'draft' then raise exception 'Only draft form versions can be deleted'; end if;
    return old;
  end if;
  if old.state = 'draft' and new.state = 'published' then
    if new.published_at is null then raise exception 'published_at is required'; end if;
    if not exists (select 1 from public.survey_form_fields f where f.form_version_id = old.id and f.visible) then
      raise exception 'A form must contain at least one visible field before publish';
    end if;
  elsif old.state = 'draft' and new.state <> 'draft' then
    raise exception 'Draft form versions can only be published';
  elsif old.state = 'published' then
    if new.state <> 'archived'
      or (to_jsonb(new) - 'state' - 'archived_at') <> (to_jsonb(old) - 'state' - 'archived_at')
      or new.archived_at is null then
      raise exception 'Published form versions are immutable; create a new version';
    end if;
  elsif old.state = 'archived' then
    raise exception 'Archived form versions are immutable';
  end if;
  return new;
end;
$$;

create or replace function private.guard_form_child_change()
returns trigger language plpgsql set search_path = ''
as $$
declare
  v_version_id uuid;
  v_state public.form_version_state;
begin
  v_version_id := case when tg_op = 'DELETE' then old.form_version_id else new.form_version_id end;
  select state into v_state from public.survey_form_versions where id = v_version_id;
  if v_state is distinct from 'draft' then
    raise exception 'Only draft form versions can be changed';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger survey_form_version_immutable before insert or update or delete on public.survey_form_versions
  for each row execute function private.guard_form_version_change();
create trigger survey_form_fields_draft_only before insert or update or delete on public.survey_form_fields
  for each row execute function private.guard_form_child_change();
create trigger survey_form_categories_draft_only before insert or update or delete on public.survey_form_categories
  for each row execute function private.guard_form_child_change();
create trigger survey_form_products_draft_only before insert or update or delete on public.survey_form_products
  for each row execute function private.guard_form_child_change();

create or replace function private.snapshot_submission_revision()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  next_revision integer;
  snapshot_data jsonb;
begin
  select coalesce(max(r.revision_number), 0) + 1 into next_revision
  from public.survey_submission_revisions r where r.submission_id = new.id;
  select jsonb_build_object(
    'submission', to_jsonb(new),
    'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.id) from public.survey_items i where i.submission_id = new.id), '[]'::jsonb),
    'field_responses', coalesce((select jsonb_agg(to_jsonb(fr) order by fr.id) from public.survey_field_responses fr where fr.submission_id = new.id), '[]'::jsonb),
    'photos', coalesce((select jsonb_agg(to_jsonb(p) order by p.id) from public.survey_photos p where p.submission_id = new.id), '[]'::jsonb)
  ) into snapshot_data;
  insert into public.survey_submission_revisions(submission_id, revision_number, actor_id, submitted_at, snapshot)
  values (new.id, next_revision, (select auth.uid()), coalesce(new.submitted_at, now()), snapshot_data);
  return new;
end;
$$;
revoke all on function private.snapshot_submission_revision() from public, anon, authenticated;
create trigger snapshot_submission_resubmission after update of status on public.survey_submissions
  for each row when (old.status is distinct from new.status and new.status = 'submitted')
  execute function private.snapshot_submission_revision();

create or replace function private.guard_assignment_conflicts()
returns trigger language plpgsql set search_path = ''
as $$
declare
  campaign public.survey_campaigns%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.outlet_id::text, 0));
  select * into campaign from public.survey_campaigns where id = new.campaign_id;
  if campaign.id is null then raise exception 'Campaign not found'; end if;
  if not campaign.allow_multiple_surveyors_per_outlet and exists (
    select 1 from public.survey_assignments a
    where a.outlet_id = new.outlet_id and a.campaign_id = new.campaign_id
      and a.surveyor_id <> new.surveyor_id and a.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) then raise exception 'This campaign allows one surveyor per outlet'; end if;
  if campaign.prevent_active_campaign_conflicts and campaign.status = 'active' and exists (
    select 1 from public.survey_assignments a
    join public.survey_campaigns other on other.id = a.campaign_id
    where a.outlet_id = new.outlet_id and a.campaign_id <> new.campaign_id
      and other.status = 'active' and other.prevent_active_campaign_conflicts
      and daterange(campaign.starts_on, campaign.ends_on, '[]') && daterange(other.starts_on, other.ends_on, '[]')
      and a.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) then raise exception 'Outlet has a conflicting active campaign assignment'; end if;
  return new;
end;
$$;
create trigger survey_assignment_conflict_guard before insert or update of campaign_id, outlet_id, surveyor_id
  on public.survey_assignments for each row execute function private.guard_assignment_conflicts();

create or replace function private.guard_submission_photo_count()
returns trigger language plpgsql set search_path = ''
as $$
declare
  photo_count integer;
begin
  perform 1 from public.survey_submissions s where s.id = new.submission_id for update;
  select count(*) into photo_count from public.survey_photos p where p.submission_id = new.submission_id;
  if tg_op = 'INSERT' and photo_count >= 3 then raise exception 'A submission can have at most three photos'; end if;
  return new;
end;
$$;
create trigger survey_photo_count_guard before insert on public.survey_photos
  for each row execute function private.guard_submission_photo_count();

create or replace function private.guard_field_response()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  response_field public.survey_form_fields%rowtype;
  response_version uuid;
  valid_value boolean;
begin
  select v.form_version_id into response_version
  from public.survey_submissions s
  join public.survey_form_versions v on v.id = s.form_version_id
  where s.id = new.submission_id and s.captured_by = (select auth.uid())
    and s.status in ('draft', 'revision_requested');
  if response_version is null then raise exception 'Submission is not editable by this user'; end if;
  select * into response_field from public.survey_form_fields f where f.id = new.field_id;
  if response_field.id is null or response_field.form_version_id <> response_version then
    raise exception 'Response field does not belong to the submission form version';
  end if;
  valid_value := case response_field.field_type
    when 'text' then jsonb_typeof(new.value) = 'string'
    when 'number' then jsonb_typeof(new.value) = 'number'
    when 'currency' then jsonb_typeof(new.value) = 'number' and (new.value #>> '{}')::numeric >= 0
    when 'select' then jsonb_typeof(new.value) = 'string' and response_field.choice_options @> jsonb_build_array(new.value)
    when 'multi_select' then jsonb_typeof(new.value) = 'array' and not exists (
      select 1 from jsonb_array_elements(new.value) chosen(v)
      where jsonb_typeof(chosen.v) <> 'string' or not (response_field.choice_options @> jsonb_build_array(chosen.v))
    )
    when 'yes_no' then jsonb_typeof(new.value) = 'boolean'
    when 'date' then jsonb_typeof(new.value) = 'string' and (new.value #>> '{}') ~ '^\d{4}-\d{2}-\d{2}$'
    when 'photo' then jsonb_typeof(new.value) = 'array'
    else false
  end;
  if not coalesce(valid_value, false) then raise exception 'Response value does not match configured field type'; end if;
  return new;
end;
$$;
revoke all on function private.guard_field_response() from public, anon, authenticated;
create trigger survey_field_response_type_guard before insert or update on public.survey_field_responses
  for each row execute function private.guard_field_response();

create or replace function private.guard_survey_item_form_scope()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  version_id uuid;
  product_category uuid;
  configured_products integer;
  configured_categories integer;
begin
  select s.form_version_id into version_id from public.survey_submissions s
  where s.id = new.submission_id and s.captured_by = (select auth.uid())
    and s.status in ('draft', 'revision_requested');
  if version_id is null then raise exception 'Submission is not editable by this user'; end if;
  select p.category_id into product_category from public.products p where p.id = new.product_id and p.active;
  if product_category is null then raise exception 'Product is missing or inactive'; end if;
  select count(*) into configured_products from public.survey_form_products fp where fp.form_version_id = version_id;
  if configured_products > 0 and not exists (
    select 1 from public.survey_form_products fp where fp.form_version_id = version_id and fp.product_id = new.product_id
  ) then raise exception 'Product is not included in the selected form version'; end if;
  select count(*) into configured_categories from public.survey_form_categories fc where fc.form_version_id = version_id;
  if configured_categories > 0 and not exists (
    select 1 from public.survey_form_categories fc where fc.form_version_id = version_id and fc.category_id = product_category
  ) then raise exception 'Product category is not included in the selected form version'; end if;
  return new;
end;
$$;
revoke all on function private.guard_survey_item_form_scope() from public, anon, authenticated;
create trigger survey_item_form_scope_guard before insert or update on public.survey_items
  for each row execute function private.guard_survey_item_form_scope();

create or replace function private.guard_submission_state_transition()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  assigned_campaign uuid;
  assigned_surveyor uuid;
  campaign public.survey_campaigns%rowtype;
  form_version public.survey_form_versions%rowtype;
  required_photos integer;
  photo_count integer;
begin
  if new.id <> old.id or new.assignment_id <> old.assignment_id or new.captured_by <> old.captured_by then
    raise exception 'Submission identity and assignment cannot be changed';
  end if;
  if old.form_version_id is not null and new.form_version_id is distinct from old.form_version_id then
    raise exception 'A submission keeps the form version selected at creation';
  end if;
  new.updated_at := now();
  if new.status = old.status then
    if (select private.user_role()) = 'supervisor'
      and (to_jsonb(new) - 'updated_at') <> (to_jsonb(old) - 'updated_at') then
      raise exception 'Supervisor review updates must change the workflow status only';
    end if;
    if (select private.user_role()) = 'surveyor'
      and (new.submitted_at is distinct from old.submitted_at or new.review_note is distinct from old.review_note) then
      raise exception 'Surveyors cannot edit submission or review metadata directly';
    end if;
    return new;
  end if;

  if old.status in ('draft', 'revision_requested') and new.status = 'submitted' then
    if (select private.user_role()) is distinct from 'surveyor' or new.captured_by <> (select auth.uid()) then
      raise exception 'Only the assigned surveyor can submit this survey';
    end if;
    select a.campaign_id, a.surveyor_id into assigned_campaign, assigned_surveyor
    from public.survey_assignments a where a.id = new.assignment_id;
    if assigned_campaign is null or assigned_surveyor <> (select auth.uid()) then
      raise exception 'Survey assignment is not available to this user';
    end if;
    select * into campaign from public.survey_campaigns c where c.id = assigned_campaign;
    if campaign.status <> 'active' or new.captured_at is null
      or new.captured_at::date not between campaign.starts_on and campaign.ends_on then
      raise exception 'Survey capture must be within an active campaign date range';
    end if;
    select * into form_version from public.survey_form_versions v where v.id = new.form_version_id;
    if form_version.id is null or form_version.campaign_id <> assigned_campaign or form_version.state <> 'published' then
      raise exception 'Submission must retain the published form version for its campaign';
    end if;
    if exists (
      select 1 from public.survey_form_fields f
      where f.form_version_id = form_version.id and f.visible and f.required
        and (f.visibility_condition is null or exists (
          select 1 from public.survey_field_responses condition_response
          join public.survey_form_fields condition_field on condition_field.id = condition_response.field_id
          where condition_response.submission_id = new.id
            and condition_field.field_key = f.visibility_condition ->> 'field_key'
            and condition_response.value = f.visibility_condition -> 'equals'
        ))
        and not exists (select 1 from public.survey_field_responses answer
          where answer.submission_id = new.id and answer.field_id = f.id)
    ) then raise exception 'Required form fields are incomplete'; end if;
    if exists (
      select 1 from public.survey_form_products fp
      where fp.form_version_id = form_version.id and not exists (
        select 1 from public.survey_items si where si.submission_id = new.id and si.product_id = fp.product_id
      )
    ) then raise exception 'Every configured SKU must have an observation'; end if;
    select form_version.photo_required_count into required_photos;
    if campaign.completion_requires_photo then required_photos := greatest(required_photos, 1); end if;
    select count(*) into photo_count from public.survey_photos p
      where p.submission_id = new.id and p.uploaded_at is not null;
    if photo_count < required_photos then raise exception 'Required evidence photos have not been uploaded'; end if;
    new.submitted_at := now();
    new.review_note := old.review_note;
    update public.survey_assignments set status = 'submitted' where id = new.assignment_id;
    return new;
  end if;

  if (old.status = 'submitted' and new.status = 'in_review') or
     (old.status = 'in_review' and new.status in ('approved', 'revision_requested')) then
    if (select private.user_role()) is distinct from 'supervisor'
      or not (select private.can_access_assignment(new.assignment_id)) then
      raise exception 'Only an authorized supervisor can review this survey';
    end if;
    if (to_jsonb(new) - 'status' - 'review_note' - 'updated_at') <>
       (to_jsonb(old) - 'status' - 'review_note' - 'updated_at') then
      raise exception 'Review actions cannot edit captured survey data';
    end if;
    if new.status = 'revision_requested' and nullif(trim(new.review_note), '') is null then
      raise exception 'A revision request requires a review note';
    end if;
    insert into public.review_logs(submission_id, reviewer_id, action, note)
    values (new.id, (select auth.uid()), new.status::text, new.review_note);
    update public.survey_assignments set status = new.status::text::public.assignment_status where id = new.assignment_id;
    return new;
  end if;

  raise exception 'Invalid submission status transition';
end;
$$;
revoke all on function private.guard_submission_state_transition() from public, anon, authenticated;
create trigger survey_submission_state_guard before update on public.survey_submissions
  for each row execute function private.guard_submission_state_transition();

create or replace function private.flag_submission_price_anomalies()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.survey_quality_flags(submission_id, rule_code, severity, description)
  select new.id, 'PRICE_OUTLIER:' || si.product_id::text, 'warning', 'Harga berada di luar rentang awal dan perlu diperiksa.'
  from public.survey_items si where si.submission_id = new.id and si.price_review_required
  on conflict (submission_id, rule_code) do update
    set severity = excluded.severity, description = excluded.description, resolved_at = null, resolved_by = null;
  return new;
end;
$$;
revoke all on function private.flag_submission_price_anomalies() from public, anon, authenticated;
create trigger flag_submission_anomalies after update of status on public.survey_submissions
  for each row when (old.status is distinct from new.status and new.status = 'submitted')
  execute function private.flag_submission_price_anomalies();

-- Append-only, changed-field-only audit trail. Raw row contents are not copied into the log.
create or replace function private.audit_row_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  old_row jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  new_row jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  changed text[];
  row_id text;
begin
  select coalesce(array_agg(k order by k), '{}') into changed
  from jsonb_object_keys(old_row || new_row) as keys(k)
  where old_row -> k is distinct from new_row -> k
    and k not in ('created_at', 'updated_at', 'last_seen_at');
  row_id := coalesce(new_row ->> 'id', old_row ->> 'id',
    concat_ws(':', coalesce(new_row ->> 'profile_id', old_row ->> 'profile_id'),
      coalesce(new_row ->> 'territory_id', old_row ->> 'territory_id'),
      coalesce(new_row ->> 'campaign_id', old_row ->> 'campaign_id')));
  insert into public.audit_logs(actor_id, action, entity, entity_id, changed_fields)
  values ((select auth.uid()), lower(tg_op), tg_table_name, row_id, changed);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.audit_row_change() from public, anon, authenticated;

create trigger audit_profiles after insert or update or delete on public.profiles
  for each row execute function private.audit_row_change();
create trigger audit_profile_territories after insert or update or delete on public.profile_territories
  for each row execute function private.audit_row_change();
create trigger audit_profile_campaign_access after insert or update or delete on public.profile_campaign_access
  for each row execute function private.audit_row_change();
create trigger audit_territories after insert or update or delete on public.territories
  for each row execute function private.audit_row_change();
create trigger audit_outlets after insert or update or delete on public.outlets
  for each row execute function private.audit_row_change();
create trigger audit_channels after insert or update or delete on public.channels
  for each row execute function private.audit_row_change();
create trigger audit_categories after insert or update or delete on public.categories
  for each row execute function private.audit_row_change();
create trigger audit_brands after insert or update or delete on public.brands
  for each row execute function private.audit_row_change();
create trigger audit_products after insert or update or delete on public.products
  for each row execute function private.audit_row_change();
create trigger audit_campaigns after insert or update or delete on public.survey_campaigns
  for each row execute function private.audit_row_change();
create trigger audit_assignments after insert or update or delete on public.survey_assignments
  for each row execute function private.audit_row_change();
create trigger audit_form_versions after insert or update or delete on public.survey_form_versions
  for each row execute function private.audit_row_change();
create trigger audit_form_fields after insert or update or delete on public.survey_form_fields
  for each row execute function private.audit_row_change();
create trigger audit_form_categories after insert or update or delete on public.survey_form_categories
  for each row execute function private.audit_row_change();
create trigger audit_form_products after insert or update or delete on public.survey_form_products
  for each row execute function private.audit_row_change();
create trigger audit_system_settings after insert or update or delete on public.system_settings
  for each row execute function private.audit_row_change();
create trigger audit_import_jobs after insert or update on public.import_jobs
  for each row execute function private.audit_row_change();
