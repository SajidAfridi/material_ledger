# Project setup workspace integration — 4 October 2026

## Root cause and correction

The staging candidate deployed the full application from `lib/main.dart`, not
the synthetic visual fixture. Its setup route nevertheless bypassed the shared
Yorks workspace shell. The desktop hamburger collapsed only the setup stage
rail, the phone drawer contained only Projects and setup stages, and search
offered only Projects as a module shortcut. Profile, notifications and sign-out
already used the real shared services, but normal workspace navigation was
missing from the new chrome.

The [route wrapper](../../../lib/app/router.dart) now uses
[`YorksV1WorkspaceShell(featureOwnsChrome: true)`](../../../lib/app/yorks_v1_workspace_shell.dart).
The [navigation scope](../../../lib/app/yorks_v1_workspace_navigation_scope.dart)
connects both setup headers to the canonical permission-filtered drawer, search
targets and session-scoped navigation history. The supplied header, stage rail,
mobile stepper and form layout remain feature-owned, with one header and one
zoom host. The local stage-only drawer and desktop collapse action are removed.

Create and Edit still enter through the existing application routes
(`/projects/new` and `/yorks/projects/<project-id>/edit`). Their GoRouter exit
guards and the feature's draft-aware pop/save decisions remain active; the outer
workspace pop handler does not issue a competing Back action. Draft identity,
acknowledgement, ownership, uncertain-command recovery and server authority are
unchanged. `YORKS_V1_PROJECT_SETUP` remains default off and browser-only; native
routes retain the accepted legacy experience. This correction changes no SQL,
RLS, RPC or commercial capability.

## Staging alias mismatch

Independent release inspection found that the stable staging alias
`yorks-r35-staging.vercel.app` still served the **26 September** candidate:

| Evidence | Observed value |
| --- | --- |
| Source | `449a0e01` |
| Deployment | `dpl_FxKmjTWKHzdo34uNXjDe9E4WHbNZ` |
| `main.dart.js` bytes | `10,423,896` |
| `main.dart.js` SHA-256 | `a535f2c106fb5018221cf9e593a6974d860b3cf96fe4320f608f285606452e44` |
| Compiled backend-reference occurrences | Staging `1`; production `0` |

The earlier 4 October preview from source `9dc91b8` had not been assigned to
that alias. A new preview must be built and byte-verified before assigning
**only the staging alias**. Production release remains a later, separate step.
These observations preserve the older [staging release report](STAGING_RELEASE_2026-10-04.md)
as historical evidence rather than treating its preview as the current alias.

## Validation and remaining work

- **Eight focused integration tests passed:**
  [test source](../../../test/yorks_v1_project_setup_workspace_integration_test.dart).
  They cover real Projects → Create entry and re-entry, retained draft ID/name
  and acknowledged revision, zero dispatched project commands, and actual
  permission loading/denial boundaries on desktop and phone.
- The final full suite passed **2,272 tests with four retained skips**, including
  the drawer label assertion and both Projects → Create re-entry cases.
  Analysis found no issues; all seven changed Dart files were formatted.
  CI web passed the startup budget (10,007,045 bytes / verifier gzip 2,880,695).
  CI APK built with CI Ephemeral signing; it is not a production artifact.
- Actual browser inspection exposed a macOS platform Drawer warning caused by
  a null route label. The shared drawer now supplies the existing localized
  `quickNavigation` semantic label, with a regression assertion. Fresh final
  desktop and phone sessions showed no captured warnings/errors. A debug engine
  semantics-map error on a post-enable breakpoint resize remains an open browser
  accessibility gate; no semantics suppression or unproven form-key workaround
  was added.
- [Browser captures and inspection scope](visual-evidence/workspace-integration-2026-10-04/README.md)
  accompany this report. Synthetic visual fixtures can demonstrate the chrome;
  they do not establish authenticated remote navigation or live create/upload
  success.

The [machine release record](WORKSPACE_INTEGRATION_2026-10-04.json) records
completed local gates and explicit pending deployment statuses. The staging
build identity, verified preview, alias assignment and production comparison
will be recorded after deployment. A successful preview or alias assignment
is not a production release or a complete source acceptance pass.

Application rollback remains the default-off flag or prior verified staging
deployment. Preserve draft, journal, quarantine and tombstone namespaces; no
database rollback is needed for this shell correction.
