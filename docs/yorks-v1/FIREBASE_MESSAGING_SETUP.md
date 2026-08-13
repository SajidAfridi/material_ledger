# Yorks Firebase Cloud Messaging setup

Firebase is **push transport only**. Supabase Auth, RLS, records and audit
remain authoritative. The app uses the registered Yorks Firebase project
`yorks-48c40` for Android (`com.yorks.app`), iOS (`com.yorks.app`) and web.

## Application behavior

- Firebase initializes at application launch and reads the current permission
  without opening a prompt. Chrome, Android and Apple permission is requested
  only from the user's explicit **Enable device alerts** action in the
  notification center so browser gesture requirements are satisfied. An
  already-authorized FCM token is registered only after the Yorks user is
  known; token refresh and foreground resume repeat that owner-bound step.
- Token and message-payload diagnostics are emitted only in debug builds. FCM
  payloads must never contain commercial or other protected values.
- Foreground FCM messages and recipient-scoped Realtime refreshes converge on
  one de-duplicated in-app alert with visible copy, navigation, haptic feedback
  and a short tone. Background/terminated notifications use the Yorks system
  channel and retain safe deep-link behavior. Browser/OS focus and sound
  settings remain authoritative.
- Web uses one service worker that includes Flutter's generated cache worker
  and FCM background handler. This avoids either worker replacing the other.

## Trusted delivery path

Workflow RPCs insert recipient-specific rows into `v1_notifications`. An
insert trigger creates exactly one durable `v1_notification_push_outbox` job;
Postgres invokes `send-push` with only that notification UUID and a
Vault-managed webhook secret. The Edge Function claims the job atomically,
derives the recipient and non-commercial copy from protected server data,
sends through FCM HTTP v1, removes stale tokens and records a terminal or
retryable result. A one-minute `pg_cron` job retries failed or expired leases.

Clients cannot choose recipients, event copy or deep links. They can only
register/unregister their own FCM token through owner-bound RPCs. If a user
first registers after an alert was created, recent unseen `no_devices` jobs are
requeued. The notification centre reads the same authoritative recipient rows
through `v1_list_my_notifications`; Realtime is a refresh signal and a bounded
poll remains as a fallback. Desktop/tablet expose a top-bar recent-alert panel,
and every layout retains the full center with unread, delivery-health,
enable/recovery and pull-to-refresh behavior.

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

After deployment, sign in once on each target, open Notifications and choose
**Enable device alerts** so its owner-bound token can be registered. Prove an
actual Yorks workflow transition (for example Engineer Submit -> Procurement),
not only a Firebase campaign. Verify the recipient receives both the FCM alert
and the authoritative in-app row, an unrelated role receives neither, the deep link
opens the intended record, and retrying the workflow does not create a
duplicate notification. Test Android, a physical iOS device, and the HTTPS
production web origin separately; an iOS Simulator cannot receive FCM push.

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
