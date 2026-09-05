# My Yorks P04/P05 local acceptance

Accepted locally: 5 September 2026  
Baseline commit inspected: `f37ee8a405158864465606202166451c3db0809b`  
Release boundary: local implementation and verification only; no staging or
production migration, deployment, commit or push was performed.

## Accepted behavior

- `v1_get_my_yorks_profile_workspace()` is a no-argument, authenticated,
  `STABLE SECURITY DEFINER` projection with an empty `search_path`.
- P01 remains the identity, capability and navigation-action authority. The
  P04/P05 response must match its actor, exact role and permission revision or
  the client rejects it.
- **Today** contains only bounded server-confirmed project, Material Request
  and organization-portfolio Accounts counts. Unavailable facts are omitted;
  loading and errors never become false zeroes.
- **Access & scope** explains safe aggregate reach, direct membership count,
  effective access source and the next scheduled authority transition.
- Quick links require both a protected P01 navigation action and the relevant
  feature flag. Accounts additionally requires the server-confirmed
  organization portfolio gate.
- **Work identity** is a separate self-linked Workforce record. It exposes
  only worker number, display name, designation, optional department, type and
  current status. It grants no self-service and exposes no attendance,
  assignment, team, supervisor, contact, HR-note or commercial data.
- Preferences, refresh access, sync, app lock, About and sign out share the
  same compact, medium and expanded responsive composition in English,
  Arabic, Urdu and Hindi.

## Verification evidence

| Gate | Result |
|---|---|
| Clean local Supabase rebuild | Passed; P01 then P04/P05 migrations applied in timestamp order |
| Focused P04/P05 pgTAP | Passed; 1 file, 32 assertions |
| Complete Supabase database suite | Passed; 89 files, 2,631 assertions |
| Focused P04/P05 Dart/widget suite | Passed; 18 tests |
| Profile responsive/accessibility regression | Passed; 29 tests |
| Legacy mobile profile/document suite | Passed; 16 tests |
| Legacy mobile shell and smoke checks | Passed; 5 + 17 tests |
| Dart formatting | Passed; no changes required |
| `flutter analyze` | Passed; no issues |
| Complete `flutter test` | Passed; 1,627 tests |
| Production-shaped web build | Passed; startup budget passed |
| Ephemeral-signed Android release build | Passed |
| `git diff --check` | Passed |

## Artifact evidence

- `build/web/main.dart.js`: 9,785,860 bytes;
  SHA-256 `2daf2051b667090599194d89d70b19eee0edacbc1940f22cd5686b295f267752`
- `build/app/outputs/flutter-apk/app-release.apk`: 104,167,304 bytes;
  SHA-256 `d8a0856c7547d19884411dd3635f993f4964d7be10840b069e9b61aa2088a0d4`

## Visual evidence reviewed

Deterministic goldens under `test/goldens/profile_p04_p05/` cover desktop
1440x900, tablet 1024x768 and 820x1180, phone 390x844, short-height landscape
844x390, Arabic RTL 390x844 and 200% text at 360x800. The profile also passed
layout assertions at 1366x768, 1180x820, 800x360, 768x1024 and 430x932.

## Security and rollback

Project Engineer, Site Engineer, Procurement and Admin boundaries are tested.
Denied project scope removes both project and membership counts, project-only
Accounts access cannot become portfolio access, stale/legacy/inactive/banned/
anonymous identities fail closed, and repeated reads do not mutate profile,
permission or worker state.

Rollback is additive and non-destructive: revoke authenticated execution of
`v1_get_my_yorks_profile_workspace()` and return the client to P01-only
profile sections. No existing account, permission, project, Workforce or
Material Request data is rewritten by the migration.

## Remaining phase

P06 remains open. It covers dedicated staging deployment and named-persona
UAT, including live permission refresh and real role/capability combinations.
P04/P05 local acceptance is not evidence of staging or production release.
