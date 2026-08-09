# Yorks Firebase Cloud Messaging setup

Firebase is **push transport only**. Supabase Auth, RLS, records and audit
remain authoritative. The app uses the registered Yorks Firebase project
`yorks-48c40` for Android (`com.yorks.app`), iOS (`com.yorks.app`) and web.

## Application behavior

- Firebase initializes at application launch, requests the platform's
  notification permission, and registers the FCM token to the signed-in Yorks
  user only after that user is known.
- Token and message-payload diagnostics are emitted only in debug builds. FCM
  payloads must never contain commercial or other protected values.
- Foreground messages use the Yorks Android notification channel and local
  display. Background/terminated notifications retain the existing route
  deep-link behavior.
- Web uses one service worker that includes Flutter's generated cache worker
  and FCM background handler. This avoids either worker replacing the other.

## Required operator credentials

These values must never be committed or placed in the Flutter client.

1. **Web Push VAPID key**: sign in to Firebase Console for `yorks-48c40`, open
   **Project settings → Cloud Messaging → Web configuration → Web Push
   certificates**, generate a key pair, then set the public key as
   `FIREBASE_WEB_VAPID_KEY` in the production build environment. The R35
   launcher forwards it as a Dart define.
2. **iOS APNs**: in Apple Developer, enable Push Notifications for
   `com.yorks.app`, then upload the Apple Push Notification Authentication Key
   (`.p8`, key ID and team ID) in Firebase Console's Cloud Messaging settings.
   The production provisioning profile must include the capability.
3. **Trusted sender**: create a Firebase service-account key in the Yorks
   project and set its full JSON as the `FCM_SERVICE_ACCOUNT_JSON` secret for
   the existing Supabase `send-push` Edge Function. This key is server-only;
   do not add it to this repository, a Dart define, Vercel, or a device.

Once all three are present, use Firebase Console's **Messaging → Send test
message** with a debug-device token to prove delivery while the app is in the
background. Test Android, a physical iOS device, and the HTTPS production web
origin separately; an iOS Simulator cannot receive FCM push.

## Rollback

Removing `FIREBASE_WEB_VAPID_KEY` disables browser token issuance. Removing
the `FCM_SERVICE_ACCOUNT_JSON` secret makes the sender return its existing
safe `501` response; in-app Supabase notifications continue to function.
