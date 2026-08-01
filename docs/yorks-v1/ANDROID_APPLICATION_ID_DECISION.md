# Yorks V1 R35 — Android Application Identity Decision

Status: **approved for Yorks V1 on 1 August 2026**. This records the Android
identity only; it is not authorization to upload to Google Play.

## Current declared values

| Setting | Current value | Status |
|---|---|---|
| Android `applicationId` | `com.yorks.app` | Confirmed permanent Yorks application identity. |
| Android `namespace` | `com.yorks.app` | Aligned with the application ID and Kotlin `MainActivity` package. |

## Batch 1 decision

The product owner confirmed `com.yorks.app` for the Android identity. Batch 1
aligns the Gradle `applicationId`, Android namespace and Kotlin
`MainActivity` package in one coordinated change. The existing Flutter method
channel remains unchanged because it is an in-app integration name, not an
Android application identity.

Production signing still fails closed when the protected release configuration
is absent. CI can create only an explicit ephemeral verification certificate;
that APK is non-publishable. A Play upload still requires the controlled
production signing configuration and the release owner's authorization.

## Why this is a release blocker

Google Play application IDs cannot be changed after the first production
registration. The approved identity therefore needs a release build and
artifact inspection before its first Play use. The coordinated namespace and
Kotlin package change keeps generated Android references and release provenance
consistent.

## Evidence and follow-up

- `android/app/build.gradle.kts` declares `com.yorks.app` for both Android
  identity settings.
- `android/app/src/main/kotlin/com/yorks/app/MainActivity.kt` declares the
  matching Kotlin package.
- `.gitignore` excludes signing material; production credentials remain outside
  the repository.
- CI signs only with the distinguishable **Yorks CI Ephemeral** certificate.

Before the first Play use, verify a release build and record the artifact
package/signature provenance. Do not treat the CI ephemeral artifact as a
publishable build.
