# Yorks V1 R35 — Current-to-Target Gap Analysis

Audit date: 1 August 2026
Audited branch: `agent/nexus-v7-implementation`
Audit type: read-only product/code/schema review before Batch 0 documentation

> **HISTORICAL BASELINE — NOT CURRENT BUILD CONFIGURATION.** This 1 August
> audit explains the original migration strategy and may refer to default-off
> slices. For the accepted operational configuration, use `README.md`,
> `TERRA.md` and `BATCH_10_RELEASE_READINESS.md`.

## 1. Executive conclusion

The repository is a healthy Flutter foundation and should not be rewritten.
Its V7 operational workflow, three-role model and generic JSON persistence are
not safe foundations for small state tweaks, however. Yorks V1 needs a new
normalized Postgres domain and trusted RPC layer while selectively reusing the
existing UI, sync, security and compatibility mechanics.

The implementation strategy is additive coexistence:

- keep unrelated modules and legacy decoders working;
- add normalized V1 schema/repositories behind guarded rollout flags;
- adapt proven widgets to V1 contracts;
- migrate/reconcile data explicitly;
- switch routes only after role/RLS and acceptance gates pass;
- preserve old V7 records as historical evidence until controlled retirement.

## 2. Verified baseline

At re-baseline, the worktree was clean and the existing application passed:

- `flutter analyze` — no issues;
- `flutter test` — 352 tests passed;
- Flutter web release build with non-secret CI Supabase placeholders;
- Flutter Android release APK assembly with the same placeholders.

The Android result is a mechanical build, not a production release: the main
manifest lacks Internet permission and release signing falls back to a debug
key when no keystore is present.

## 3. Reusable foundation

| Current evidence | What is reusable | Required V1 adaptation |
|---|---|---|
| `lib/main.dart`, `lib/shared/sync/supabase_bootstrap.dart` | Supabase initialization and fail-closed release configuration | Preserve; extend tracked local/staging setup |
| `lib/shared/providers/session_provider.dart` | Exact `app_metadata` role extraction and stable user ID seam | Add four-role vocabulary; fail closed on legacy/unknown role |
| `lib/app/router.dart` | GoRouter tree, transition helpers and route tests | Replace three-role/path-default assumptions with membership-aware guards |
| `lib/core/constants/`, `lib/core/widgets/` | Palette, spacing, typography, bilingual, status/current-action/audit primitives | Align final R35 shell and complete accessibility |
| `lib/core/widgets/nexus_page_shell.dart`, `lib/app/app_shell.dart`, `lib/app/engineer_shell.dart` | Responsive shell and navigation structure | Four role-specific V1 navigation maps |
| `lib/shared/widgets/material_line_grid.dart` | Virtualized desktop rows, synchronized scrolling, keyboard traversal, TSV paste | Bind mechanics to dynamic BOQ schema and R35 presentation |
| `lib/shared/controllers/material_line_grid_controller.dart` | Undo/redo, focus, row editing, autosave seam | Insert-below semantics, dynamic columns and repository commands |
| `lib/features/projects/presentation/screens/project_create_flow_screen.dart` | Autosaved wizard presentation and responsive tests | Expand three stages to effective R35 five; change authority/team rules |
| `lib/shared/models/project_creation_draft.dart` | Common scope, multiple buildings, legacy-safe draft conversion | Server transaction and four-role membership payload |
| `lib/features/projects/presentation/screens/project_workspace_screen.dart` | Workspace tabs, current action, responsive inspector | Replace V7 Material Plan/Procurement placeholders with BOQ/MR/Documents |
| `lib/shared/models/material_master.dart`, material-master migrations | Stable material/category/unit migration and archive patterns | Reuse for single-warehouse inventory and BOQ mappings |
| secure commercial migration/tests | Protected commercial boundary and adversarial pgTAP style | Extend to V1 MR/arrangement/inventory/document projections |
| `lib/shared/sync/outbox.dart`, `realtime_sync.dart` | Retry/draft delivery and refresh mechanics | Exclude critical state/stock authority; use RPC-specific repositories |
| legacy providers/models/tests | Compatibility fixtures and regression coverage | Treat as migration input, not canonical V1 domain |

