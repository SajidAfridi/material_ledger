# R39 Accounts T07 release evidence

**Evidence date:** 26 August 2026

**Release scope:** Yorks R39 Accounts T01-T07, additive and protected by the
default-off `YORKS_V1_ACCOUNTS` flag.

This file records reproducible local evidence. It does not manufacture the
five-persona staging acceptance or release-owner approval required to enable
Accounts in production. Deploying the migrations and application while the
flag remains off is safe: normalized Accounts routes and protected commercial
responses remain unreachable, and no legacy Finance route becomes authority.

## Local release gates

| Gate | Result | Evidence |
|---|---:|---|
| Clean database rebuild | Pass | `npx --yes supabase db reset` applied the complete migration chain from zero, including T01-T07. |
| Focused Accounts database security and workflow | Pass | T01-T07 pgTAP: 211/211. |
| Complete database suite | Pass | `npx --yes supabase test db`: 55 files, 1,590 tests. |
| Forward-disable rollback rehearsal | Pass | T05-T07 disable script ran inside a transaction and rolled back cleanly. |
| Accounts Flutter boundary and routing | Pass | 124 focused model, repository, controller, route and permission tests. |
| Accounts responsive and golden UI | Pass | Nine focused tests; all six required viewports and both portfolio goldens passed. |
| Non-golden Flutter regression suite | Pass | 108 test files, 821 tests. |
| Static analysis | Pass | `flutter analyze`: no issues. |
| Formatting and patch integrity | Pass | Changed Dart files formatted; `git diff --check` clean. |

The production web and Android build commands, artifact hashes, linked
Supabase migration state, Git commit, Vercel deployment and public-route smoke
checks are recorded during the release execution and reported with the release
handoff.

## Security and rollback facts

- The exact ninth role is `Accountant`; it inherits no technical project,
  procurement, inventory, dispatch, receipt, return or team-management write
  authority.
- The 15 Accounts capabilities remain command-specific and are resolved from
  protected server identity and scope, never editable profile metadata.
- Commercial tables are protected by RLS; client writes use trusted RPCs with
  project binding, version checks, idempotency and server audit.
- Export payloads are server-scoped. Spreadsheet formula-like values are
  neutralized and unauthorized projections omit commercial fields.
- Rollback is forward-only and data-preserving. Use
  `supabase/snippets/r39_accounts_t05_t07_forward_disable.sql` after disabling
  the application flag; it returns consumers to shadow without deleting
  committed commercial evidence.

## External release gate still required for flag enablement

Before setting `YORKS_V1_ACCOUNTS=true`, the release owner must record the same
commit passing staging journeys for Site Engineer, Project Engineer,
Accountant, Procurement and Admin, confirm there are no open P0/P1 defects,
and explicitly approve enablement. Until then, production deployment must keep
the flag off or preserve an already-controlled production setting without
silently changing it.
