# User profile P02 acceptance evidence

Date: 5 September 2026  
Status: **implemented and locally accepted; not deployed**

## Accepted product boundary

- The desktop sidebar account stamp opens a compact `YorksAccountPopover`
  instead of a second statistics/profile dialog.
- The launcher shows the protected P01 account name, exact Yorks role and
  account state. Workspace connectivity is labelled separately.
- **Open My Yorks**, mobile More and shared avatar/account entries use the one
  canonical `/profile` destination.
- Profile surfaces share one localized sign-out command and confirmation
  component.
- A failed protected profile read is shown as unavailable and is never
  presented as an active account.
- No authorization, project, workflow, database, migration or production
  behavior was changed in P02.

The existing `/profile` content is intentionally retained at this stage. Its
responsive restructuring and role-aware content belong to P03–P05.

## Functional evidence

- `test/yorks_my_profile_p02_test.dart`: 14 tests passed.
  - compact launcher content and canonical route;
  - all nine exact Yorks role labels;
  - protected-read failure state;
  - shared avatar route;
  - shared sign-out cancellation and confirmed login route.
- Focused shell, profile, mobile and Workforce route regression checks passed.
- Complete `flutter test`: **1,580 tests passed**.
- `flutter analyze`: **no issues found**.
- Changed Dart format gate: passed with no changes required.
- `git diff --check`: passed.

P02 contains no SQL, RLS or RPC change. The additive P01 projection and its
database authorization coverage remain recorded in
[`../user-profile-p01/P01_ACCEPTANCE.md`](../user-profile-p01/P01_ACCEPTANCE.md).

## Responsive visual evidence

- Desktop account launcher, 1366x768:
  [`../../../../test/goldens/profile_p02/account_popover_1366x768.png`](../../../../test/goldens/profile_p02/account_popover_1366x768.png)
- My Yorks phone portrait, 360x800:
  [`../../../../test/goldens/mobile_batch5/50_profile_settings_360x800.png`](../../../../test/goldens/mobile_batch5/50_profile_settings_360x800.png)
- Offline workspace sheet from My Yorks, 360x800:
  [`../../../../test/goldens/mobile_batch5/51_offline_sync_360x800.png`](../../../../test/goldens/mobile_batch5/51_offline_sync_360x800.png)

Affected shell and mobile golden baselines were reviewed and regenerated after
the intentional account-entry and **My Yorks** label changes. No overflow or
uncaught Flutter exception was observed.

## Release-shaped build evidence

```text
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-web
```

Passed. `build/web` was produced and the startup budget passed:
`main.dart.js=9,689,577 bytes`, gzip `2,628,240 bytes`.
SHA-256 for `build/web/main.dart.js`:
`e96dc77022431c5d08f37262b2ba6550a687da2340892a5bc24f5204fc43a744`.

```text
CI=true YORKS_CI_EPHEMERAL_SIGNING=true \
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-apk
```

Passed. `build/app/outputs/flutter-apk/app-release.apk` was produced
(`103.9 MB`). Gradle, Android Gradle Plugin and Kotlin emitted future support
warnings; they did not fail this gate.
APK SHA-256:
`4b3c35d4ad9ae90fb4a59dbeaeb212c6a24d6d3348fcd8e164556ccc7816e072`.

## Rollback and release state

P02 is client-only and rollback-safe. The prior sidebar entry and local
confirmation callers can be restored without removing the additive P01
projection. No migration was applied remotely, no commit was created, and no
staging or production deployment was performed.
