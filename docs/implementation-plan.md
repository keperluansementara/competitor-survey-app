# Implementation plan — Competitor Survey & Market Intelligence

## Repository assessment

- Starting state: empty directory; no existing application or `AGENTS.md` found.
- Foundation prepared: Vite/React/TypeScript/Tailwind/PWA scaffold, base schema, synthetic seed, survey wireframe, and responsive Admin shell with a Supabase-backed dashboard.
- Current increment covers Admin architecture, additive database model/security policies, and a dashboard shell. Master-data CRUD/import, campaign/form management, role-specific workflows, and offline sync remain future increments.

## Proposed phased delivery

1. **Admin data model (prepared, not applied):** import history/rollback snapshots, hierarchical master data, form versioning, audit history, and scoped RLS in a local migration.
2. **App shell and identity (partial):** sign-in, role-aware navigation, and Admin dashboard with metrics queried from Supabase only; profile bootstrap and functional non-admin views remain open.
3. **Master data and imports:** CRUD/deactivation, downloadable CSV/XLSX templates, preview/validation, separate outlet and assignment imports, safe rollback.
4. **Campaigns and forms:** lifecycle, bulk assignments, survey form builder, preview, validation, immutable published versions.
5. **Survey capture and sync:** dynamic mobile form, IndexedDB outbox, photos, idempotent sync, conflict handling and status visibility.
6. **Review, quality and reports:** supervisor workflow, anomaly flags, filters, authorized exports, audit history.
7. **Hardening and pilot:** database policy tests, mobile browser verification, accessibility, sync failure/retry scenarios, deployment documentation; no production deployment without explicit approval.

## Architecture decisions

- SPA: React + Vite + TypeScript; Tailwind CSS and Lucide React. Responsive layouts share the same app, with surveyor-first mobile navigation and denser supervisor/analyst desktop views.
- Supabase is the system of record: PostgreSQL constraints and RLS enforce permissions; Auth identifies users; Storage holds private evidence. Frontend role checks improve navigation only and are never treated as authorization.
- IndexedDB stores drafts and an outbox on-device. Every submission gets a client-generated UUID as an idempotency key. The client only removes an outbox record after the server confirms the matching submission. Photos are queued as blobs with a documented size cap and resumable state.
- Keep observed, estimated, and actual-sales measures distinct. MVP capture is observational; estimates and actual sales are represented separately and not inferred from missing observation values.
- Region/depo/kecamatan are represented as a territory hierarchy; each outlet is linked to a territory node and channel. Assignments are campaign/outlet/surveyor scoped.
- Review is append-only in `review_logs`; submission status is a current-state convenience. Returning a survey requests revision and preserves the prior review trail.
- Private photos use opaque storage paths and short-lived signed URLs, with authorization checked before issuing access. No public bucket.
- Published forms are immutable versions referenced by each submission; running campaigns take changes only through a new version.
- Import jobs separate outlet master data from campaign assignments. Preview rows retain validation results and before-values so rollback can reject conflicts instead of overwriting later edits.
- Audit history records actor, entity, action, timestamp, and changed-field summaries. Sensitive data is not copied wholesale into audit records.
- Pilot data is synthetic. Admin dashboard numbers remain unavailable/empty until Supabase is configured and a signed-in user can query authorized rows.
- SQL migrations are the source of truth. Seed data is synthetic and development-only. `profiles` references `auth.users`; account creation/invitation remains an admin/bootstrap concern.

## Initial schema map

Base tables are defined in `supabase/migrations/202610210001_initial_schema.sql`. Admin extensions and ERD are in `docs/database-erd.md` and the generated migration `supabase/migrations/20261021153722_admin_control_center.sql`.

## Decisions and risks to resolve before pilot

1. **Territory ownership:** grants are explicit territory nodes. Confirm whether a grant on a region/depo should include descendants; current access model intentionally does not infer descendants.
2. **Revision behavior:** confirm whether a returned submission is edited in place or a new revision is created. Current draft keeps the submission identity and records review history; item-level snapshots/revision tables may be needed for immutable history.
3. **Offline photo limits:** initial policy is at most three images per submission, 10 MB each, JPEG/PNG/WebP. Confirm retention for failed uploads. Browser storage quota is device-dependent; local encryption is not provided by IndexedDB.
4. **GPS and privacy:** define consent wording, precision/retention, and whether coordinates are required or optional. Schema permits absent coordinates.
5. **Actual sales and estimation:** define the source/owner for actual-sales data and estimation methodology; the MVP schema keeps them separate from field observations.
6. **Admin bootstrap:** decide how the first admin is provisioned and whether role/territory changes require dual approval. Users must not be able to self-assign privileged roles.
7. **Campaign scale and export:** expected survey volume and export size may require server-side pagination/background exports instead of browser CSV generation.

## Acceptance checkpoints

- This foundation is reviewable before workflow implementation.
- Later phase gates include database policy tests, idempotent sync tests, browser/mobile usability checks, lint, type-check, test, and production build. No check is reported as passed unless run.
- Production deployment, destructive data changes, and real customer data are out of scope for development work without explicit approval.

## Current verification

- `npm install`: completed; npm reported 0 vulnerabilities (dependency deprecation notices were printed during install).
- Frontend checks have passed at the previous checkpoint; rerun before treating the current working tree as verified.
- The pgTAP test file exists but has not run. Docker is unavailable in this environment, so `supabase test db --local` cannot reach the local database.
- The Admin migration has not been applied to any Supabase/PostgreSQL instance. SQL correctness and RLS behavior are therefore unverified.

## Addendum security notes

- Supabase CLI was run via `npx`; installed CLI version was 2.121.0. The CLI is not a project dependency.
- Supabase's current docs distinguish table grants from RLS policies. New migration explicitly scopes grants/policies; actual Data API exposure must still be configured and checked in the target development project.
- Private helper functions belong in a non-exposed schema and are granted only to `authenticated`; Storage stays private and uses object-level policies.
- Never put service-role credentials in frontend environment variables.
- Supabase authorization has both explicit table grants and RLS policies. New-project Data API exposure defaults can vary by project settings, so review API exposure alongside grants/policies in the target development project. See [RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security) and [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
