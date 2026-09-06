# Find and use information — 6 September 2026

## Delivered behavior

- Workspace search accepts case/spacing/punctuation variants, compact request
  references and one-character spelling mistakes for longer terms. Exact title
  matches rank first. Module aliases include MR, stock, finance and attendance.
- Search continues to consume authorized repository projections. Its two-minute
  in-memory index is discarded on identity, session or permission revision
  changes. Partial source failures are visible; they never appear as a confirmed
  empty search. Clearing a query invalidates pending responses.
- My Yorks includes Contact support. It opens a WhatsApp draft using the published
  company support number, with a copy-number fallback. Opening the draft does not
  send a message. Admin changes the number in Configuration, reviews the draft,
  and publishes it through the existing audited configuration workflow.
- The initial support number is +923159353145. The database requires a canonical
  international number; ordinary engineering, Procurement and Accountant roles
  cannot change this organization setting. Active Accountants can read the same
  non-sensitive runtime settings needed by Profile.
- New labels cover English, Arabic, Urdu and Hindi. The existing language setting
  continues to apply to the app shell and persist on the device/browser. It does
  not translate user-entered names or synchronize a preference between devices.
- Team Chat has a show/hide details button on desktop. The preference survives
  reopening the screen. Tablet and mobile retain their full-size details sheet.
  The desktop transition respects reduced motion.
- The approved black seal is used by the shared app logo, document logo asset,
  web startup, favicon/PWA icons, and generated Android/iOS launcher icons.
  Browser icon version references were updated. Historical source artwork remains
  preserved. Native launcher appearance requires installing the new binary.
- The generated seal removes the source image's pale square canvas with a soft
  circular alpha edge. A freshly generated Delivery Order was rendered to PNG
  at 150 DPI and visually confirmed without a rectangular logo boundary.

## Deployment and preservation

The additive migration is
`../../supabase/migrations/20260906114750_yorks_support_contact_configuration.sql`.
It preserves existing settings and publication history. Rollback means publishing
the prior support number or reverting the UI; no historical data is deleted.
The implementation was subsequently deployed to staging on user request;
see the deployment record below.

## Verification

Focused Profile/search/Team Chat checks and reviewed desktop/mobile/RTL goldens
pass. Final checks:

- Clean local Supabase reset passed; the additive migration also passed a second
  application without overwriting the published setting.
- Full database suite: 91 files, 2,669 assertions passed.
- Flutter analyzer: no issues. Full Flutter suite: 1,647 tests passed.
- Dart formatting and `git diff --check` passed.
- R35 CI web build passed, including startup size limits. `main.dart.js` SHA-256:
  `f7e64dedd8cfb02159ddd00f5d292badcb37f7a4a906c4d6f0999bf5a90f7079`.
- R35 CI Android build passed. APK SHA-256:
  `ee97fd779270a2efc60a6f7aef20fa1403095766a738f9d1858cfc37a84f22da`.

CI Android uses the explicit ephemeral signing lane and is not a production
signed distribution artifact. Device/browser acceptance and deployment remain
the next release step. Existing prior web deployment output was preserved in
`/tmp/yorks-prior-web.tVDi4w/web` before the clean CI web build.

## Staging deployment

- Preview: https://yorks-r35-qf1407j0b-sajid-alis-projects-0ec775a2.vercel.app
- Deployment: `dpl_3ghzgd3oA4QZbRwC2H949jc4WkqJ`.
- Backend: `iqltcyimlqtcwyzlemwx`; Accounts, Workforce and Analytics enabled.
  Staging backend occurs once in the bundle; production and CI references zero.
- Applied only migration `20260906114750`. Subsequent dry-run reports no pending
  migrations. Published support contact verified as `+923159353145`, operational.
- Root, About, Profile, notification preferences, Analytics, Workforce, Rentals,
  Material Requests and Team Chat routes matched the built HTML. Bootstrap,
  main/deferred JavaScript, PWA workers and manifest hashes matched the artifact.
  Black logo, favicon and installed-web icon hashes also matched.
- Staging main JavaScript SHA-256:
  `58d9fca62b643aa91f090d0871bd882323132a66f9bfd7e823509d3b509cc71e`.
- Artifact preserved at `/tmp/yorks-find-staging.bRUIUb`.
- Production alias was not promoted. Interactive acceptance is pending user
  testing. To roll back this preview, return to the prior preview URL; preserve
  the additive setting and publish a corrected number if needed.
