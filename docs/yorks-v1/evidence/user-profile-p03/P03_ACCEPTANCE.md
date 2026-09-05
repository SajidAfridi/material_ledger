# User profile P03 acceptance evidence

Date: 5 September 2026  
Status: **implemented and locally accepted; not deployed**

## Accepted product boundary

- The canonical `/profile` destination now renders compact, medium and expanded
  compositions from one ordered section model.
- Desktop, tablet portrait, tablet landscape, phone portrait and short phone
  landscape are deliberate layouts. The selected section survives rotation and
  width changes.
- Account identity comes only from the protected P01 profile projection. The
  page no longer uses a legacy four-role `UserRole` decision or an employee
  record as account authority.
- Loading and error states do not fabricate an active account, business metric
  or zero summary. A failed protected read remains visibly unavailable and
  recoverable through an explicit retry.
- Preferences retain secondary language, notifications, display currency and
  app lock. Help and security retain workspace sync, version, About and the
  shared P02 sign-out command.
- P03 does not add role summaries, access explanations, protected quick actions,
  employee identity or Workforce worker identity. Those remain P04 and P05.
- No authorization, database, RLS, RPC, project, workflow, migration, remote
  environment or production behavior changed in P03.

## Responsive and accessibility evidence

- Functional layout checks passed at 1440x900, 1366x768, 1180x820, 1024x768,
  820x1180, 800x360, 768x1024, 844x390, 430x932, 390x844 and 360x800.
- Seven reviewed visual baselines cover desktop, tablet portrait/landscape,
  phone portrait/landscape, Arabic RTL and 200% phone text:
  [`../../../../test/goldens/profile_p03/`](../../../../test/goldens/profile_p03/).
- The page mirrors in RTL while email remains left-to-right. Page copy, states,
  picker copy and semantic labels are centralized in a four-language profile
  string model.
- Keyboard section activation, selected/toggled semantics, live account-state
  announcements and named screen-reader controls are verified.
- Interactive rows and controls are at least 44px high. Two-hundred-percent
  text remains scrollable without clipped or hidden controls.
- Reduced-motion users receive immediate section navigation and non-animated
  picker presentation.
- Contrast checks for the principal surfaces meet WCAG 2.1 AA: white on navy
  13.45:1, profile ink on white above 10:1, blue on white 5.21:1 and error on
  white 5.39:1.

## Functional verification

- `test/yorks_my_profile_p03_test.dart`: **29 tests passed**.
- P01/P02/P03, mobile profile, shell, route and smoke compatibility set:
  **134 tests passed**.
- Complete `flutter test`: **1,609 tests passed**.
- `flutter analyze`: **no issues found**.
- `flutter pub get`: passed.
- Changed Dart format gate: passed with no changes required.
- `git diff --check`: passed.

P03 contains no SQL, RLS or RPC change, so no database reset or pgTAP gate is
introduced by this slice. The protected P01 authorization evidence remains in
[`../user-profile-p01/P01_ACCEPTANCE.md`](../user-profile-p01/P01_ACCEPTANCE.md).

## Release-shaped build evidence

```text
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-web
```

Passed. `build/web` was produced and the startup budget passed:
`main.dart.js=9,722,720 bytes`, gzip `2,635,483 bytes`.
SHA-256 for `build/web/main.dart.js`:
`95d74eb6f32f5e4a31ed735ccc242d548d18105c6b4976e2aee8f06f29dc0f4c`.

```text
CI=true YORKS_CI_EPHEMERAL_SIGNING=true \
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-apk
```

Passed. `build/app/outputs/flutter-apk/app-release.apk` was produced
(`103,888,632 bytes`). This is an ephemeral CI signing/buildability gate, not a
claim that the APK carries the business production certificate. Gradle, Android
Gradle Plugin and Kotlin emitted future-support warnings without failing the
gate. APK SHA-256:
`e2fbf2b905c12dd398bee9d78e8f9b2ace7a7b0da23519970c1d2caf414132a5`.

## Rollback and release state

P03 is client-only and rollback-safe. The adaptive page, profile copy model and
picker accessibility additions can be reverted while retaining the protected
P01 projection and accepted P02 one-entry route. No migration was applied
remotely, no commit was created, and no staging or production deployment was
performed.
