# Yorks privacy-safe product analytics

Status: implemented behind an explicit opt-in; disabled by default. Session
replay and PostHog exception autocapture are not enabled.

This document governs external product telemetry. It is separate from the
Yorks `YORKS_V1_ANALYTICS` feature, which is the protected, server-authoritative
operational reporting workspace backed by
`v1_get_operational_analytics_foundation`.

## Goals and non-goals

The integration answers a small set of product questions:

- Which role-safe workflows are entered and completed?
- Where do users abandon Material Request, arrangement, approval and dispatch?
- Which server-confirmed operations are slow or fail by category?
- Where do search and action feedback create measurable friction?
- Do explicitly reviewed feature-flag variants improve completion?

It does not reproduce Yorks business data in PostHog. It is not an audit log,
stock ledger, workflow authority, error-reporting replacement, employee
monitoring system or source for commercial reporting. Supabase/Postgres remains
authoritative for business state and Sentry remains the crash-reporting tool.

## Architecture

The path is:

`route/controller/repository -> AnalyticsService -> privacy guard -> PostHog sink`

`AnalyticsService` is injected through Riverpod. The application creates one
`GuardedAnalyticsService`; disabled, invalid, CI and unsupported-platform builds
are no-ops. Calls are queued in a bounded in-memory buffer until initialization
finishes, serialized to preserve identity/reset order, and never awaited by a
business command. SDK setup or transport failure is swallowed at the analytics
boundary and cannot change authentication, navigation, RPC or storage results.

Navigation is observed once at the root `GoRouter`. `AnalyticsRouteMapper`
converts the URI path to a fixed `AnalyticsScreen` value before capture. It does
not retain query parameters, UUIDs, project references, request IDs, supplier
IDs, conversation IDs or document IDs. Widget rebuilds do not emit duplicate
screen events.

The web SDK is initialized manually from the build-time configuration. Browser
autocapture, page views, page leave, dead-click capture, performance capture,
surveys and replay are disabled. A final JavaScript sanitizer removes URL,
pathname, host, referrer and title properties that the Flutter web bridge adds.
Android and Apple native auto-init are also disabled so capture cannot start
before Yorks applies its runtime policy.

## Identity lifecycle

- Before authentication, any allowed sign-in attempt event uses PostHog's
  anonymous identity.
- After a connected session is verified, `identify` receives only the stable
  Supabase Auth UUID (`auth.currentUser.id`) and the exact server-controlled
  `app_metadata.role` claim.
- Email, name, phone, editable user metadata, profile fields and project
  membership are not person properties.
- Local-demo user IDs are never sent as external analytics identities.
- Sign-out, rejected restore, remote sign-out and local session clearing call
  `reset()` so another person cannot inherit the previous identity.

## Configuration and environments

The canonical launcher accepts these build values:

| Variable | Meaning | Default |
|---|---|---|
| `POSTHOG_ENABLED` | Explicit telemetry opt-in | `false` |
| `POSTHOG_PROJECT_TOKEN` | Environment-specific public project token | blank |
| `POSTHOG_HOST` | Explicit HTTPS ingestion host; override for the project's region | `https://us.i.posthog.com` |
| `POSTHOG_ENV` | Analytics environment; must match `R35_ENVIRONMENT` (`development` is accepted for local) | `R35_ENVIRONMENT` |
| `POSTHOG_DEBUG` | SDK debug logging; accepted only in local debug builds | `false` |
| `R35_ENVIRONMENT` | Yorks environment: `local`, `staging`, `production`, or `ci` | required by launcher |

Example operator-only `.r35.staging.env` values:

```dotenv
POSTHOG_ENABLED=true
POSTHOG_PROJECT_TOKEN=phc_replace_with_staging_project_token
POSTHOG_HOST=https://us.i.posthog.com
POSTHOG_ENV=staging
POSTHOG_DEBUG=false
```

Use separate PostHog projects and tokens for staging and production. CI is
always forced off. The launcher rejects a blank token, a non-HTTPS host, an
environment mismatch, or debug logging outside local development. Tokens
belong only in the ignored operator file or deployment environment, never
committed source.

