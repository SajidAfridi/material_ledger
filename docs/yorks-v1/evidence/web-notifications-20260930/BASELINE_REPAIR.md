# Strict visual baseline repair

Unchanged production source b86ff4362cde5c214aaff2906c05b0adac258074
was tested in isolation: 1699 passed, 4 skipped, 271 failed.
Regenerating its baselines revealed two remaining non-visual failures:
the desktop BOQ Groups label and hashed release test-account define.
These are repaired narrowly. No unrelated primary-checkout work was imported.

307 PNG baselines were generated on that unchanged source. All 21 changes
at or above 1 percent differing pixels were inspected side-by-side. They
represent existing production layouts rather than new notification UI changes.
Most other differences are small text-rendering drift. A sampled Flutter
3.47.1 comparison reproduced the same differences; the cause is not attributed
solely to SDK version. Strict image equality remains enabled.

The candidate full suite passed 1984 tests with four existing skips. Its
notification goldens were separately updated and reviewed, with fixed dates.
CI is pinned to Flutter 3.47.5. Linux hosted CI has not been observed passing.

Local review contact sheets and pixel metrics are retained under
`/Users/eapple/Downloads/yorks-notification-implementation-20260930/`.
