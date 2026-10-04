# Direct project navigation and fresh Create — 4 October 2026

Status: implementation and local Flutter gates passed; staging delivery in progress.

## Later product-owner correction

The owner removed the Project created screen. This supersedes the earlier
desktop/mobile confirmed-result presentation and sticky-completion behavior.
Confirmed creation/update now opens the authorized project directly, with
Projects as the fallback when the actor cannot open that project. An uncertain
core outcome remains guarded; there is no optimistic navigation or new intent.

## Cause and correction

The old active proposal retired only after activation and every file finished.
Its `latest_operation` pointer restored a prior confirmed core whenever any
follow-up remained pending. The next Create therefore reopened that result.

A durably acknowledged core now releases its matching proposal independently
of pending follow-up. The exact journal, command keys, confirmed result,
attachment hashes/manifests and tombstone remain stored. A project-scoped
recovery locator is acknowledged before the slot is freed. New Create skips
confirmed prior-core pointer fallback while retaining the original unresolved
core guard. Historical confirmed proposals are rotated without server replay.

When reconciling an earlier original intent against a different current
proposal, only the historical project locator is added. The different proposal's
input, ID, writer epoch and envelope remain untouched. Historical recovery
cannot replace the active latest-operation pointer or use a disposed owner.

Pending activation/files are available separately in the existing project's
Edit view. Explicit actions use the original intent, file key and content hash,
with current owner, capability, membership and file-classification checks.
Opening the view does not dispatch or upload. Changed file bytes are refused;
uncertain uploads cannot be removed as though they were uncommitted selections.
Unpublished edit input remains independent of these actions.

The ordinary universal Yorks header/sidebar remain the route wrapper. Setup
supplies content only. The owner's screenshot shows the former navy feature
header, which is absent from the current routed source. Fresh HTTP assets match
the previous verified correction; an already running older tab does not replace
its JavaScript merely because the alias changes. No cache/draft wipe, Firebase
unregistration, automatic reload or global update framework was added.

## Local validation

- Dependency resolution passed; lockfile unchanged.
- Formatting gate: 14 changed Dart files, zero remaining changes.
- Full analyzer: no issues.
- Full Flutter suite after the live ownership correction: **2,330 passed,
  four retained skips**.
- Flow/workspace/desktop/mobile regression and interaction coverage: **128
  cases** in the complete passing gate; the focused flow/workspace rerun passed
  86 before the final Retry race case was added.
- Draft/recovery suite now includes **56 cases** in the complete passing gate.
- Project-linked recovery widget: **12 passed**, including original keys/hash,
  denied/stale permissions, owner switch, classification redaction, independent
  edit input and 360px RTL at 200% text with 44px actions.
- Exactly three Review hint goldens were deliberately updated and visually
  checked: desktop and mobile top/bottom. No other baseline changed.
- Candidate CI web passed after the live ownership correction: main 10,011,592
  bytes, verifier gzip 2,882,734.
- CI release APK passed; Android v2 signature verified with the ephemeral
  `Yorks CI Ephemeral` certificate. This is a CI artifact, not a production
  signing lane or an Android release.

There are no SQL, RLS, server-role, server-command or production data changes.
No database reset/deployment or fresh live Create/Update/upload acceptance is
inferred from the local gates. The prior accessibility-enabled breakpoint resize
semantics issue remains an open gate; this change does not alter Flutter/semantics.

## Staging delivery

The first preview from `45367b48` exposed an additional installed-browser edge
during the live check. Its confirmed create envelope was schema 2 with an exact
journal, retained writer and epoch 1; the fresh page was another writer. The
automatic history-release branch hid the normal ownership takeover control,
then its fenced retirement failed. The generic catch incorrectly described that
failure as an undecodable record. The ownership guard is corrected before final
acceptance: loading waits for the claim, another owner keeps the explicit
localized Take over draft action, and only a writable owner releases history.
No automatic ownership theft or command replay is introduced.
The added desktop and 360px regressions cover delayed ownership initialization,
explicit takeover, a still-live former writer, exact private manifest/journal
retention and zero remote commands. A local retirement write failure followed
by another writer before Retry exposes takeover instead of acquiring ownership.

Final source, artifact/deployment identity, unchanged production proof, desktop
and 360px browser evidence will be recorded after verification. Staging only
remains authorized; production is unchanged by this task.

Rollback preserves all draft/journal/quarantine/tombstone and completed-project
recovery namespaces. The previous verified staging deployment or default-off
candidate flag restores presentation without deleting historical records.
