# P06 My Yorks settings and navigation hardening

Status: **implemented and locally verified; staging refresh pending**  
Date: 5 September 2026  
Production boundary: no production database, alias, branch or configuration
has been changed by this slice.

## Accepted product behavior

- The bell and existing Notification Centre are the one authorized inbox.
- My Yorks Notifications opens personal delivery controls for push, workflow,
  Team Chat, foreground pop-ups and sound. Required in-app history stays on.
- Preferences are per authenticated user, protected behind narrow RPCs and
  optimistic revision checks; direct client table access is denied.
- Company currency is read-only AED. Obsolete device currency state is ignored.
- App Lock is absent and an old stored enabled value is cleared safely.
- English, Arabic, Urdu and Hindi selection drives the shared shell, side rail,
  mobile bottom navigation and page controls with correct directionality.
- Header, keyboard/browser and system/gesture Back share session-scoped route
  history for workspace-root switches. Nested Navigator routes still pop
  natively.

## Local evidence

| Gate | Result |
|---|---|
| Clean `npx --yes supabase db reset --local` | Pass; the complete tracked migration chain, including `20260905170000_yorks_personal_notification_controls.sql`, replayed from zero |
| Focused notification database suite | Pass; 1 file, 16 assertions |
| Complete database suite | Pass; 90 files, 2,647 assertions |
| Focused notification model/controller/UI tests | Pass; English controls, saved change and Arabic RTL |
| Profile responsive/accessibility/golden suite | Pass; 29 tests after reviewed golden refresh |
| Route history and shell tests | Pass; bounded history, transient-query removal, desktop button, system Back, desktop side panel and mobile navigation localization |
| `flutter analyze` | Pass; no issues |

## Security and data preservation

The migration is additive and preserves every notification, read timestamp,
device token and audit/business record. Missing preference rows retain the old
enabled-delivery defaults. Push suppression never removes in-app history.
First writes serialize on the actor's protected profile row, repeated identical
commands are idempotent, stale different writes return a conflict, and the
existing company-wide notification policy remains the upper-level gate.

Rollback is forward-only: revoke the two authenticated preference RPCs and
restore the preceding enqueue/claim/device-registration function bodies. The
preference table can remain dormant; no business history needs to be deleted.
