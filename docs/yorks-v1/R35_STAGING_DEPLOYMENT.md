# Yorks V1 R35 — Dedicated Staging Deployment and Document Witness

Status: **prepared; awaiting a release-owner-created staging project.**

This procedure is intentionally separate from the historic shared remote
project. It applies every tracked migration to an empty staging project, then
deploys the JWT-protected `finalize-document-upload` Edge Function. It does not
modify production or use a browser/service-role fallback.

## Target contract

- Create an empty project named `yorks-r35-staging` in the approved Supabase
  organization and Frankfurt region (`eu-central-1`) unless the release owner
  selects another supported region.
- Record its project ref, HTTPS URL, publishable key and database password in
  an ignored `.r35.staging.env` copied from
  [`../../tool/r35.staging.env.example`](../../tool/r35.staging.env.example).
- Do not use `czykuksmlwswjsgotrpo`: it is the historic shared project and is
  deliberately rejected by `tool/r35-staging.sh`.
- The Edge runtime receives `SUPABASE_SERVICE_ROLE_KEY` only from Supabase's
  protected function environment. It is never copied into the Flutter build,
  the config file, logs or this repository.

## Deploy and schema proof

```bash
R35_STAGING_CONFIG_FILE=.r35.staging.env ./tool/r35-staging.sh preflight
R35_STAGING_CONFIG_FILE=.r35.staging.env ./tool/r35-staging.sh deploy
```

The deployment is accepted only when `verify` shows:

1. every tracked migration through
   `20260803224536_yorks_v1_p0_boq_document_delivery_order`;
2. `header_hierarchy_supported = true` for
   `v1_import_boq_worksheet(jsonb, uuid)`;
3. a deployed `finalize-document-upload` function with JWT verification still
   enabled; and
4. no migration is pushed to or function is deployed on the historic shared
   project.

`preflight` also runs `supabase db push --dry-run`. A real `deploy` requires
the explicit confirmation value
`R35_STAGING_DEPLOY_CONFIRM=<the-dedicated-staging-project-ref>` in the
ignored staging configuration. This prevents a linked-project command from
being treated as a harmless inspection.

Run the complete staging database suite only after deployment against this
dedicated non-production target:

```bash
npx supabase test db --linked
```

The tests are transaction-scoped, but they still require a dedicated staging
project and named non-production personas. Do not point them at production.

## Required controlled-document witness

Use an assigned Project Engineer and a new staging project created through the
R35 project flow. Record the request IDs, document/version UUIDs, UTC times,
browser screenshots and the downloaded byte hashes in the release evidence
folder.

1. Upload a small operational PDF or PNG as a project document. Confirm the
   client receives a scoped intent, Storage accepts only the assigned object
   path and `finalize-document-upload` returns document revision `1`.
2. Download the document as the assigned Project Engineer and Site Engineer.
   Confirm the bytes hash to the uploaded SHA-256. Confirm an unrelated
   Engineer cannot list or download it.
3. Choose **Replace version** for the same document, upload different bytes,
   then finalise. Confirm it returns the same document ID, revision `2`, a new
   version ID, and the document now points at revision `2`.
4. Confirm both version rows remain immutable, there is still one current link
   for the project target, and audit contains `document_version_created` then
   `document_version_superseded`.
5. Retry the finalizer once for each intent and confirm it returns the original
   result without adding a version, link or audit event.

The local pgTAP replacement regression in
`supabase/tests/database/yorks_v1_batch9_documents_audit.test.sql` proves the
database half of steps 3–5. The live witness is still required because it also
proves Edge byte hashing, Storage download and function deployment.

## Rollback

This is the complete-R35-only release strategy. Rollback is deployment-level:
redeploy the prior approved app/function version and stop new staging traffic.
Do not delete committed document versions, links, audit events or additive
schema. If a staging test requires cleanup, create new test records or reset
the dedicated staging project; never “clean” production data.
