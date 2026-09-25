# Company MR approval parity — staging handoff, 25 September 2026

Implementation source: `678b6820b0de187e1b74be264457c24b98236578`
on draft PR #26. The final, unaliased staging preview is
https://yorks-r35-l5h1o2m7k-sajid-alis-projects-0ec775a2.vercel.app.
No production migration, merge, promotion or deployment was performed.

An authorized Project Engineer, Senior Mechanical Engineer, Project Manager,
Workshop In-Charge, Document Controller or Admin with an active dated Company
category/unit approver grant can now submit and approve a Company request in
one atomic command. The selected approver, requester, beneficiary and receiver
are checked by the server. Site Engineers and ungranted roles keep the approval
handoff; beneficiary/receiver self-approval remains denied. The distinct
submission and decision events, version changes, decision, notifications and
idempotency result are retained. The transient self-handoff notification is
marked seen in the same transaction. Procurement arrangement, dispatch,
receiver confirmation, beneficiary handover, return and cancellation continue
to use their existing protected commands.

The Company detail now places eligible CTAs near the title, exposes an always
visible seven-stage progress card, uses the Project-style responsive material
table and preserves fulfilment quantities. Request Information opens in a
right-side panel. Company creation offers Submit and Approve when the protected
preflight assigns the signed-in approver, and keeps Submit for approval as the
secondary option. The reviewed desktop, 360px mobile and RTL fixtures were
updated; resize tests cover 360, 390, 600, 768, 1024, 1366 and 1920px.

Verification:

- Fresh local Supabase reset and full database suite: **110 files, 3,087
  checks passed**, including 16 new fast-path checks for role denials,
  beneficiary separation, version/idempotency, audit and notifications.
- Flutter analyzer and formatting passed. Company screen, repository and
  operations suites passed; the final screen suite has 32 tests.
- The full Flutter suite reported **1,608 passes and 264 known failures**,
  matching the prior failure count. These failures remain a release gate and
  are not represented as a clean full suite.
- CI web and ephemeral-signing Android APK builds passed. The final
  Company-enabled staging web build passed the startup check at **10,288,126
  raw / 2,773,687 gzip bytes** for `main.dart.js`. The APK is a verification
  artifact, not a publishable signed release.
- Staging preflight showed only
  `20260925024703_company_mr_submit_approve_parity.sql` pending; it was
  applied to the dedicated staging ref `iqltcyimlqtcwyzlemwx` and appeared
  in the remote migration ledger. A read-only function check confirmed the
  fast-path RPC and handoff handling.
- The final 61-file web bundle contains the staging backend reference and no
  production or CI reference. The preview verifier byte-matched **22 routes
  and assets**, including the Company creation route, MR register, PWA files,
  `main.dart.js` and all deferred JavaScript parts. Its `main.dart.js`
  SHA-256 is
  `12301b5b3615f7c42731bea91882604935f44c382a4207a5b695a21e8a43467f`.
  The production alias retained SHA-256
  `97b62b561e80d907239fe60786195bd760c148fcca6df45b569908bdadfcc4eb`.

Named-persona signed-in staging flows and PostHog ingestion remain user/UAT
checks; asset and database verification do not claim those runtime outcomes.
Rollback for staging is Company flag off plus the previous compatible preview.
Retain the additive schema and committed business evidence, then fix forward.
