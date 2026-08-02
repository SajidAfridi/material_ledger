# Yorks AC. & Ref. V1 R35 — Batch 10 Release Readiness

Status: **local release evidence passed; staging and production cutover are
blocked pending release-owner authority**.

This is the controlled-release checkpoint for the code merged through
`6644eafe0380b14ebbe75f955937e4f1a6ab7857`. It deliberately distinguishes a
reproducible local proof from a staging acceptance or a production release.
No hosted Supabase project, deployment target, production signing key or Play
account was supplied to this repository task.

## Local evidence captured on 2 August 2026

| Gate | Result |
|---|---|
| Clean migration replay | `npx supabase db reset --local` passed through Batch 9 and seeded the four local personas. |
| Database/RLS/concurrency suite | `npx supabase test db --local` passed: 12 files, 351 tests. |
| Flutter static analysis | `flutter analyze` passed with no issues. |
| Flutter suite | `flutter test` passed: 448 tests. |
| Browser release build | `flutter build web --release` passed with non-secret CI placeholder backend values. |
| Android verification APK | CI-only signed release APK passed; it is explicitly non-publishable. |
| Android verification AAB | CI-only signed release AAB passed; it is explicitly non-publishable. |
| Production-signing guard | An ordinary release APK build failed as intended because `android/key.properties` is absent. |
| Local browser smoke | Signed in as the seeded Project Engineer with all Yorks flags enabled. The branded welcome/sign-in screens, desktop project-creation flow, 360px dashboard and 360px project-details flow rendered without a console warning or error. |

The Flutter tool reports two unrelated forward-looking warnings: an iOS
CocoaPods-to-Swift-Package migration notice, and a future Kotlin Gradle Plugin
migration notice (including `sentry_flutter`). Neither blocks the current web
or Android build, but both belong in the platform-maintenance backlog before a
future Flutter upgrade.

## Verification-artifact provenance

The following locally built artifacts are verification-only and are **not**
release candidates. They were created with the explicit CI ephemeral signing
lane and therefore must never be uploaded to Google Play.

| Artifact | SHA-256 | Signer |
|---|---|---|
| `build/app/outputs/flutter-apk/app-release.apk` | `06e6153c397ca358cd552e48cb4c3b1a2daaa533900b1198e8dce0b8a853f1ef` | Yorks CI Ephemeral |
| `build/app/outputs/bundle/release/app-release.aab` | `f4c072405cd315c19ae1c4c626e2982243653d2da3f4c5d723a093035d7ed77e` | `CN=Yorks CI Ephemeral, OU=CI Only, O=Yorks, C=AE` |

The accepted Android identity remains `com.yorks.app`. A production release
record must replace this table with the protected CI artifact's SHA-256,
version, package inspection and production certificate subject.

## AT-01–AT-25 evidence matrix

All rows below have automated local evidence. `Staging witness required` means
the scenario still needs a recorded live walkthrough by the named personas; it
does **not** mean the automated check failed.

| Scenario | Local evidence | Current release state |
|---|---|---|
| AT-01 | `yorks_v1_batch2_projects.test.sql`, `yorks_v1_project_create_flow_test.dart` | Automated pass; staging witness required |
| AT-02 | Batch 2/3 pgTAP BOQ-default tests and Batch 3 BOQ widgets | Automated pass; staging witness required |
| AT-03–AT-04 | `yorks_v1_batch4_excel.test.sql` and workbook round-trip tests | Automated pass; staging workbook witness required |
| AT-05 | Batch 3 BOQ row-order/Similar Row tests | Automated pass; staging witness required |
| AT-06–AT-08 | `yorks_v1_batch5_material_requests.test.sql` and MR widgets | Automated pass; staging witness required |
| AT-09–AT-12 | `yorks_v1_batch6_arrangement_inventory.test.sql` | Automated pass; staging witness required |
| AT-13–AT-16 | `yorks_v1_batch7_logistics.test.sql`, logistics widgets | Automated pass; staging witness required |
| AT-17–AT-19 | `yorks_v1_batch8_delivery_orders_returns.test.sql`, logistics-document tests | Automated pass; staging witness required |
| AT-20 | MR/DO/Return PDF and print service tests, including multi-page coverage | Automated pass; Chrome/Edge and Android visual witness required |
| AT-21 | Batch 2 membership/RLS tests | Automated pass; staging witness required |
| AT-22 | Batch 5 cancel/deletion state and RLS tests | Automated pass; staging witness required |
| AT-23 | `smoke_test.dart` retained-module coverage | Automated pass; staging witness required |
| AT-24 | Yorks calculator service/widget tests | Automated pass; staging witness required |
| AT-25 | Batch 2–9 direct-table/RPC/RLS negative suites | Automated pass; staging API witness required |

## Android and browser gates

