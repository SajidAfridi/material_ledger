# Yorks AC. & Ref. V1 R35 — Batch 9 Completion

Status: **passed** on 2 August 2026.

## Delivered

- Private `yorks-documents` Storage with server-issued, fifteen-minute upload
  intents. The app can write only to the exact intent path; the Edge Function
  re-downloads the object, verifies byte count and SHA-256, then calls the
  service-only finalizer.
- Immutable document roots, append-only versions and classified links for
  Projects, BOQ groups, Material Requests, Dispatches, Material Returns and
  Delivery Orders. Versions record file name, MIME type, byte size, hash,
  uploader, role, timestamp, source record and source revision.
- A strict multi-link read rule: a reader must be authorized for *every*
  current link and then meet the document classification. Commercial documents
  need `view_commercials`; Admin-restricted documents need Admin. Storage paths
  alone convey no access.
- New project, BOQ, Material Request, Delivery Order and Material Return
  document entry points. MR/DO/Return PDFs can be stored as controlled,
  generated versions tied to the source revision. The workspace supports
  upload, download, immutable replacement versions, contextual linking and a
  safe server-generated activity view.
- Safe audit projections deliberately omit before/after payloads. New document
  commands append exactly one event; existing V1 critical commands retain their
  existing server-side audit events.
- The legacy Accounts deep link is closed once Yorks V1 is active. Legacy
  Material Plan/Procurement/dispatch routes remain closed by the existing V1
  boundary. Rentals, User Management, configuration/profile and Audit receive
  smoke coverage.
- Retained reference-only Duct Sizer and ESP Calculator routes. They use the
  R35 formulas locally, display a non-authoritative warning and do not write
  project, BOQ, stock, commercial or approval data.

## Migration and rollback

`20260802060000_yorks_v1_batch9_documents_audit.sql` is additive and
idempotent. It creates a private bucket, document/version/link/intent tables,
RLS, Storage policies, immutable triggers, role-safe RPCs and audit
projections. Disable `YORKS_V1_DOCUMENTS` to remove the new UI and routes; do
not delete created objects, versions, links or audit events. Correct a document
through a new version or an audited link removal with a reason.

## Verification

- `supabase db reset` applied all migrations cleanly.
- The Batch 9 pgTAP suite proves four-role Storage access, intent-scoped paths,
  client finalizer denial, immutable versioning, idempotent finalization,
  classification boundaries, cross-project Admin/reason requirements, strict
  every-link access, auditable soft removal and a safe audit envelope.
- The complete database suite passed: 12 files / 351 tests.
- Flutter analysis and the complete Flutter suite passed: 448 tests. The
  retained User Management, configuration/profile, Audit and Rentals screens
  are included in smoke coverage.
- Release web and Android APK builds succeeded with CI placeholder Supabase
  settings. Calculator formula tests and the deferred-Accounts route guard are
  included in the Flutter suite.

## Known limitation

The local command-line environment does not include Deno, so the Edge Function
formatter could not be run here. The function is covered by the database
contract it invokes, while a live signed-in upload/download walkthrough with a
configured Supabase Edge Function remains a Batch 10 staging validation item.