## 4. Identity, roles and route gaps

- `lib/shared/models/user_role.dart::UserRole` has only Engineer, Procurement and
  Admin. Rev 2.0 requires Project Engineer and Site Engineer.
- `UserRole.fromName` silently falls back to Engineer. New canonical claims
  would be misclassified without an explicit mapper.
- `lib/app/router.dart::_isAllowedForRole` eventually allows broad remaining
  Engineering paths and is not project-membership aware.
- `/projects/new` and `/projects/:id` do not enforce the new four-role and
  historical-membership rules at the route boundary.
- `lib/shared/providers/project_provider.dart::visibleProjectsProvider` exposes
  unassigned projects broadly and has no dated `project_members` authority.
- `supabase/functions/admin-users/index.ts` accepts the old role/capability
  vocabulary and needs a strict V1 allowlist.

Target: protected profiles/capabilities, dated project membership, four-role
claim mapping, route checks and matching RLS/RPC denial.

## 5. Project and BOQ gaps

- Project remains a JSON aggregate with legacy single/generic engineer fields,
  not normalized project/scopes/membership history.
- `ProjectLifecycleStatus` uses V7 Draft/Planning/Active/Archived semantics.
- Procurement-created projects can be automatically accepted in the current
  draft conversion, contradicting V1 read-only Procurement access.
- Weighted progress fields remain in `lib/shared/models/project.dart`; they do
  not participate in V1.
- There are no `boq_groups`, `boq_columns` or `boq_rows` relations.
- The existing material grid has a fixed column schema. It lacks ordered dynamic
  columns, canonical-plus-raw values, group-level editing and real workbook
  import.
- Similar/Blank rows currently append in relevant paths instead of inserting
  below the active row.
- `pubspec.yaml` has no XLSX workbook/file-picker dependency.

Target: normalized project/scopes/members, transactional 29-group creation,
dynamic BOQ, real workbook round-trip and mobile focused editor.

## 6. Material Request and procurement gaps

- `lib/shared/models/material_request.dart::RequestStatus` and
  `RequestPriority` do not match V1; Scheduled and approval/receipt states are
  absent.
- MR lacks required scope, timing/scheduled date, server reference, requester
  project-role snapshot, arrangement version and approved quantities.
- Current draft/request snapshots use the generic shared collection, creating a
  Procurement draft-privacy risk.
- `lib/shared/providers/material_request_provider.dart` reserves inventory at
  submission, while V1 reserves only when Procurement saves an arrangement.
- No normalized arrangement lines, Full/Partial/Unavailable decisions,
  versioned approval decisions or return-for-changes command exist.
- Current project/request screens use V7 plan/sourcing concepts and must be
  mapped to the final R35 flow.

Target: owner-only drafts, explicit Submit RPC, complete arrangement version,
reservation replacement, separate Project Engineer approval and protected
commercial projections.

## 7. Inventory, dispatch, receipt and return gaps

- `lib/shared/providers/inventory_provider.dart` mutates/reserves
  SharedPreferences state. Postgres does not own the transaction.
- `lib/shared/sync/supabase_sync_backend.dart::apply` always performs a generic
  JSON upsert and does not execute the semantic operation kind as a locked
  transaction.
- Request dispatch loops change stock on the client before syncing a request
  snapshot.
- `lib/shared/models/material_dispatch.dart` and
  `lib/shared/providers/dispatch_provider.dart` are presentation/mock oriented,
  not a request-line logistics repository.
- Receipt stores only received quantity; Missing/Damaged review and immutable
  review versions do not exist.
- `lib/shared/providers/material_return_provider.dart` creates a return already
  restocked, rather than Submitted then Procurement-confirmed/rejected.
- Delivery Order snapshots do not exist.

Target: numeric locked inventory/reservations/movements, idempotent dispatch,
line review, good-receipt reconciliation, DO revision snapshots and confirmed
return stock posting.

