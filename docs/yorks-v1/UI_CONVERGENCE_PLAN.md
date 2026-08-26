# Yorks V1 — UI Convergence Plan

Status: **Batch 11A complete; Batch 11B in progress.** The normalized
portfolio foundation is complete. This is an incremental visual-convergence
track on top of the completed V1 security/workflow batches; it does not replace
the release-readiness work in Batch 10.

## Authority and delivery boundary

- Rev 2.0 is the behavior authority, `PRODUCT_DECISIONS.md` is the frozen
  transaction/security authority, and R35 is the visual/interaction authority.
- The R35 HTML is not a runtime dependency. Its localStorage auth, client-only
  permissions, stock and audit behavior remain intentionally excluded.
- Supabase/Postgres continues to be the authority for committed records and
  commands. Existing Riverpod repositories/controllers retain the only UI
  command paths.
- Recoverable draft input continues to use the existing versioned
  `SharedPreferences`/`CollectionStore` implementation. It works on Android
  and Web and is deliberately not SQLite, which would create a second web
  persistence path. A draft is never displayed as server-confirmed work.

## Batch 11 slices

| Slice | Scope | Acceptance evidence |
| --- | --- | --- |
| 11A | R35 auth surface; Yorks desktop sidebar/top bar; mobile operational navigation around existing V1 screens | **Complete.** Login and role shell at 1366x768 and 360px; all existing V1 route/role guards unchanged |
| 11B | Portfolio/read-only project context, five-stage creation, project workspace, BOQ group and worksheet visual alignment | **In progress.** RLS-backed portfolio and four-tab project workspace are complete; the existing five-stage creation and BOQ flows remain connected. Role visual regression continues with the remaining workspace refinements. |
| 11C | Material Request list/draft/detail plus Procurement arrangement and Engineer approval alignment | Draft privacy, commercial allowed/denied, partial/unavailable and return-reason states |
| 11D | Inventory, dispatch/receipt, delivery order and return workspace alignment | Desktop table/mobile editor; required reference/outcome and server rejection states |
| 11E | Documents, retained administration and engineering tools; loading/error/offline/forbidden presentation | Controlled print/document evidence and accessible responsive review |
| 11F | Client demonstration seed/runbook and final visual regression evidence | Four-role demo script on Web and Android against an approved environment |

## Intentional integration boundaries

The original prototype contains overlapping or deferred routes that must not be
silently recreated beside V1 authority:

- RFQ, quotations and PO remain unavailable in V1. The later approved R39
  Accounts module is a separate normalized T01–T07 rollout; it stays
  unreachable behind default-off `YORKS_V1_ACCOUNTS` during T01 and never
  revives legacy `/admin/finance`.
- Dispatch and return navigation starts from an authorised Material Request;
  global list surfaces are introduced only with a safe server projection.
- The normalized project portfolio now uses an explicitly non-commercial read
  model over `v1_projects`, `v1_project_parties`, `v1_project_scopes` and
  `v1_project_members`. Each relation is already protected by the existing
  `v1_project_readable` RLS predicate; this deliberately avoids a broad legacy
  project-register fallback. Procurement has the same read model with a
  visible View Only affordance and no project/BOQ command path.
- The project workspace currently provides Overview, BOQ, Material Requests
  and Documents. BOQ and Documents open the selected project's connected
  record; Material Requests opens the role-authorized request workspace while
  its project-scoped list filter is completed in Slice 11C. R39 T05 may add a
  normalized, capability-guarded Accounts entry after its server phases pass;
  that later work does not change this historical Slice 11 baseline.

Every convergence slice preserves the existing positive/negative RLS tests;
UI visibility is never treated as authorization.
