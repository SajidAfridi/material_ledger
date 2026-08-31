# Workforce Production Release Evidence

Status: **released and independently smoke-verified on 31 August 2026**

T14 boundary: **named-persona/manual staging UAT remains deferred, not
performed and not passed.** The product owner explicitly authorized this
production release as an exception and required T14 setup/UAT next. Automated
release and live-smoke evidence below is not T14 evidence.

## Source and rollback identity

| Evidence | Value |
|---|---|
| Release source commit | `a8f31d8466bc115a2fdab894f5c261381adc4a17` |
| GitHub `main` | Exact match to the release source commit after push |
| Pre-release source commit | `eeed1a294abfd686aada03791e605ff06a58124f` |
| Production Supabase ref | `czykuksmlwswjsgotrpo` |
| Dedicated staging ref | `iqltcyimlqtcwyzlemwx` |
| Previous Vercel deployment | `dpl_9RnX6xtiLQhocA1F2xGP5Q9uMgNz` |
| Previous Vercel URL | `https://yorks-r35-8l1lh1pse-sajid-alis-projects-0ec775a2.vercel.app` |

## Technical release gates

- `flutter pub get`: passed.
- changed-Dart format gate: 55 files checked, zero changed.
- `flutter analyze`: passed with no issues.
- focused Workforce and feature-flag Flutter gate: 152 tests passed.
- clean `supabase db reset`: passed through every tracked migration and seed.
- complete local `supabase test db`: 75 files and 2,326 assertions passed.
  The 500-worker T06 validation completed in 15,100.61 ms; the T13 local wall
  observations were overview 7,185.62 ms, roster 852.26 ms and queue 2,710.46
  ms. These are observations, not newly invented product SLAs.
- production-shaped web build: passed with Accounts and Workforce enabled.
- Android release-shaped technical build: passed and produced a 101.2 MB APK
  using the explicitly CI-ephemeral certificate. This is not a claim that a
  protected store-signing artifact was published.
- credential/backend scan: the web artifact contained the production ref,
  contained neither the staging/CI refs nor a credential-shaped secret, and
  no service-role credential was introduced into tracked source.

The previously accepted T13 full-suite baseline included unrelated legacy
golden/overflow failures; this release does not relabel that global suite as
green. The focused Workforce, analyzer, database and release-build gates above
are the observed release evidence.

## Production migration evidence

Before mutation, the linked production ledger matched local history through
`20260829110327`. The reviewed dry run contained exactly these 17 additive
Workforce migrations and no seed or role operation:

- `20260829225746` through `20260830090445` — T01–T04 foundation,
  calendar/retained-history, attendance/future-date and allocation authority;
- `20260830101500` and `20260830111341` — T05 roster plus authority/aggregation
  bounds;
- `20260830120427`, `20260830140235` and `20260830150826` — T06 validation and
  retained historical/team-month corrections;
- `20260830152937` — T07 review/approval lifecycle;
- `20260830215610` — T08 collaboration/evidence/notifications;
- `20260831000752` — T09 reports/exports;
- `20260831022915` — T10 dashboards; and
- `20260831090940` — T13 query and period-authority hardening.

All 17 applied successfully to `czykuksmlwswjsgotrpo`. The post-apply ledger
matched local through `20260831090940`, and a second dry run returned no
pending migration, seed or role operation. No production seed/persona data was
created. No Edge Function source changed in this release; the existing
production `finalize-document-upload` function remained ACTIVE version 1 with
JWT verification.

## Web artifact and deployment identity

| Artifact | SHA-256 |
|---|---|
| `index.html` | `31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5` |
| `main.dart.js` | `7d3f799806b2a0545770fd44403e497cedf4a6a4d3e5dfa9a64178cd82516a65` |
| `flutter_bootstrap.js` | `cd1731f91810aa4b388a18417a9d2eae70d04f07350b9bb390629f5e423f13e6` |
| `manifest.json` | `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff` |
| `flutter_service_worker.js` | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` |
| `firebase-messaging-sw.js` | `e8151cb276b7644627e5cefc1dc5e46b69ad38f952c4a734b1f81a9795437a1e` |

The verified 52-file `build/web` output was copied to an isolated directory;
Vercel extracted the 51 deployable static files without discovering the
repository. The unaliased candidate was:

- deployment: `dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g`;
- URL: `https://yorks-r35-asnb696qz-sajid-alis-projects-0ec775a2.vercel.app`;
- state: `READY`, target `production`.

Before promotion, `/`, the three Workforce routes, Projects, Material
Requests, Accounts and Team Chat each returned HTTP 200 with the exact local
`index.html` hash. The five runtime/PWA assets above also returned HTTP 200 and
matched local bytes. The remote configuration scan found the production ref
and zero staging/CI/credential-shaped matches.

After those checks, the candidate was promoted to
`https://yorks-r35.vercel.app`. The same eight route and five asset checks were
repeated on the alias and matched exactly. Vercel resolved the alias to
`dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g` in `READY` state.

## Rollback and remaining work

If the client release must be contained, promote previous deployment
`dpl_9RnX6xtiLQhocA1F2xGP5Q9uMgNz`; that restores the prior static client while
retaining diagnostic evidence. The production migrations are additive and
their history must not be deleted or rewritten. Keep the Workforce UI
contained with a prior flag-off artifact, then correct any proven database
defect with a reviewed forward migration. The source rollback point is
`eeed1a294abfd686aada03791e605ff06a58124f`; do not reset or rewrite `main`.

Next work remains T14 on the dedicated staging project: approve named
non-production personas and witness, form one immutable staging candidate, and
execute the 35 manual scenarios. Production smoke checks above cannot be
credited toward that acceptance.