Before production enablement, the release owner must confirm the intended
PostHog region, retention period, access group, data-processing terms and which
staff may view person-level events. The PostHog project token is not a
service-role credential, but it is still environment-specific configuration.

## Data contract

The source of truth is
`lib/shared/models/analytics_event.dart`. Event and property keys are enums;
feature call sites cannot invent arbitrary keys. The service accepts only
booleans, non-negative finite numbers, enums and short categorical strings
matching `A-Z`, `a-z`, `0-9`, `_`, `.`, `+` or `-`. Longer text, spaces and
email-shaped/free-text values are dropped. PostHog has a second event/property
allowlist in `PostHogAnalyticsSink`.

Every event automatically includes:

| Property | Source |
|---|---|
| `schema_version` | analytics contract, currently `1` |
| `app_version` / `app_build` | build defines |
| `environment` | validated `POSTHOG_ENV` matching `R35_ENVIRONMENT` |
| `platform` | Flutter target |
| `role` | exact server-controlled role after identification |
| `screen_name` | last fixed route mapping, when available |

Allowed contextual properties are categorical dimensions and aggregates only:
`source`, `action_type`, `object_type`, `workflow`, `outcome`,
`error_category`, `result_count`, `item_count`, `building_count`,
`attachment_count`, `duration_ms`, `retry_count`, `attempt_count`,
`no_result_count`, `tap_count`, `operation_was_loading`, `cached`, `success`,
`feature_flag`, `variant`, `query_length_bucket`, `file_type`,
`file_size_bucket`, `inventory_action`, `arrangement_mode`, `request_timing`,
`entry_mode`, `list_filter`, `record_state` and `feedback_expected_ms`.

Never add any of the following, even hashed:

- email, name, phone, address, employee number or free-form user/profile data;
- project/client/supplier/company/building names or references;
- Supabase row IDs, request IDs, document IDs, storage paths or URLs;
- search text, MR descriptions, BOQ cell values, notes, reasons or chat text;
- filenames, document contents, commercial values, quantities tied to a record;
- access tokens, JWTs, keys, headers, exception messages or stack traces.

The Supabase Auth UUID is the one exception to the no-ID rule and may appear
only as PostHog's `distinct_id`, never as a custom event property.

## Event taxonomy

The allowlist contains 49 business and diagnostic events, within the approved
30–50 event budget. A `*_completed` event uses `success` and, only on failure,
the normalized `error_category`; raw server messages are never sent.

| Area | Events | Important properties |
|---|---|---|
| Authentication | `authentication_attempted`, `authentication_succeeded`, `authentication_failed`, `session_restored`, `user_signed_out` | `source`, `outcome` |
| Projects | `project_creation_started`, `project_creation_validation_failed`, `project_creation_attempted`, `project_created`, `project_creation_failed`, `project_opened`, `project_access_changed`, `project_updated`, `project_update_failed` | counts, `action_type`, `success`, `error_category` |
| Documents | `document_upload_attempted`, `document_upload_succeeded`, `document_upload_failed` | `object_type`, `file_type`, `file_size_bucket`, `duration_ms` |
| Material Requests | `material_request_started`, `material_request_item_changed`, `material_request_draft_saved`, `material_request_review_opened`, `material_request_validation_failed`, `material_request_submission_attempted`, `material_request_submitted`, `material_request_submission_failed`, `material_request_opened`, `material_request_action_started`, `material_request_action_completed` | `item_count`, `source`, `request_timing`, `action_type`, `success` |
| Approval | `approval_opened`, `approval_action_started`, `approval_action_completed` | `action_type`, `success`, `error_category` |
| Procurement | `procurement_request_opened`, `arrangement_started`, `arrangement_save_attempted`, `arrangement_save_completed`, `dispatch_attempted`, `dispatch_completed` | `item_count`, `success`, `error_category` |
| Inventory/search | `inventory_opened`, `material_search_completed`, `inventory_item_selected`, `inventory_action_started`, `inventory_action_completed`, `inventory_import_completed`, `material_search_struggle_detected` | query-length bucket, aggregate results, duration, action, counts |
| UX/performance/reliability | `ui_repeated_action_detected`, `ui_action_no_feedback`, `operation_completed`, `feature_flag_interacted`, `reliability_error` | action, screen, duration, loading state, normalized error category |

