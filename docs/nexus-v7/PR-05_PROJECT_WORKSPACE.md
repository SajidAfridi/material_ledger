# PR-05 — Yorks Nexus V7 project workspace and readiness

Date: 24 July 2026  
Status: complete

## Scope

This slice makes the project the shared container for its existing connected
records. The route is:

```text
/projects/:id
```

It is available only while `NEXUS_V7_PROJECTS=true`. A disabled flag, missing
record or project outside an Engineer's assignment fails closed.

The workspace contains exactly:

1. Overview
2. Material Plan
3. Requests
4. Procurement
5. Documents
6. Activity

It does not create RFQ, Supplier Quotation, Purchase Order or Delivery Receipt
records. Those remain controlled later slices.

## Operational behavior

- Current action and responsible role are derived from project acceptance,
  Material Plan state and connected Material Request states.
- Assigned Engineer names are shown when the action belongs to Engineering;
  team ownership is shown for Procurement and Admin actions.
- Blockers are concrete conditions: missing Procurement acknowledgement, start
  date, physical building or Engineer assignment; unresolved plan changes;
  request hold; or project hold.
- Normal next work is not mislabeled as a blocker.
- Readiness is an explicit checklist for responsibility, building scope,
  Procurement acknowledgement, Phase 1 plan and execution. There is no
  weighted completion score or arbitrary percentage.
- Project status, buildings, plan version/counts, request status, attachment
  scope and actor/role/time remain visible from the same container.
- Existing controlled plan, request, receipt and Procurement routes remain the
  owners of workflow mutations. The workspace does not duplicate commands.
- RFQ and PO cards state that their models are not enabled in this batch. No
  placeholder records or misleading counts are fabricated.

## Role and navigation behavior

- The workspace provider derives from `visibleProjectsProvider`. Engineers
  cannot retrieve a guessed project id outside their assignment.
- Procurement and Admin receive the full project register.
- Engineer project cards open the workspace only when the V7 Projects flag is
  enabled; the legacy card behavior remains unchanged when it is disabled.
- Procurement's Materials hub now exposes the project register while V7
  Projects is enabled.
- Procurement can inspect projects but cannot see the destructive delete
  control. Project deletion remains Admin-only.
- A new Procurement project queue card opens the workspace; its explicit Accept
  button retains the existing single-step acknowledgement action.

## Responsive behavior

- Browser/desktop uses familiar horizontal workspace tabs and the V7 inspector
  rail for responsibility and audit metadata.
- Mobile uses one section selector instead of squeezing six desktop tabs.
- The inspector stacks below primary content on narrow layouts through the
  shared V7 page shell.
- All workflow links retain the shared minimum touch target.
- English remains primary and the selected secondary language remains visible.
  Arabic-script fallback explicitly uses the bundled deterministic font.

## Connected data and compatibility

`ProjectWorkspaceSnapshot` is read-only and derived from the current Project,
Material Plan, Material Request and audit providers.

- Material Requests match by stable `projectId`.
- Name matching is used only for legacy requests that do not yet have a
  project id.
- Audit entries match the stable project id and are sorted newest first.
- Project creation metadata supplies the foundational creation activity when
  present.
- Attachment metadata resolves its stable building id back to building code and
  name.

No persisted model version changed in this slice.

## Supabase review

No Supabase schema, Storage policy or RLS migration is required.

The workspace reads the same Supabase-backed operational stores already
hydrated through the existing Riverpod/outbox boundary. It adds no Data API
table, does not widen project visibility and does not move authorization into
the UI. Binary Documents remain disabled until normalized document metadata,
object paths and Storage policies are delivered together.

## Verification

- Current-action tests for acceptance, plan review and site receipt.
- Negative Engineer project-assignment test.
- Stable-id request relationship test with legacy-name fallback.
- Readiness state test with no weighted score.
- Feature-flag deep-link failure test.
- Six-register and desktop-inspector widget test.
- Building-scoped document and actor/role metadata test.
- Mobile-specific selector and overflow test.
- Route construction test for every role.
- 1280×900 browser golden.
- 390×844 mobile golden.
- Both goldens visually inspected after font rendering correction.
- `flutter analyze`: passed with zero issues.
- Focused Phase 5 and route tests: passed, 19 tests.
- Complete regression suite: passed, 318 tests.
- Release web build with non-secret CI Supabase placeholders: passed.
- `git diff --check`: passed.

## Rollout

The existing owning flag remains off by default:

```text
NEXUS_V7_PROJECTS=false
```

Enable it in the controlled Supabase environment only after Engineer,
Procurement and Admin personas validate project visibility, current ownership
and navigation.

## Rollback

Set `NEXUS_V7_PROJECTS=false`.

This removes workspace entry points, restores the legacy Engineer project-card
navigation and makes deep links fail closed. No data rollback is needed because
the slice introduced no persisted schema or workflow mutation.