## 8. Documents and audit gaps

- `lib/shared/models/project_attachment.dart` records metadata but no protected
  Storage object/version contract.
- There are no polymorphic document links, hashes, classifications,
  supersession or Storage RLS policies.
- Current activity models accept client-supplied actor/role/time.
- V1 has no append-only server-generated audit relation covering critical
  commands.

Target: immutable document versions plus classified links, authorized Storage
access, generated document snapshots and server-only critical audit inserts.

## 9. Supabase and migration gaps

- The nine tracked migrations cover commercial boundaries, material masters
  and obsolete V7 Phase 1 planning, not a complete clean V1 baseline.
- Base schema functions/tables also exist in `docs/supabase/schema.sql` rather
  than a fully tracked migration chain.
- There is no `supabase/config.toml`, deterministic seed or clean local reset
  contract.
- Existing pgTAP coverage does not cover four roles, memberships, BOQ, MR,
  reservations, competing writers, dispatch, receipt, DO, return, documents,
  audit or idempotency.
- `LocalCollectionStore.readAll` may skip undecodable rows; this cannot be a
  migration mechanism.
- Existing V7 Phase 1 RLS includes broad unassigned-project behavior that must
  not be copied.

Target: additive normalized migrations, clean local reset/seed, explicit
quarantine and complete positive/negative/concurrency database tests.

## 10. Platform/release gaps

- Batch 1 now adds CI database, Android release-build and signature-verification
  lanes; the local database gate must remain green before downstream batches.
- The main Android manifest now declares `android.permission.INTERNET` for
  release use.
- Android production signing now fails closed; only an explicitly marked,
  non-publishable CI verification key may be generated in CI.
- Android namespace and application ID are both confirmed as `com.yorks.app`.
  The Play listing must use that identity at its first production registration.
- `web/manifest.json` no longer forces portrait-only orientation, preserving a
  browser-first spreadsheet workspace.
- There is no integration-test/device lane for Android core flows.
- Flutter currently warns that the project/plugins must migrate from the Kotlin
  Gradle Plugin before a future Flutter version makes it a build failure.

These are Batch 1 blockers, not reasons to delay the normalized product design.

## 11. Highest-risk points

1. Legacy Engineer role backfill could grant approval privilege. Require an
   explicit reconciliation mapping.
2. App hydration/empty-table seeding could overwrite or upload demo/local data.
   Never use it as migration.
3. Current client inventory and dispatch mutations can oversubscribe under
   concurrency. Do not expose V1 until RPC paths pass competing-writer tests.
4. Costs embedded in shared JSON can leak to Engineers. Use protected response
   shapes, not zeroing after fetch.
5. Client-supplied actor/activity data is spoofable. Critical audit must be
   generated within server commands.
6. Silent legacy decode skips are data loss. Quarantine and reconcile every
   failure/unknown field.
7. Old routes/command-palette links can expose contradictory flows. V1 guards
   and navigation cleanup must cover direct deep links.
8. A successful Android assembly can still be unusable or falsely signed.
   Network permission and production signing are separate acceptance gates.

## 12. Dependency correction to the Execution Pack

The original T06 asks arrangement to create reservations before T07 introduces
inventory. Batch 6 therefore starts with the minimum inventory item,
reservation, movement and locking foundation before implementing arrangement
and approval. Full inventory browsing/management and logistics then continue
through Batches 6–7.

## 13. Resolved ambiguities

Batch 0 resolves role source/defaults, BOQ scope, planning model versus receipt
serial, receipt partial-good behavior, supplier-item return mapping,
reservation lifecycle, DO revision cardinality, document-link classification,
reference allocation and unavailable-line closure in
[`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

Remaining external decisions do not alter domain correctness:

- final Android application identity and Play signing owner;
- deployment/staging credentials and URL;
- named legacy-user-to-role reconciliation supplied before production backfill.

These require controlled business/operations input and are explicit later-batch
gates.
