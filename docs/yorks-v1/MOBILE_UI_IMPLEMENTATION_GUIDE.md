# Yorks Mobile UI Implementation Guide

Status: **implementation contract**
Reference pack: **Yorks Mobile UI Design Pack — R38 Native Adaptation**
Reference viewport: **390×844 logical pixels**
Secondary acceptance viewport: **360×800 logical pixels**

This guide controls the incremental mobile-only convergence of the existing
Flutter application to the approved 52-screen design pack. It is an
implementation aid, not a new source of workflow, authorization, quantity or
document truth.

The screen-by-screen delivery state is recorded in
[`MOBILE_UI_SCREEN_LEDGER.md`](MOBILE_UI_SCREEN_LEDGER.md). Evidence for the
current ten-screen slice starts under
[`evidence/mobile-batch-02/`](evidence/mobile-batch-02/README.md).

## 1. Source identity

The external pack used for this program is identified by the following full
SHA-256 fingerprints. A changed hash is a new design input and requires a
review before implementation continues.

| Artifact | SHA-256 |
|---|---|
| `screen_manifest.json` | `7487b4233b5b7179a8cc572fc3b54068380704badf3bb464d74d69223d34c18c` |
| `design_tokens.json` | `a9e055732f548ced2f18fc6facd29c822397fe1a6985f950d5d65faae3c54694` |
| `docs/MOBILE_UI_CONTRACT.md` | `778800cb866b90693c265218be1e40c6dbf9a49ecb811d29ebd98f1cb388911c` |

## 2. Authority split

The repository authority order in [`README.md`](README.md) and
[`SOURCE_OF_TRUTH.md`](SOURCE_OF_TRUTH.md) remains unchanged.

| Layer | Authority |
|---|---|
| Mobile design pack | Phone composition, hierarchy, density, shape, color and interaction presentation |
| Flutter | Existing routes, responsive composition, accessibility, controllers and application state |
| Supabase/Postgres | Auth, RLS, RPCs, quantities, versions, idempotency, audit, documents and committed workflow truth |

The HTML references are visual fixtures only. Never copy their JavaScript,
static values, sample role, sample quantity or displayed status into Flutter as
business logic. Existing Flutter presentation is not a visual oracle merely
because its controllers already work.

Every implementation must preserve the production path:

`Widget -> Riverpod controller -> repository -> authorized query/RPC -> Postgres`

Widgets must not call Supabase directly, manufacture a server-success state or
change a protected record without its existing controller/repository command.

## 3. Approved production exceptions

These exceptions override literal screenshot parity:

- Do not add weighted project progress or completeness. It is not part of the
  V1 readiness model.
- Accounts references 42–47 are not production surfaces until Accounts is
  separately implemented and authorized. Do not add dead navigation, sample
  financial data or placeholder commands.
- Do not invent statuses, owners, counts, activity, warning totals or success
  messages to fill a reference composition. Loading, unavailable and error are
  distinct from zero or empty.
- BOQ and controlled-document fields remain dynamic and capability-safe.
  Commercial fields must be absent, not masked or zeroed, when the authorized
  server response does not contain them.
- BOQ Overview is summary-only. It is never an editable aggregate, MR source or
  direct export source. Common remains a real independent scope.
- Dynamic imported columns and raw source values remain intact. A visual
  template must not coerce, drop or silently standardize them.
- Project Creation date controls must wrap without the clipping present in an
  older desktop reference.
- Mobile navigation stays one row, uses equal bounded destinations with at
  least 44×44 semantic targets, and never covers scroll content or actions.

## 4. Mobile-only isolation boundary

Use `YorksMobileUi.isActive(context)` from
`lib/core/widgets/yorks_mobile_ui.dart` as the production branch guard. Its
current boundary is **720 logical pixels or narrower**. The pack describes a
broader conceptual phone range, but changing the repository breakpoint would
alter accepted tablet/web behavior and is outside this mobile convergence
program unless separately approved.

Rules:

- Put new composition behind the guard at the highest safe presentation-only
  branch point.
- Preserve the existing widget tree at widths above the guard.
- Do not change shared desktop tokens to force mobile parity. Add or reuse
  mobile tokens/components instead.
- Keep the same route, provider family, controller instance, repository and
  callback on both branches.
- Do not create a second mobile business model or shadow workflow state.
- Do not add a child bottom navigation when the workspace shell already owns
  it. Editor/wizard screens use focused Back navigation and a safe sticky
  action area where appropriate.
- Give scrollable content enough keyboard, safe-area and shell-navigation
  inset to expose the final field, help text, table row and action.

Prefer small shared primitives in `lib/core/widgets/yorks_mobile_ui.dart` and
feature-local mobile compositions. A shared primitive belongs in the core file
only when at least two production surfaces use the same semantics.

## 5. State and permission preservation checklist

Complete this inventory before changing any target screen.

### Identity and permission

- [ ] Identify every allowed exact Auth role and every denied role.
- [ ] Preserve project-membership, organization-wide role and capability
      checks already supplied by production providers.
- [ ] Keep UI permission checks as preflight only; trusted RPC/RLS remains the
      enforcement boundary.
