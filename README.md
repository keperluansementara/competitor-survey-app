# Competitor Survey & Market Intelligence

Mobile-first web app for collecting product and competitor observations at outlets. The current increment provides a responsive Admin shell and dashboard that reads real Supabase data when configured. The other Admin modules and survey/review flows are still being built; their navigation is marked as coming in later increments.

## Stack

- React, Vite, TypeScript, Tailwind CSS, Lucide React
- Supabase Auth, PostgreSQL with RLS, and private Storage
- Vite PWA support

## Repository map

- `src/` — app shell, dashboard, Supabase client, and survey wireframe
- `docs/implementation-plan.md` — phased plan, architecture decisions, and known risks
- `docs/database-erd.md` — database relationship diagram
- `supabase/migrations/` — initial schema and Admin Control Center extension (not yet applied)
- `supabase/seed/dev.sql` — synthetic development records only
- `supabase/tests/admin_control_center_test.sql` — pgTAP policy/schema checks
- `public/templates/` — header-only CSV import templates

## Local development

Requires Node.js 22.12 or newer. Copy `.env.example` to `.env.local` and set the local Supabase URL and publishable key. Never place a service-role key in frontend environment variables.

```sh
npm install
npx supabase start
npx supabase db reset
npm run dev
```

`db reset` applies local migrations and synthetic seed data. Supabase local development requires Docker. Auth users are not seeded; the first development admin must be provisioned in local Auth and linked to a `public.profiles` row with role `admin`. Role assignment is a trusted setup operation, never a self-service UI action.

Without `.env.local`, the app shows a setup state instead of sample metrics. No production project or real outlet/customer data is included.

## Checks

```sh
npm run lint
npm run typecheck
npm test
npm run build
npx supabase test db --local
```

Frontend checks run without Supabase. SQL tests require a running local Supabase stack and Docker. Report each check only after it has actually run.

## Deployment

Deployment is not part of the current increment. Before a pilot, configure a dedicated development/staging Supabase project, apply reviewed migrations, verify RLS and Storage access, add approved Auth users, and set `VITE_SUPABASE_URL` plus `VITE_SUPABASE_PUBLISHABLE_KEY` in the hosting environment. Production deployment and production data changes require explicit approval.
