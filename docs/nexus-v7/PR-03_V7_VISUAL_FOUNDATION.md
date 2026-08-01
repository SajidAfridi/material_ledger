# PR-03 — Yorks Nexus V7 visual foundation

Date: 24 July 2026  
Status: complete

## Scope

This slice establishes the approved V7 visual implementation base without
changing a workflow, route, provider, database schema or feature flag.

The source baseline is `docs/nexus-v7/design/source/styles.css`, reviewed
against the approved desktop and mobile previews in
`docs/nexus-v7/design/previews/`.

## Token mapping

- Ink: `#132033`
- Secondary ink: `#34435A`
- Muted: `#6B788C`
- Primary action navy: `#0D2F57`
- Interaction blue: `#1D68D9`
- Success: `#0D8B63`
- Warning: `#AD6A00`
- Error: `#C23737`
- Canvas: `#EEF3F8`
- Panel: `#FFFFFF`
- Line: `#DCE3EC`
- Standard card radius: `14`
- Desktop page maximum: `1740`
- Desktop inspector: `330`
- Responsive breakpoints: `720`, `980`, `1180`
- Minimum touch target: `44`

These values live in `lib/core/constants/`. Compatibility aliases remain for
existing screens so later slices can migrate incrementally.

## Shared implementation

- `AppTheme` now defines V7 bordered panels, compact rectangular actions,
  outlined fields, status chips, data-table surfaces and quiet separators.
- `PrimaryButton`, `SecondaryButton` and `LedgerCard` retain their existing
  public APIs while using the V7 shape and surface language.
- `NexusPageShell` and `NexusPageHeader` provide desktop, tablet and mobile
  containment. The inspector remains 330 px on desktop and stacks after the
  primary content below 980 px.
- `NexusSectionCard` provides the standard section header/body contract.
- `StatusChip` supports explicit information, success, warning, danger, purple,
  neutral and outline tones.
- `CurrentActionCard` makes current state, action context and owner visible.
- `AuditMeta` and `AuditTrailItem` keep actor, role and timestamp attached to
  the action.
- `NexusSans` and `NotoSansArabic` use repository-owned font assets so browser,
  offline and golden rendering do not depend on a font network request.

All user-facing copy is supplied by feature callers; the shared widgets do not
introduce hard-coded workflow labels.

## Verification

- Exact palette and workspace geometry assertions.
- Current state, current owner and actor/role/time widget assertions.
- 44 px minimum touch-target assertions.
- Desktop fixed-inspector layout assertion.
- Tablet and mobile stacked-inspector assertions.
- Human-readable 1280×800 desktop golden.
- Human-readable 390×844 mobile golden.
- `flutter analyze`: zero issues.
- `flutter test`: 289 passed.
- `flutter build web --release` with non-secret CI Supabase placeholders:
  passed.
- Both generated golden images were visually inspected against the approved V7
  previews.

## Security and data review

This slice adds no data access, mutation, route or backend policy. Commercial
payload boundaries and Supabase RLS from PR-02 are unchanged. Cost visibility
is therefore neither broadened nor inferred by these visual components.

## Migration and rollout

There is no data migration. New workflow screens should consume these shared
components one controlled slice at a time. Existing V7 feature flags remain off
until their owning vertical slice passes acceptance.

## Rollback

Rollback is code-only:

1. revert the PR-03 token/theme changes;
2. revert the shared V7 component files and barrel exports;
3. remove the V7 font registrations and golden test/baseline files.

No Supabase or stored-data rollback is required.
