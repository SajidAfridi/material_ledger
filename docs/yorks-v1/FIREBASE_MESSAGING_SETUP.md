# Yorks Firebase Cloud Messaging setup

Firebase is **push transport only**. Supabase Auth, RLS, records and audit
remain authoritative. The app uses the registered Yorks Firebase project
`yorks-48c40` for Android (`com.yorks.app`), iOS (`com.yorks.app`) and web.

## Application behavior

- Firebase initializes at application launch and reads the current permission
  without opening a prompt. Chrome, Android and Apple permission is requested
  only from the user's explicit **Enable device alerts** action so browser
  gesture requirements are satisfied. Every signed-in, supported but
  unregistered installation receives a global, session-dismissible setup
  banner; the same recovery control remains available in the notification
  centre and Team Chat. An already-authorized FCM token is registered only
  after the Yorks user is known; token refresh and foreground resume repeat
  that owner-bound step.
- Token and message-payload diagnostics are emitted only in debug builds. FCM
  payloads must never contain commercial or other protected values.
- Foreground FCM messages and recipient-scoped Realtime refreshes converge on
  one de-duplicated in-app alert with visible copy, navigation, haptic feedback
  and a short tone. Background/terminated notifications use the Yorks system
  channel and retain safe deep-link behavior. A foreground Team Chat transport
  row also produces its alert from the protected Supabase feed, so a temporary
  FCM registration failure does not make an open app silent. Browser/OS focus,
  notification and sound settings remain authoritative.
- Web uses one service worker that includes Flutter's generated cache worker
  and FCM background handler. This avoids either worker replacing the other.
  The worker updates the installed-PWA badge while the app is closed.

## Trusted delivery path

Workflow RPCs and Team Chat insert recipient-specific rows into
`v1_notifications`. An
insert trigger creates exactly one durable `v1_notification_push_outbox` job;
Postgres invokes `send-push` with only that notification UUID and a
Vault-managed webhook secret. The Edge Function claims the job atomically,
derives the recipient and non-commercial copy from protected server data,
sends through FCM HTTP v1, removes stale tokens and records a terminal or
retryable result. A one-minute `pg_cron` job retries failed or expired leases.
The claim derives the recipient's current workflow plus unmuted Team Chat
unread count on the server. Android receives `notification_count`, Apple
receives `aps.badge`, and web receives the same count for its service-worker
Badging API update. Device-local compatibility rows never drive those external
badges.

Clients cannot choose recipients, event copy or deep links. They can only
register/unregister their own FCM token through owner-bound RPCs. If a user
first registers after an alert was created, recent unseen `no_devices` jobs are
requeued. The workflow notification centre reads its authoritative recipient
rows through `v1_list_my_notifications`; hidden Team Chat transport rows are
excluded because conversation-member cursors own Chat unread state. Realtime is
a refresh signal and a bounded poll remains as a fallback. Desktop/tablet
expose a top-bar recent-workflow-alert panel, and every layout retains the full
centre with unread, delivery-health, enable/recovery and pull-to-refresh
behavior. Team Chat independently exposes alert setup and its authoritative
unread badge.

Current targeting follows workflow ownership:

- MR submission -> active Procurement users.
- Procurement arrangement -> assigned Project Engineers plus the two approved
  organization-wide engineering roles.
- Approved arrangement -> Procurement for dispatch plus the assigned/global
  Engineering team for awareness.
- Dispatch/receipt review -> the assigned project team plus the two approved
  organization-wide engineering roles where the workflow requires their
  review.
- Material return submission -> Procurement; the confirm/reject decision ->
  the Engineering submitter.
- Project membership assignment/revocation -> the affected user.
- Material Request cancellation -> its requester and active Procurement users,
  excluding the actor.

FCM payloads contain only a notification UUID, event code, safe type, record
reference and validated internal route. Quantities, costs, supplier details,
user email and other protected fields are excluded.

## Required operator credentials

These values must never be committed or placed in the Flutter client.

1. **Web Push VAPID key**: every production web build requires the project
   public key. Sign in to Firebase Console for `yorks-48c40`, open
   **Project settings → Cloud Messaging → Web configuration → Web Push
   certificates**, generate a key pair, then set the public key as
   `FIREBASE_WEB_VAPID_KEY` in the production build environment. The R35
   launcher forwards it as a Dart define and fails a production build when it
   is missing.
2. **iOS APNs**: in Apple Developer, enable Push Notifications for
   `com.yorks.app`, then upload the Apple Push Notification Authentication Key
   (`.p8`, key ID and team ID) in Firebase Console's Cloud Messaging settings.
   The production provisioning profile must include the capability.
3. **Trusted sender**: set the dedicated minimal Firebase sender service-account
   JSON as the `FCM_SERVICE_ACCOUNT_JSON` Supabase Edge secret. Set
   `YORKS_WEB_ORIGIN` to the canonical HTTPS application origin. The service
   account is server-only; do not add it to this repository, a Dart define,
   Vercel, or a device.
4. **Database webhook**: store the deployed `send-push` HTTPS URL as
   `yorks_push_edge_url` in Supabase Vault. The migration creates
   `yorks_push_webhook_secret`; never expose its decrypted value to a client.

After deployment, sign in once on each target and choose **Enable device
alerts** from the global setup banner. Permission cannot be granted silently by
a web page or application; every browser profile or installed device must be
enrolled once. Prove an actual Yorks workflow transition and a Team Chat
message, not only a Firebase campaign. A workflow event must produce one FCM
alert and one authoritative workflow row. A Chat message must produce one FCM
alert and only the Team Chat unread badge, never a workflow-bell entry. Verify
exact deep links, unauthorized-role exclusion and retry de-duplication.

Before approving a rollout, the operator must verify all three layers instead
of relying on a successful Edge invocation alone:

1. `v1_push_device_tokens` contains a current owner-bound row for each enrolled
   test installation.
2. A new workflow and Chat event each leave `no_devices` and finish as `sent`
   in `v1_notification_push_outbox`.
3. With the app foregrounded, backgrounded and terminated, the target receives
   one alert, the correct sound permitted by its OS settings, the current app
   badge and the exact protected deep link.

Target verification matrix:

- Android native and a physical iOS device use FlutterFire FCM. An iOS
  Simulator cannot receive remote FCM push.
- Windows and macOS use the installed HTTPS web/PWA build in a supported
  browser for background and terminated delivery. The native macOS and Windows
  Flutter builds receive protected Realtime alerts, tone and application
  attention while running, but the repository does not configure a separately
  signed native macOS APNs application or a Windows Push Notification Services
  application. Claiming closed-app native desktop push without those external
  identities would be false; use the installed PWA until those release inputs
  are provisioned.
- iOS/iPadOS web push requires 16.4 or later, a Home Screen installation and
  the user's explicit alert action. Browser and operating-system notification,
  Focus/Do Not Disturb and sound settings remain authoritative.

## Rollback

Removing `FIREBASE_WEB_VAPID_KEY` prevents the next production web build; the
previous approved artifact remains the rollback target. Removing
`yorks_push_edge_url` from Vault stops new outbound
invocations without affecting notification creation or the in-app feed.
Removing `FCM_SERVICE_ACCOUNT_JSON` makes claimed delivery jobs fail safely and
retry with bounded backoff; the in-app feed continues to function. For a full
schema rollback, unschedule `yorks-v1-push-outbox`, drop the three notification
triggers, then the added functions and two added tables. Existing
`v1_notifications` and workflow records remain intact; never copy protected
tokens into a client-readable legacy collection.