Current call-site status:

- Active: authentication/session/reset, central screens and entry events,
  project create/access, document upload, MR draft/item/submit/decision,
  arrangement begin/save/decision, dispatch, inventory mutation/import/search
  and generic operation timing.
- Available as explicit UI contracts: `material_request_review_opened`,
  `approval_opened`, `ui_action_no_feedback`, `feature_flag_interacted` and
  `reliability_error`. Emit these only at a semantically verified call site;
  their presence in the contract is not permission to infer an event from a
  widget rebuild or raw error.

The taxonomy intentionally contains no RFQ, quotation-comparison, Purchase
Order, supplier-portal or multi-warehouse event because those workflows are
outside approved Yorks V1 scope.

## Friction detection

The implementation avoids global tap capture and noisy heuristics.

- Repeated action: the same explicitly named action is invoked at least three
  times within two seconds. The event reports the action category, stable
  screen, tap count, elapsed milliseconds and whether a command was already
  loading. It does not record coordinates, labels or text.
- No feedback: a call site explicitly starts an expected-feedback timer and
  cancels it when visual/loading/navigation feedback is observed. If four
  seconds elapse, one event is emitted. It is not inferred from every button.
- Search struggle: within a 30-second material-search sequence, at least three
  completed attempts with at least two empty results, or 15 seconds without a
  selection, emits one event. Only attempt/no-result counts and duration are
  sent; the query is never retained or passed to analytics.

## Performance and reliability

`beginOperation()` measures elapsed client time around important repository or
controller work and emits `operation_completed` exactly once with `success`,
`duration_ms`, optional aggregate result count and a normalized failure
category. It does not attach the RPC name, URL, record ID, exception message or
stack. Telemetry initialization is post-frame, bounded and asynchronous.

The web startup gate retains the existing 2.9 MB gzip ceiling and adds only a
50 kB raw parse-size allowance for the typed analytics runtime. The checked
enabled build remains below both limits; the disabled build continues to
tree-shake the transport implementation.

Sentry remains the error tool with its existing privacy scrubber. PostHog's
Flutter error autocapture, platform-dispatcher capture, isolate capture and logs
are explicitly disabled to avoid duplicate reporting and accidental payloads.
The `reliability_error` contract is reserved for a reviewed, category-only
signal when an aggregate reliability question cannot be answered from
`operation_completed`.

## Feature flags

Call `AnalyticsService.isFeatureEnabled(AnalyticsFeatureFlag.someFlag)` only
for non-security presentation experiments. The enum is the allowlist. Missing,
late, failed and disabled flag reads return `false` within two seconds; the
control experience must always be complete. Flags must never grant a role,
project scope, commercial projection, route, workflow transition or stock
authority. RLS and trusted RPC checks remain authoritative.

## Session replay decision

Replay is intentionally off on web, Android and iOS. Default SDK masking is not
accepted as proof because replay capture bypasses the Dart `beforeSend` guard
and Yorks screens contain project, material, HR, chat and commercial context.

Replay may be reconsidered only in a dedicated staging PostHog project after:

1. a build uses manual SDK setup and explicit text/image/input masking;
2. representative Project, BOQ, MR, Inventory, Accounts, People and Chat screens
   are exercised with synthetic sensitive data on web, Android and iOS;
3. an authorized reviewer inspects the actual uploaded recordings frame by
   frame and confirms no text, image, canvas, platform-view or accessibility
   leakage;
4. network payloads are inspected for URL/query, identifier and metadata leaks;
5. the proof, SDK versions, sampling, retention and rollback switch are recorded
   in a review artifact and approved by the release owner.

