# Yorks staging release — 18 September 2026

Status: **deployed to dedicated staging and ready for operator testing**

## Release identity

- Source commit: `6583997d4e4e0e45b3078b91003cfeb2c3d1cf8f`
- Supabase project: `iqltcyimlqtcwyzlemwx` (`yorks-r35-staging`)
- Vercel deployment: `dpl_4HFzeQJThMi3pxe8GJQje1MCGPG9`
- Preview: `https://yorks-r35-bgiupi2by-sajid-alis-projects-0ec775a2.vercel.app`
- Target: unaliased preview; production was not promoted or changed.

The staging build enables Accounts, Company Material Requests, Workforce and
Analytics. PostHog remains disabled in this artifact. The compiled bundle
contains the dedicated staging project reference once and the production
project reference and CI placeholder zero times.

## Supabase deployment

The remote migration ledger is aligned through
`20260917215706_audit_investigation_workspace.sql`. This release applied:

1. `20260917154516_material_request_submission_reconciliation.sql`
2. `20260917185345_company_material_request_approval_decisions.sql`
3. `20260917193012_company_material_request_fulfilment_lifecycle.sql`
4. `20260917201854_company_material_request_end_to_end_hardening.sql`
5. `20260917215706_audit_investigation_workspace.sql`

`finalize-document-upload` version 4 and `finalize-chat-attachment` version 2
are active with JWT verification. The staging company-use fixture remains
present with seven technical users, one active demonstration category, one
effective approval route and thirteen effective authorization rows.

Live privilege probes passed: authenticated users can execute the protected
Audit workspace, Audit export, company decision and supply-plan RPCs; anonymous
users cannot. Admin Audit reads returned HTTP 200, Procurement Audit reads
returned HTTP 403, anonymous Audit reads returned HTTP 401, and the Procurement
work inbox plus Engineering approval inboxes returned HTTP 200. Supabase's
security advisor returned no error-level findings; its existing warning
baseline remains for later security-maintenance work.

## Web artifact and live verification

The fully enabled build passed the startup budget at 10,205,890 raw bytes and
2,755,889 gzip bytes for `main.dart.js`. The transferred-size ceiling remains
2,900,000 bytes.

Critical local/live SHA-256 matches include:

- `main.dart.js`: `c78ac83e0863b02329f74c239b74ffe9c2ce111357b697303786cf803183f6fd`
- `flutter_bootstrap.js`: `5788a5579d2922d331b79757658939a239221f4fd54eb5d1f090d735dbfb1236`
- `flutter_service_worker.js`: `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c`
- `manifest.json`: `9cd22466de94f77b60a5545f0ba2f2c6fda19f0ece2e0d232fca7b875cdd000c`

The root, About, Profile, notification preferences, Analytics, Workforce,
Rentals, Material Requests, Company Material Request composer and Team Chat
routes all returned the byte-matched Flutter entrypoint. PWA assets, Firebase
worker and deferred JavaScript parts also byte-matched.

An authenticated browser witness rendered the refreshed Audit workspace with
637 matching events, opened the event investigation panel and showed its
recorded facts, copy-ID action and same-record history. The same session opened
the Company Material Request composer with the category/unit, beneficiary,
receiver, purpose, handover, timing, item and guarded submit controls visible.

## Production preservation and acceptance boundary

The production deployment remained `dpl_EFMtEEvZrhMcjttQbSFQZCXjzV6y` before
and after this preview release, and its root continued to return HTTP 200.
This evidence proves deployment, backend binding, access probes, route delivery
and authenticated rendering. It does not replace the product owner's manual
multi-persona workflow acceptance; staging remains available for that testing.
