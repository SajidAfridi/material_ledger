# My Yorks P06 staging UAT candidate

Candidate deployed: 5 September 2026 at `2026-09-05T13:02:38Z`  
Status: **ready for product-owner UAT; manual UAT not yet passed**  
Baseline commit: `f37ee8a405158864465606202166451c3db0809b` plus the
reviewed P01-P05 working-tree slice  
Production boundary: no production database, Vercel alias, GitHub branch or
production configuration was changed.

## Candidate identity

| Evidence | Result |
|---|---|
| Dedicated Supabase staging project | `iqltcyimlqtcwyzlemwx` (`yorks-r35-staging`) |
| Applied migrations | `20260905120000_yorks_my_profile_p01.sql` and `20260905130000_yorks_my_profile_p04_p05_workspace.sql` only; post-deploy ledger is aligned through `20260905130000` |
| Protected document function | `finalize-document-upload` version 2, active, JWT verification enabled |
| Vercel deployment | `dpl_CUgKWHWDeaA4avyFQpqrdorotz1D`, Ready, Preview and unaliased |
| UAT URL | `https://yorks-r35-6uef8dgdc-sajid-alis-projects-0ec775a2.vercel.app/#/profile` |
| Feature configuration | Accounts, Workforce and Analytics enabled; staging project ref occurs once in the client bundle; production and CI refs occur zero times |

## Artifact and route proof

| Artifact | Bytes | SHA-256 | Hosted result |
|---|---:|---|---|
| `main.dart.js` | 9,808,141 | `9fd7f3e4687d4c13ff801286d7399e82b56eff654da19b9737d43f8ca0008d00` | byte-matched |
| `index.html` | 7,488 | `8fd010a275a733516a37bc192d5d2120328288e0d7de7efe20bba38353f9227a` | byte-matched after the allowed Vercel Preview toolbar line is removed |
| `manifest.json` | 1,008 | `0ceffe4b72dab90dd5364dac622de18417dd32bb5432f553a763253a89cbfcbb` | byte-matched |
| `flutter_service_worker.js` | 784 | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` | byte-matched |
| `flutter_bootstrap.js` | 13,784 | `1040a421cc1e7d1e572c4505984d997aec8e1cbe9d02b648206226ae64c54273` | byte-matched |

Direct unauthenticated HTTP checks returned 200 for `/`, `/profile` and
`/#/profile`. The release verifier also byte-matched `/`, Material Requests,
Team Chat, `main.dart.js`, Flutter bootstrap/service worker, Firebase messaging
worker and the web manifest.

## Database and security proof

- The deploy preflight showed exactly the two reviewed profile migrations as
  pending; no other migration was applied.
- After deployment, both migration versions appear on the remote ledger.
- `v1_get_my_yorks_profile(integer, integer)` and
  `v1_get_my_yorks_profile_workspace()` are `SECURITY DEFINER` functions with
  empty `search_path`, executable by `authenticated`, and not executable by
  `anon` or `public`.
- The focused hosted pgTAP wrapper did not execute assertions because the
  hosted project has no persistent pgTAP extension and the CLI wrapper does
  not carry the local `extensions` search path into its container. This is
  recorded as a runner limitation, not a pass. The same profile database
  suites passed locally before deployment: 32 focused assertions and the
  complete 89-file, 2,631-assertion database gate.

## Local acceptance inherited by this exact source slice

- combined P01-P05 profile model, repository, controller, role, state,
  responsive, accessibility and golden rerun: 101 passed immediately after the
  staging build;
- focused P04/P05 Dart and widget tests: 18 passed;
- responsive and accessibility profile regression: 29 passed;
- complete Flutter suite: 1,627 passed;
- Flutter analyzer: no issues;
- production-shaped web and ephemeral-signed Android build gates: passed;
- desktop, tablet portrait/landscape, phone portrait/landscape, Arabic RTL and
  200% text visual evidence: reviewed.

The staging build was rebuilt from the same source using the ignored staging
configuration. Its startup budget passed at 9,808,141 bytes for
`main.dart.js` and 2,656,248 bytes gzipped.

## Product-owner UAT checklist

Use real non-production accounts for the role being checked. Do not reuse a
production password in staging.

1. Open the UAT URL on desktop, tablet and phone, then sign in.
2. Open My Yorks from the account launcher and confirm the same `/profile`
   destination opens from every entry point.
3. Confirm name, exact role and job title are correct and remain visibly
   separate.
4. Confirm **Today**, **Access & scope**, **Quick actions**, **Work identity**,
   **Preferences** and **Security & help** show only information that account
   is allowed to see. An unavailable fact must say it is unavailable, not show
   a false zero.
5. Change a staging permission, use **Refresh access**, and confirm links and
   scope update without signing out.
6. Check English and the configured secondary language, including one RTL
   language; test phone rotation and larger text.
7. Briefly disconnect the network, confirm the page explains the stale/offline
   state, reconnect, refresh, and confirm recovery.
8. Sign out and confirm the shared confirmation appears and the protected
   profile cannot be reopened with the browser Back action.

Record any mismatch with the account role, screen size, language, action taken
and a screenshot. P06 becomes accepted only after this named-persona UAT has
passed on deployment `dpl_CUgKWHWDeaA4avyFQpqrdorotz1D` with no open P0/P1
defect.

## Containment and rollback

This deployment is an isolated Preview with no production alias. Containment
is to stop using this URL and retain the deployment for diagnosis. The two
profile migrations are additive; if a defect is found, revoke their
authenticated execute grants and ship a reviewed forward correction rather
than deleting account, permission, project or Workforce history.
