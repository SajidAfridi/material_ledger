# Terra — Yorks V1 R35 Development Contract

This repository builds **Yorks AC. & Ref. V1 R35**, not GodownPro or Nexus V7.
Rev 2.0 defines current behavior, and the effective R35 HTML defines the
non-conflicting visual and interaction target.

## Read before changing code

Read these in order for every task:

1. [`AGENTS.md`](AGENTS.md) — repository-wide safety, architecture and role rules.
2. [`docs/yorks-v1/README.md`](docs/yorks-v1/README.md) — local V1 authority map.
3. [`docs/yorks-v1/SOURCE_OF_TRUTH.md`](docs/yorks-v1/SOURCE_OF_TRUTH.md) — approved source hierarchy and superseded V7 decisions.
4. [`docs/yorks-v1/PRODUCT_DECISIONS.md`](docs/yorks-v1/PRODUCT_DECISIONS.md) — frozen workflow, roles, quantities and security decisions.
5. The task-relevant Yorks V1 contract: UI, architecture/security, state/RPC/RLS, migration, test or release readiness.

The approved Rev 2.0 SRS, R35 HTML prototype and execution pack are the
external source artifacts fingerprinted in `SOURCE_OF_TRUTH.md`. If one of
those artifacts changes, stop and treat it as a new product input.

## Canonical R35 build

Yorks V1 is enabled by default in Dart. Supabase targets are never embedded as
defaults: create an ignored explicit configuration once, then use the launcher
without typing dart-defines:

```bash
cp tool/r35.env.example .r35.env
# Edit .r35.env with local, staging or production values.
./tool/r35.sh run
./tool/r35.sh build-web
./tool/r35.sh build-apk
```

The tracked `./tool/r35.sh` launcher enables all nine `YORKS_V1_*` flags and
`use_arabic=true`, reads only the explicitly configured publishable Supabase
pair, and deliberately enables no `NEXUS_V7_*` flag. Never add V7 project,
planning, browse or procurement flags to an R35 command. CI supplies its own
placeholder values and `R35_ENVIRONMENT=ci`.

## Current product boundaries

- Roles are exactly `project_engineer`, `site_engineer`, `procurement` and
  `admin`, derived from server-controlled `app_metadata.role`.
- Supabase Auth/Postgres, RLS and trusted RPCs are authoritative for committed
  workflow state; local storage is limited to drafts, permitted cache and
  queued non-critical work.
- The canonical chain is `Project -> BOQ -> MR Draft -> Submit ->
  Arrange/Reserve -> Approval -> Dispatch -> Receipt -> Delivery Order -> Return`.
- Do not reintroduce Material Plan, RFQ/PO, Accounts, legacy Engineer roles,
  GodownPro naming or old visual rules into current Yorks routes.
- Preserve legacy records and decoders; do not delete historical evidence or
  silently reinterpret it.

## Legacy material — read only as evidence

The following are intentionally retained but are **LEGACY — NOT CURRENT
PRODUCT AUTHORITY**:

- `docs/nexus-v7/` and its design prototype;
- `docs/claude.md`, `docs/design.md`, `docs/ARCHITECTURE.md`,
  `docs/ARCHITECTURE_AUDIT.md`, `docs/backend-firebase-vs-supabase.md` and
  `docs/srs_extracted.txt`;
- historical generic-sync material under `docs/supabase/`;
- root/binary GodownPro SRS and architecture artifacts.

Use those files only to preserve migrations, compatibility, security lessons or
regression coverage. When any legacy text conflicts with `AGENTS.md` or
`docs/yorks-v1/`, the Yorks V1 contract wins.

## Verification

Run the narrow checks first, then the applicable gate from `AGENTS.md`:

```bash
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
./tool/r35.sh build-web
```

Do not claim a production release from a local debug run. Report files changed,
tests, build evidence, migration/rollback impact and any release-owner blocker.
