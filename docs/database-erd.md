# Database ERD — Admin Control Center

```mermaid
erDiagram
  PROFILES ||--o{ PROFILE_TERRITORIES : scoped_to
  PROFILES ||--o{ PROFILE_CAMPAIGN_ACCESS : authorized_for
  TERRITORIES ||--o{ TERRITORIES : parent_of
  TERRITORIES ||--o{ OUTLETS : contains
  CHANNELS ||--o{ OUTLETS : classifies
  CATEGORIES ||--o{ PRODUCTS : groups
  BRANDS ||--o{ PRODUCTS : owns
  UNITS ||--o{ PRODUCTS : measures
  SURVEY_CAMPAIGNS ||--o{ SURVEY_ASSIGNMENTS : targets
  OUTLETS ||--o{ SURVEY_ASSIGNMENTS : visited
  PROFILES ||--o{ SURVEY_ASSIGNMENTS : assigned_to
  SURVEY_CAMPAIGNS ||--o{ SURVEY_FORM_VERSIONS : configures
  SURVEY_CAMPAIGNS ||--o{ PROFILE_CAMPAIGN_ACCESS : scoped_access
  SURVEY_FORM_VERSIONS ||--o{ SURVEY_FORM_FIELDS : contains
  SURVEY_FORM_VERSIONS ||--o{ SURVEY_FORM_CATEGORIES : includes
  SURVEY_FORM_VERSIONS ||--o{ SURVEY_FORM_PRODUCTS : includes
  SURVEY_FORM_VERSIONS ||--o{ SURVEY_SUBMISSIONS : captured_with
  SURVEY_ASSIGNMENTS ||--o{ SURVEY_SUBMISSIONS : produces
  SURVEY_SUBMISSIONS ||--o{ SURVEY_ITEMS : observes
  SURVEY_SUBMISSIONS ||--o{ SURVEY_FIELD_RESPONSES : answers
  SURVEY_SUBMISSIONS ||--o{ SURVEY_PHOTOS : proves
  SURVEY_SUBMISSIONS ||--o{ REVIEW_LOGS : reviewed
  SURVEY_SUBMISSIONS ||--o{ SURVEY_SUBMISSION_REVISIONS : snapshots
  SURVEY_SUBMISSIONS ||--o{ SURVEY_QUALITY_FLAGS : flags
  SURVEY_SUBMISSIONS ||--o| SURVEY_SYNC_RECEIPTS : syncs
  PROFILES ||--o{ REVIEW_LOGS : reviews
  PROFILES ||--o{ IMPORT_JOBS : uploads
  IMPORT_JOBS ||--o{ IMPORT_JOB_ROWS : previews
  PROFILES ||--o{ AUDIT_LOGS : acts
```

All master data is deactivated rather than deleted when referenced. Form versions retain their own field/category/product configuration; published versions cannot be edited, and submissions retain the version used at capture. Imports use separate job types for outlet masters and campaign assignments, and each row keeps preview results and prior values needed for a guarded rollback. Admin metrics are derived from RLS-filtered database counts; there are no hardcoded metric values.

The hierarchy and pilot seed use synthetic records only. Region/depo/kecamatan/kelurahan remain a parent-child territory tree; outlet assignment imports and outlet-master imports are separate jobs. `survey_submission_revisions` snapshots each resubmission so corrections retain the previous raw observation. `survey_sync_receipts` record successful server receipt only; unsynchronized device outboxes are not visible to the server.
