# Company Material Requests staging preview — 25 September 2026

Implementation source: `a2cd9738cdfd0010c0c45f01629c11c1a2de3dd7` on PR #26.
Preview: https://yorks-r35-qw37ur92c-sajid-alis-projects-0ec775a2.vercel.app

The dedicated staging database dry run identified only four pending migrations:
`20260924213744`, `20260924221348`, `20260925000100` and `20260925003000`.
All four applied, appeared in the remote migration ledger, and the unified
register function was present afterward. No production database was changed.

The staging web build used the ignored operator-owned staging configuration,
with Accounts, Workforce, Analytics and Company Material Requests enabled.
The compiled artifact contains the staging backend reference and neither the
production backend reference nor the CI placeholder. The source checkout was
clean at build time. The build passed the startup check at 10,287,901 raw and
2,773,546 gzip bytes for `main.dart.js`; the raw allowance was raised by
30,000 bytes for the combined Company register while the 2.9 MB compressed
ceiling and other startup checks remained unchanged.

The 61-file static bundle was deployed as a Vercel preview. The release
verifier confirmed byte-identical responses for `/`, the login shell, the
Material Requests and Company creation deep routes, other key Yorks routes,
PWA files, `main.dart.js` and all seven deferred JavaScript parts. The live
`main.dart.js` SHA-256 is
`f18267a4c2c587a47aa047e7e21144195f4baa499f6fd999220549712a0c0655`.
The production alias retained its prior JavaScript SHA-256
`97b62b561e80d907239fe60786195bd760c148fcca6df45b569908bdadfcc4eb`.

The shared MR list now shows a purple briefcase for Company use and a blue
folder for Project use, with localized semantic labels. Real-font visual
fixtures at 1440, 1024 and 360 px passed, as did the analyzer and formatting.

This preview is for named-persona user testing. Live signed-in workflow and
PostHog ingestion were not verified during deployment. The full Flutter suite
still has 264 known failures, and the broader Company returns/document
acceptance remains open. Production deployment and merge remain separate gates.
