# Yorks PostHog analytics

## Purpose

PostHog is the Yorks product/UX analytics layer. It answers whether staff can complete work confidently, quickly, and without avoidable friction. It is not an audit log, financial system of record, authorization mechanism, or replacement for Sentry.

## Configuration

Analytics is disabled when `POSTHOG_API_KEY` is absent.

Build-time values:

- `POSTHOG_API_KEY` — project token supplied by deployment/CI, never committed to this repository.
- `POSTHOG_HOST` — defaults to `https://us.i.posthog.com`.
- `POSTHOG_ENV` — use `development`, `staging`, or `production` consistently.
- `POSTHOG_DEBUG` — enable only for local troubleshooting.
- `APP_VERSION` and `APP_BUILD` — attached to every event.

Example local invocation:

```bash
flutter run \
  --dart-define=POSTHOG_API_KEY=<project-token> \
  --dart-define=POSTHOG_HOST=https://us.i.posthog.com \
  --dart-define=POSTHOG_ENV=development \
  --dart-define=POSTHOG_DEBUG=true
```

Use a non-production PostHog project/token for development and staging when available. Never use a production token in committed source.

## Architecture

`YorksAnalytics` is the only general-purpose PostHog facade. Feature code must not scatter direct `Posthog().capture(...)` calls.

The facade is best-effort. Analytics failures must never block or fail:

- sign in
- project/MR operations
- approvals
- procurement
- inventory
- accounts
- document operations
- navigation

Authenticated identity comes from the stable Supabase Auth UUID via `yorksV1AuthUserIdProvider`. The only person property currently sent is the Yorks role claim. Logout resets PostHog identity.

Every event receives:

- `yorks_environment`
- `yorks_app_version`
- `yorks_app_build`
- `analytics_schema_version = 1`

## Privacy contract

Do not send raw business or personal content to PostHog.

Prohibited by default:

- employee names, email, phone
- passwords, OTPs, access/refresh tokens
- project/client/consultant/contractor/supplier names
- invoice numbers or document contents
- filenames where they reveal business data
- bank, salary, price, cost, or amount values
- comments, notes, descriptions, or other free text
- raw search query text
- PDFs, attachments, images, or document previews
- raw Supabase/server exception messages

Prefer structured metadata such as:

- `role = project_engineer`
- `item_count = 12`
- `duration_ms = 842`
- `result_count = 4`
- `error_category = timeout`
- `stock_action = add_stock`

The central sanitizer is a second line of defense, not permission to pass sensitive values into the analytics layer.

## Screen privacy

Never send live Yorks URLs containing entity IDs directly as analytics screen names.

Use `yorksAnalyticsScreenName(...)` so examples such as:

- `/yorks/projects/<uuid>` -> `project_detail`
- `/yorks/material-requests/<id>` -> `material_request_detail`
- `/yorks/inventory/suppliers/<id>` -> `inventory_supplier_detail`

Unknown routes become `other` rather than leaking their path.

## Session replay

Session replay is intentionally **disabled** in the initial production integration.

Yorks contains commercially sensitive project, finance, workforce, supplier, invoice, and document information. Replay may be enabled only after all of the following are completed:

1. Enable it in a staging PostHog project first.
2. Keep `maskAllTexts = true` and `maskAllImages = true` initially.
3. Verify actual Android, iOS, and Web recordings visually.
4. For Flutter Web, configure and verify PostHog canvas masking before rollout.
5. Explicitly mask/exclude invoice, PDF, attachment, accounts, supplier, employee, document-preview, and other sensitive surfaces.
6. Review recordings for accidental business-data exposure.
7. Enable production replay only after privacy verification passes.

## Error tracking

Sentry remains Yorks' crash/error authority. PostHog Flutter automatic exception capture is disabled in this integration to avoid duplicate error pipelines and accidental transmission of unsanitized error content.

Product analytics may emit normalized failure events such as `material request submission failed` with `error_category = timeout`, but never raw exception bodies.

## Event naming

Use PostHog's object + verb convention with stable lowercase names, for example:

- `project created`
- `material request started`
- `material request submitted`
- `inventory search completed`
- `stock action completed`

Track intent and outcomes, not meaningless widget interactions. `submit button clicked` is usually inferior to `material request submission attempted` and `material request submitted`.

For critical operations distinguish:

1. attempted
2. completed/succeeded
3. failed

A tap is not a successful business transaction.

## Initial high-value taxonomy

Add these only where the real workflow exists and the trigger can be identified reliably.

### Authentication

- `user signed in`
- `user sign in failed`
- `user signed out`

### Projects

- `project creation started`
- `project creation validation failed`
- `project created`
- `project creation failed`
- `project opened`
- `project updated`
- `project attachment uploaded`
- `project attachment upload failed`

### Material Requests

- `material request started`
- `material request item added`
- `material request review opened`
- `material request validation failed`
- `material request submission attempted`
- `material request submitted`
- `material request submission failed`
- `material request approved`
- `material request rejected`
- `material request returned`

### Procurement / delivery

- `procurement request opened`
- `procurement action completed`
- `procurement action failed`
- `partial delivery recorded`
- `delivery completed`

### Inventory

- `inventory search completed`
- `inventory search no results`
- `inventory item selected`
- `material search struggle detected`
- `stock action started`
- `stock action completed`
- `stock action failed`
- `inventory import completed`
- `inventory import failed`

### UX friction

- `ui repeated action detected`
- `ui action no feedback`
- `form validation failed`
- `workflow abandoned`

### Performance

Use user-perceived operations with `duration_ms`, e.g.:

- `dashboard load completed`
- `project list load completed`
- `project detail load completed`
- `inventory load completed`
- `inventory search completed`
- `material request submission completed`
- `document upload completed`

Do not instrument mouse movement, every scroll, every keystroke, every rebuild, or each rendered row.

## Dashboards after first ingestion

Do not create analytics reports against invented event/property names. Once production/staging has ingested and verified the taxonomy, build:

1. **Yorks — UX Health**: repeated actions, validation failures, no-result searches, search struggle, slow operations, failed actions.
2. **Yorks — Material Request Funnel**: started -> item added -> review -> submission attempted -> submitted -> approved -> procurement -> delivery.
3. **Yorks — Performance**: p50/p95 operation durations, slowest operations, failures by app version/platform.
4. **Yorks — Inventory Intelligence**: searches, no-result rate, search-to-selection, struggle, stock actions/failures.
5. **Yorks — Reliability**: normalized failures, timeouts, uploads, permission failures, affected versions/platforms.

Primary success metrics should be workflow completion and friction-free workflow completion, not DAU alone.

## Before adding a new event

Check:

- Does it answer a real product/UX question?
- Is it an intent/outcome rather than widget noise?
- Could an existing event + property answer the question?
- Are all properties non-sensitive and structured?
- Can it fire exactly once at the correct lifecycle point?
- For a success event, has the backend operation actually succeeded?
- Will the event name remain stable if a widget/class is renamed?

If any answer is uncertain, do not add the event until the workflow is understood.
