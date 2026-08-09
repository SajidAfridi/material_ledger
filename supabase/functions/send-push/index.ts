// Yorks V1 trusted FCM transport.
//
// Postgres is authoritative: a workflow RPC inserts v1_notifications, which
// creates a durable outbox row and invokes this function with only that UUID.
// The caller cannot choose recipients or message copy. This function claims
// the outbox command atomically, derives safe non-commercial copy, reads only
// the recipient's protected device tokens, and records a retryable result.
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  type PushClaim,
  routeFor,
  safePushCopy,
  webLinkFor,
} from "./notification_payload.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-yorks-push-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200, extraHeaders = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, ...extraHeaders, "Content-Type": "application/json" },
  });

function base64UrlEncode(bytes: Uint8Array): string {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const contents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(
    atob(contents),
    (character) => character.charCodeAt(0),
  );
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getFcmAccessToken(
  serviceAccount: { client_email: string; private_key: string },
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );
  const claims = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })),
  );
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const tokenData = await response.json();
  if (!response.ok || typeof tokenData.access_token !== "string") {
    throw new Error(`FCM_OAUTH_${response.status}`);
  }
  return tokenData.access_token;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const suppliedSecret = request.headers.get("x-yorks-push-secret") ?? "";
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";
  if (!url || !serviceKey) return json({ error: "backend unavailable" }, 503);
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: secretIsValid, error: secretError } = await admin.rpc(
    "v1_validate_push_webhook_secret",
    { p_secret: suppliedSecret },
  );
  if (secretError || secretIsValid !== true) {
    return json({ error: "unauthorized" }, 401);
  }

  let notificationId = "";
  try {
    const body = await request.json();
    notificationId = typeof body.notificationId === "string"
      ? body.notificationId
      : "";
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  if (!/^[0-9a-f-]{36}$/i.test(notificationId)) {
    return json({ error: "notificationId required" }, 400);
  }

  const finish = async (
    status: "sent" | "no_devices" | "failed",
    sentDeviceCount = 0,
    errorCode?: string,
  ) => {
    await admin.rpc("v1_finish_notification_push", {
      p_notification_id: notificationId,
      p_status: status,
      p_sent_device_count: sentDeviceCount,
      p_error_code: errorCode ?? null,
    });
  };

  const { data: claimData, error: claimError } = await admin.rpc(
    "v1_claim_notification_push",
    { p_notification_id: notificationId },
  );
  if (claimError) return json({ error: "claim failed" }, 500);
  if (!claimData) return json({ ok: true, skipped: true });
  const claim = claimData as PushClaim;

  if (!serviceAccountJson) {
    await finish("failed", 0, "FCM_NOT_CONFIGURED");
    return json({ error: "push not configured" }, 503, { "Retry-After": "60" });
  }

  const { data: tokenRows, error: tokenError } = await admin
    .from("v1_push_device_tokens")
    .select("token, platform")
    .eq("auth_user_id", claim.recipientAuthUserId);
  if (tokenError) {
    await finish("failed", 0, "TOKEN_LOOKUP_FAILED");
    return json({ error: "token lookup failed" }, 503, { "Retry-After": "30" });
  }
  if (!tokenRows || tokenRows.length === 0) {
    await finish("no_devices");
    return json({ ok: true, sent: 0, note: "no registered devices" });
  }

  try {
    const serviceAccount = JSON.parse(serviceAccountJson) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    if (
      !serviceAccount.project_id || !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error("FCM_SERVICE_ACCOUNT_INVALID");
    }
    const accessToken = await getFcmAccessToken(serviceAccount);
    const sendUrl =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    const copy = safePushCopy(claim.eventCode);
    const route = routeFor(claim);
    const webLink = webLinkFor(
      route,
      Deno.env.get("YORKS_WEB_ORIGIN") ?? "",
    );
    let sent = 0;
    let transientFailures = 0;
    const staleTokens: string[] = [];

    for (const row of tokenRows) {
      const token = row.token as string;
      const isWeb = row.platform === "web";
      const data = {
        notificationId: claim.notificationId,
        eventCode: claim.eventCode,
        type: copy.type,
        refId: claim.requestId ?? claim.entityId,
        route,
      };
      const response = await fetch(sendUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            data,
            ...(isWeb
              ? {
                webpush: {
                  notification: {
                    title: copy.title,
                    body: copy.body,
                    icon: "/icons/Icon-192.png",
                  },
                  ...(webLink ? { fcm_options: { link: webLink } } : {}),
                },
              }
              : {
                notification: { title: copy.title, body: copy.body },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              }),
          },
        }),
      });
      if (response.ok) {
        sent += 1;
        continue;
      }
      const errorBody = await response.json().catch(() => ({}));
      const status = errorBody?.error?.status as string | undefined;
      if (status === "NOT_FOUND" || status === "UNREGISTERED") {
        staleTokens.push(token);
      } else {
        transientFailures += 1;
      }
    }

    if (staleTokens.length > 0) {
      await admin.from("v1_push_device_tokens").delete().in(
        "token",
        staleTokens,
      );
    }
    if (sent > 0) {
      await finish(
        "sent",
        sent,
        transientFailures > 0 ? "PARTIAL_SEND" : undefined,
      );
      return json({ ok: true, sent, staleRemoved: staleTokens.length });
    }
    if (transientFailures > 0) {
      await finish("failed", 0, "FCM_SEND_FAILED");
      return json({ error: "FCM send failed" }, 503, { "Retry-After": "30" });
    }
    await finish("no_devices");
    return json({ ok: true, sent: 0, staleRemoved: staleTokens.length });
  } catch (error) {
    const code = String(error).includes("FCM_SERVICE_ACCOUNT_INVALID")
      ? "FCM_SERVICE_ACCOUNT_INVALID"
      : "FCM_TRANSPORT_FAILED";
    await finish("failed", 0, code);
    return json({ error: code }, 503, { "Retry-After": "60" });
  }
});
