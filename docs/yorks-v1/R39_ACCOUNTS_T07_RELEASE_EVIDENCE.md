# R39 Accounts T07 release evidence

**Evidence date:** 26 August 2026

**Release scope:** Yorks R39 Accounts T01-T07, additive and protected by the
separately controlled `YORKS_V1_ACCOUNTS` flag.

This file records reproducible local evidence. On 26 August 2026, the release
owner explicitly directed immediate production enablement and waived the
remaining five-persona UAT gate after reviewing the implemented Accounts flow.
That direction authorizes `YORKS_V1_ACCOUNTS=true` for the production web
artifact; it does not weaken server authorization or make legacy Finance an
authority.

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

## Production enablement decision

The release owner accepted the residual risk of enabling before the remaining
manual UAT matrix and explicitly requested production cutover. The launcher
therefore supports a validated operator-owned `YORKS_V1_ACCOUNTS=true` setting
while retaining `false` as the tracked/default and CI-safe value. Production
rollback remains data-preserving: rebuild with the flag disabled first, then
use the forward-disable SQL only if server consumers must also return to
shadow.