- [ ] Do not widen safe-directory, commercial, document or project reads just
      to populate a reference card.
- [ ] Keep read-only, archived, legacy/unassigned and lifecycle restrictions
      visible and non-editable.

### Data and async state

- [ ] Render loading, data, empty, failure and retry separately.
- [ ] Do not turn a failed or not-yet-loaded provider into `0`, `[]`, “None” or
      a successful empty state.
- [ ] Preserve refresh/retry actions and stale-version behavior.
- [ ] Keep arbitrary columns, exact decimal values, row lineage, scope IDs,
      canonical mappings and server versions unchanged.
- [ ] Never add fields that the authorized projection omitted.

### Draft and command state

- [ ] Distinguish Local Draft, Saving, Saved to server, Waiting to Sync,
      Offline, Conflict, Save Failed and Retry.
- [ ] A critical action reports success only after the server confirms it.
- [ ] Keep the same idempotency key across a safe retry of the same command.
- [ ] Preserve local edits on conflict/failure where the existing controller
      does so; do not silently reload over them.
- [ ] Keep Cancel/Back non-mutating unless the current production flow
      explicitly confirms discard.
- [ ] Disable duplicate submission while a command is pending.

### Action and transition

- [ ] Map every visible button to an existing route or callback.
- [ ] Hide or clearly disable an action when no production command exists.
- [ ] Preserve required confirmations, reasons, quantity caps and validation.
- [ ] Preserve current-owner, next-action and audit language from authorized
      data.
- [ ] Test both the authorized success path and an unauthorized/server-denied
      path for access-sensitive changes.

## 6. Component and interaction rules

- Use the shared mobile app bar, cards, section headers, pills, status and
  metric primitives before creating a screen-local copy.
- Use the pack tokens as the mobile visual target, translated through central
  Flutter tokens. Avoid scattered literal colors, radii and spacing.
- Use compact lists/cards for phone browsing. Do not squeeze a desktop
  spreadsheet into the primary mobile editing path.
- BOQ editing uses one focused row editor. It must render the real dynamic
  worksheet columns and stage changes through the existing BOQ controller.
- A row-editor Save may stage local worksheet changes; it must not claim
  “Saved to server” until the worksheet command succeeds.
- Excel import remains local and reversible through file, sheet/mapping and
  review steps. Only the final Import action invokes the existing trusted
  import command once.
- Use platform file/date/share behavior where the production feature already
  supports it. Keep active fields visible above the keyboard.
- Every target has a 44×44 minimum semantic hit area, visible focus, text-scale
  tolerance, non-color status cues and reduced-motion compatibility.

## 7. Screen implementation workflow

For each ledger reference:

1. Read the PNG, corresponding HTML and manifest/coverage row.
2. Map it to the current Flutter route, widget, providers, controller,
   repository and tests. If no production surface exists, mark it deferred; do
   not implement a decorative shell.
3. Enumerate all state, role, capability and action variants using the
   checklist above.
4. Capture Flutter Before with deterministic, equivalent fixture data.
5. Implement the phone composition behind `YorksMobileUi.isActive` while
   reusing the existing state and callbacks.
6. Verify Back, keyboard, scroll extent, safe area, bottom navigation, pending
   actions, errors and retries manually.
7. Capture Flutter After and image comparisons at 390×844 and 360×800.
8. Run focused tests, formatting, analysis, full tests and applicable release
   builds. Record results without hiding unrelated failures.
9. Update the ledger only after evidence identifies the implementation commit.

## 8. Visual evidence contract

Every implemented surface requires, at each accepted viewport:

- rendered design reference;
- Flutter Before;
- Flutter After;
- side-by-side comparison;
- alpha overlay or pixel/image diff;
- a measurable delta table covering position, size, typography, padding, gap,
  border, radius, color, shadow, density and controls;
- remaining differences, each classified as global token, shared component,
  screen-local or intentional production exception.

Use deterministic fixture state and the exact same viewport for both sides.
Do not say “pixel perfect”, “parity” or “verified” without this evidence. The
directory and naming convention for Batch 2 is documented in
[`evidence/mobile-batch-02/README.md`](evidence/mobile-batch-02/README.md).

## 9. Test and release gate

Run focused widget/controller/golden tests while iterating. Before accepting an
implementation batch, run the complete applicable repository gate:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-web
CI=true YORKS_CI_EPHEMERAL_SIGNING=true \
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid \
SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-apk
```

For a database-affecting batch, also run the tracked local reset and database
tests. A visual-only batch must not modify migrations, RPCs or RLS unless a
separate functional defect is documented and approved.

## 10. Definition of done

A mobile screen is verified only when:

- the ledger maps it to a real production surface;
- all authorized, denied, async, offline, pending, success, empty, error and
  conflict variants relevant to that surface remain wired;
- 390×844 and 360×800 evidence is reviewed;
- keyboard, semantics, text scale, safe areas and navigation inset pass;
- focused and full gates pass or an unrelated baseline failure is clearly
  recorded;
- the accepted desktop/web surfaces remain unchanged;
- no production workflow or protected response shape was weakened.
