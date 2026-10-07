# PR #53 recovery review corrections — 7 October 2026

The three P2 findings against `7a1e43d215a24d4b4afba7ce1f410dd320139fc2` were confirmed by tracing the recovery controller, global draft route and Save payload. They are client defects; this correction adds no database migration or production data cleanup.

## Corrected behavior

- **Accepted recovery baseline:** account recovery adoption and explicit Continue both set the accepted draft. Fresh-device recovery with 26 saved / 27 recovered lines can return without a false unsaved-changes prompt. Editing afterward and choosing Back → Discard restores the accepted 27 lines; it never calls the private-copy delete command.
- **Project revocation:** the comparison checks the recovered request's project, even on the global route. The controller provider observes permission, identity and role changes, immediately drops the protected server projection and invalidates in-flight reads. It retains owner-authored recovery and pending command intent. A newly authorized permission snapshot can re-fetch the comparison using the saved request's project context, including when local project selection is empty. Recovery denial does not replace ordinary draft error/retry handling. This is deliberately a narrow server-cache invalidation, not recreation of the draft controller from the app-wide cache list.
- **Complete comparison:** the view compares the non-commercial Save payload, matches lines by stable ID, and shows saved/recovered values for changed header fields, timing/date, delivery note, technical attributes, quantity, unit, source and order. Additions/removals are explicit; absent values say “Not set / cleared.” Project/scope changes are shown but do not bypass existing Save guards. Commercial fields never enter the comparison. Continue adopts the reviewed version; subsequent Save still uses server authorization and version checks.

## Regression evidence

- Fresh-device widget regression: 26 saved / 27 account-recovered lines → Continue → Back without edits; then edit → Back → Discard. Both preserve 27 device lines and issue zero account deletions.
- Global-route revocation widget regression: remove the saved request's project access while retaining another project's access and leaving the local project selection empty; comparison and controller server cache disappear immediately, local recovery stays intact, and regrant re-fetches the comparison.
- Controller regression: a protected request response arriving after revocation cannot repopulate the cache or authorize Continue.
- Comparison widgets: delivery-note-only difference, individually cleared model/size/equipment tag/planning tag/brand, and timing/cleared date. Commercial sentinel values remain absent.
- Updated, visually inspected [360px](../../test/goldens/r35/mr_recovery_review_360.png) and [1366px](../../test/goldens/r35/mr_recovery_review_1366.png) review evidence.

Validation: `flutter pub get`, changed-file format check, `flutter analyze`, and the full `flutter test` suite passed (**2,519 passed, four retained skips**). CI web build/startup budget passed (9,883,454-byte main bundle; 2,847,296 bytes gzip). The ephemeral CI-signed Android release build passed (111.9 MB); this is not a store-signed production APK. `git diff --check` and document links passed. No SQL changed, so database tests from the underlying repair were not rerun for this client-only correction. The earlier [database cleanup and release record](MATERIAL_REQUEST_DRAFT_REPAIR_20261007.md) remains historical evidence for that release, not proof that this follow-up is live.

## Preservation and rollback

No normalized request, line, archive, private account copy or migration is changed by this correction. Local unsaved input remains owner-scoped. Keep the database repair and archives from PR #53; a client rollback must not reinstate destructive recovery behavior. Browser/device acceptance and future production error rates remain distinct from automated regressions.