Until that evidence exists, do not add `PostHogWidget`, do not turn on
`sessionReplay`, and do not enable recordings in the PostHog project.

## Exact PostHog project setup

Create the following in both staging and production projects, starting in
staging. Always add an `environment` filter so projects cannot be mixed.

1. **MR completion funnel** — ordered funnel:
   `material_request_started` → `material_request_submitted` →
   `arrangement_save_completed` where `success=true` →
   `approval_action_completed` where `success=true` →
   `dispatch_completed` where `success=true`. Show conversion and median time;
   break down by `role`, then `platform`.
2. **Project creation funnel** —
   `project_creation_started` → `project_creation_attempted` →
   `project_created`. Add a companion trend for
   `project_creation_validation_failed` and `project_creation_failed`, broken
   down by `error_category` and `platform`.
3. **Workflow success rate** — trend `operation_completed`; formula percentage
   with `success=true` over all operation events. Break down by `action_type`.
   Add p50/p95 `duration_ms` for each action and filter out local builds.
4. **Material search quality** — trend `material_search_completed`, show average
   `result_count` and p95 `duration_ms`; add `material_search_struggle_detected`
   and break down by `screen_name`, `query_length_bucket`, `role` and platform.
5. **Interaction friction** — combined trends for
   `ui_repeated_action_detected` and `ui_action_no_feedback`, broken down by
   `action_type`, `screen_name` and `operation_was_loading`. Alert on a
   week-over-week increase greater than 50% only when the weekly count is at
   least 20.
6. **Upload reliability** — formula success percentage using
   `document_upload_succeeded` over `document_upload_attempted`; companion
   failure trend by `file_type`, `file_size_bucket`, `object_type`, platform and
   `error_category`.
7. **Inventory command health** — trend `inventory_action_completed` and
   `inventory_import_completed`, split by `success`, `inventory_action`, role
   and platform. Add p95 duration from matching `operation_completed` events.
8. **Stable screen paths** — Paths insight using `$screen`; exclude
   `unknown`. Confirm nodes are fixed names only before saving the insight.
9. **Weekly meaningful retention** — returning identified users whose return
   event is one of `project_created`, `material_request_submitted`,
   `arrangement_save_completed` with success, `dispatch_completed` with success
   or `inventory_action_completed` with success. Do not use login alone as the
   return criterion. Break down by role; hide cohorts smaller than the
   organization's approved privacy threshold.
10. **Release comparison** — trend meaningful completion events, broken down by
    `app_version`, `app_build`, `platform` and `environment`. Use this during a
    staged rollout to spot a version-specific regression.

Dashboard layout:

- Row 1: MR completion funnel, project creation funnel, meaningful retention.
- Row 2: workflow success rate, operation p95, upload reliability.
- Row 3: search quality, interaction friction, inventory command health.
- Row 4: stable screen paths and release comparison.

Do not make dashboards that expose the PostHog distinct ID to broad viewers.
Use aggregate insights and role/platform/version breakdowns. Restrict person
inspection and exports to the smallest approved group.

## Verification and release checklist

- Run the analytics unit tests and route-mapping tests.
- Run `flutter analyze`, `flutter test`, the CI web/APK builds and
  `./tool/r35.sh build-ios --no-codesign` on a configured macOS build host.
- Build staging with its own token and verify events in PostHog Live Events.
- Confirm events contain no URL/path/query, names, emails, UUID properties,
  filenames, search strings, exception text or commercial values.
- Verify login identifies to the Supabase Auth UUID and logout immediately
  resets; repeat with two accounts on the same device.
- Verify disabled and misconfigured builds perform no capture and remain fully
  functional.
- Verify no `$autocapture`, pageview, lifecycle, survey, push, replay,
  `$exception` or log events appear.
- Verify every completion event follows observed server success/failure and is
  not emitted from optimistic UI state.
- Promote only after staging payload inspection. Enabling telemetry is a
  deployment configuration change; it does not authorize a production deploy.