| Gate | Local evidence | Remaining proof |
|---|---|---|
| AP-01 Internet permission | Declared in the tracked Android manifest; APK assembly passed. | Inspect the production-signed artifact manifest. |
| AP-02 signing separation | Ordinary release build fails closed; `CI=true` plus the explicit ephemeral flag produces a non-publishable verification artifact. | Build with the protected Yorks keystore in CI and record package/signature provenance. |
| AP-03 360px critical flows | Project creation and logistics focused-editor widget coverage; local 360px browser review passed. | Repeat create/submit/approve/receipt/return on a real Android device or emulator with safe-area and keyboard evidence. |
| AP-04 file/document/PDF operations | Workbook and document service tests pass. | Signed-in staging upload/download, picker and share evidence on web and Android. |
| AP-05 retry safety | Database idempotency/concurrency tests pass. | Staging network-interruption walkthrough. |
| AP-06 browser-first layout | Web build and responsive widget coverage pass. | Record 1366x768 BOQ and PWA walkthrough. |
| AP-07 commercial boundary | Commercial RLS and non-commercial projection tests pass. | Capture authorized/unauthorized staging API and output-byte checks. |
| AP-08 legacy route closure | Router/deep-link tests pass. | Record direct-link staging denial evidence. |

## Release blockers outside this checkout

1. GitHub Actions cannot start in this repository because the account is locked
   for billing. The run for PR #5 failed before any job ran, so it is not
   evidence of a code failure. Restore the account before treating hosted CI
   as a release gate.
2. A release owner must provide a staging Supabase project and deploy authority
   for the database migrations and `finalize-document-upload` Edge Function.
3. A release owner must choose and authorize the web hosting target. No web
   deployment is inferred from a successful local build.
4. Production Android signing material, Play Console access and a release
   owner are required for a publishable APK/AAB. Never place the keystore,
   passwords or service-role secret in this repository or chat.
5. Four named staging personas and a representative non-production data set
   are required for the manual acceptance witness.

Until those items are available, Batch 10 cannot be marked complete and no
production cutover is authorized.

## Controlled-cutover runbook

### 1. Freeze and preflight

1. Select a release commit and record its SHA, release version and source
   hashes.
2. Require a clean worktree and run the local gates listed above.
3. Confirm that `SUPABASE_URL` is HTTPS and that the client receives only a
   publishable/anon-equivalent key. Confirm service-role, signing and hosting
   credentials exist only in protected CI or server environments.
4. Create a provider-confirmed backup of the target database and Storage
   bucket. Restore it into an isolated environment and record the restore
   timestamp, owner and validation result before changing the target.
5. Capture source counts, state counts and hashes for every legacy data source
   in scope. There is no implicit data conversion in a Flutter client.

### 2. Deploy an isolated staging environment

1. Link the Supabase CLI to the approved staging project in the release
   operator's environment, then review the pending migration list.
2. Apply the tracked additive migrations with all Yorks V1 feature flags off.
3. Deploy `finalize-document-upload` from
   `supabase/functions/finalize-document-upload/` using the approved Edge
   Function deployment procedure. Do not disable JWT verification or expose a
   service role to Flutter.
4. Use the protected reconciliation report (`v1_get_reconciliation_report`)
   and source/target counts to verify that every legacy row is either preserved
   in the target or represented in quarantine. A nonzero unexplained difference
   stops the cutover.
5. Create the four staging personas from server-controlled
   `app_metadata.role`: Project Engineer, Site Engineer, Procurement and
   Admin. Do not infer a role from email or editable user metadata.

### 3. Record the staging acceptance witness

1. Exercise AT-01–AT-25 in order with the four personas, recording actor,
   time, project/request references and screenshots.
2. Exercise AP-03–AP-08 on 1366x768 web, 360px Android and a normal tablet
   width. Store short and multi-page document/PDF evidence with the release
   record, not in public Storage.
3. Run direct negative RLS/RPC checks for an unrelated Engineer, a revoked
   membership and no-commercial-capability Engineer. Verify that denied calls
   leave no partial rows, movements, objects or audit side effects.
4. Simulate duplicate commands and a temporary network interruption for
   arrangement, dispatch, receipt and return confirmation. Reconcile stock,
   reservations, movements and audit entries afterwards.
5. Obtain the release owner's written acceptance of the test matrix and any
   remaining, explicitly non-blocking limitations.

### 4. Build and deploy

1. Build the web release with the approved staging/production HTTPS URL and
   publishable key, then deploy it only to the authorized hosting target.
2. Build the Android AAB inside protected CI with
   `android/key.properties` supplied as a secret. Record application ID
   `com.yorks.app`, version, SHA-256 and certificate subject. The CI ephemeral
   artifact is never uploadable to Play.
3. Start with a named pilot group. Enable flags in dependency order:
   Foundation, Projects, BOQ, Excel, Requests, Arrangement, Logistics,
   Returns/Documents. Do not enable a downstream flag without its prerequisite.
4. Monitor command failures, Storage finalization failures, reconciliation
   counts and audit events during the agreed validation window.

### 5. Stop, rollback and recovery

Stop immediately for an unexplained count difference, commercial-data leak,
uncertain role mapping, disputed opening stock, missing backup/restore proof,
or a release owner without authority to decide the exception.

For a safe rollback, disable the affected Yorks flag and stop new grants or
deployment. Preserve every committed V1 record, audit event and controlled
document version. Do not drop additive tables, overwrite normalized state from
a legacy snapshot, or re-enable legacy stock writers after a V1 stock command.
Use an audited compensating command or the confirmed backup only under the
recovery owner's direction.
