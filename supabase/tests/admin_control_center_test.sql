BEGIN;
SELECT plan(12);

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT has_table('public', 'import_jobs', 'import history table exists');
SELECT has_table('public', 'survey_form_versions', 'versioned form table exists');
SELECT has_table('public', 'survey_submission_revisions', 'resubmission snapshots exist');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.import_jobs'::regclass), 'import jobs have RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.survey_field_responses'::regclass), 'dynamic responses have RLS enabled');
SELECT ok(to_regprocedure('public.is_admin()') IS NULL, 'legacy public security helper was removed');

INSERT INTO auth.users (id, email) VALUES
  ('90000000-0000-4000-8000-000000000001', 'admin-test@example.invalid'),
  ('90000000-0000-4000-8000-000000000002', 'surveyor-one@example.invalid'),
  ('90000000-0000-4000-8000-000000000003', 'surveyor-two@example.invalid');
INSERT INTO public.profiles (id, display_name, role) VALUES
  ('90000000-0000-4000-8000-000000000001', 'Test Admin', 'admin'),
  ('90000000-0000-4000-8000-000000000002', 'Test Surveyor One', 'surveyor'),
  ('90000000-0000-4000-8000-000000000003', 'Test Surveyor Two', 'surveyor');

INSERT INTO public.territories (id, name, kind, parent_id) VALUES
  ('91000000-0000-4000-8000-000000000001', 'Test Region', 'region', null),
  ('91000000-0000-4000-8000-000000000002', 'Test Depot', 'depot', '91000000-0000-4000-8000-000000000001'),
  ('91000000-0000-4000-8000-000000000003', 'Test Kecamatan', 'kecamatan', '91000000-0000-4000-8000-000000000002');
INSERT INTO public.channels (id, name) VALUES ('92000000-0000-4000-8000-000000000001', 'Test Channel');
INSERT INTO public.outlets (id, code, name, territory_id, channel_id) VALUES
  ('93000000-0000-4000-8000-000000000001', 'TEST-OUTLET-1', 'Test Outlet One', '91000000-0000-4000-8000-000000000003', '92000000-0000-4000-8000-000000000001'),
  ('93000000-0000-4000-8000-000000000002', 'TEST-OUTLET-2', 'Test Outlet Two', '91000000-0000-4000-8000-000000000003', '92000000-0000-4000-8000-000000000001');
INSERT INTO public.survey_campaigns (id, name, starts_on, ends_on, created_by) VALUES
  ('94000000-0000-4000-8000-000000000001', 'Test Campaign', current_date, current_date + 7, '90000000-0000-4000-8000-000000000001');
INSERT INTO public.survey_assignments (id, campaign_id, outlet_id, surveyor_id, assigned_by) VALUES
  ('95000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000001'),
  ('95000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000003', '90000000-0000-4000-8000-000000000001');
INSERT INTO public.survey_submissions (id, assignment_id, captured_by) VALUES
  ('96000000-0000-4000-8000-000000000001', '95000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002');
INSERT INTO public.import_jobs (id, kind, source_filename, uploaded_by) VALUES
  ('97000000-0000-4000-8000-000000000001', 'outlet_master', 'test.csv', '90000000-0000-4000-8000-000000000001');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '90000000-0000-4000-8000-000000000002';
SELECT is((SELECT count(*)::integer FROM public.outlets), 1, 'surveyor sees only assigned outlet');
SELECT is((SELECT count(*)::integer FROM public.import_jobs), 0, 'surveyor cannot read admin import history');
SELECT is((SELECT count(*)::integer FROM public.survey_submissions), 1, 'surveyor sees own submission');

SET LOCAL request.jwt.claim.sub = '90000000-0000-4000-8000-000000000003';
SELECT is((SELECT count(*)::integer FROM public.survey_submissions), 0, 'other surveyor cannot read submission');
SELECT is((SELECT count(*)::integer FROM public.survey_assignments WHERE id = '95000000-0000-4000-8000-000000000001'), 0, 'other surveyor cannot read assignment');
RESET ROLE;

INSERT INTO public.survey_form_versions (id, campaign_id, version_number, name, created_by)
VALUES ('98000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001', 1, 'Test Form', '90000000-0000-4000-8000-000000000001');
INSERT INTO public.survey_form_fields (form_version_id, section_key, field_key, label, field_type, sort_order)
VALUES ('98000000-0000-4000-8000-000000000001', 'products', 'availability', 'Availability', 'yes_no', 1);
UPDATE public.survey_form_versions SET state = 'published', published_at = now()
WHERE id = '98000000-0000-4000-8000-000000000001';
SELECT throws_ok(
  $$UPDATE public.survey_form_fields SET label = 'Changed' WHERE form_version_id = '98000000-0000-4000-8000-000000000001'$$,
  'P0001', 'Only draft form versions can be changed', 'published form fields are immutable'
);

SELECT * FROM finish();
ROLLBACK;
