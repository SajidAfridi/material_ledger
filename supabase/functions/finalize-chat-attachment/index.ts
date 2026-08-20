// Server-side byte verification for private Yorks Team Chat attachments.
//
// The caller may upload only to a short-lived, actor-scoped Storage path. This
// function downloads that private object with service authority, computes the
// actual SHA-256 digest, and marks the intent verified through a service-only
// RPC. Message send remains the only operation that binds the object to chat.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const sha256Hex = async (bytes: ArrayBuffer): Promise<string> => {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
};

const uploadIntentId = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const id = value.trim();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(id)
    ? id
    : null;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "missing token" }, 401);
  }
  const body = await request.json().catch(() => null) as
    | Record<string, unknown>
    | null;
  const intentId = uploadIntentId(body?.upload_intent_id);
  if (intentId == null) {
    return json({ error: "upload_intent_id is required" }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return json({ error: "chat attachment finalizer is not configured" }, 503);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: identity, error: identityError } = await caller.auth.getUser();
  if (identityError || identity.user == null) {
    return json({ error: "unauthorized" }, 401);
  }

  const { data: intent, error: intentError } = await caller.rpc(
    "v1_chat_upload_intent_projection",
    { p_upload_intent_id: intentId },
  );
  if (intentError || intent == null || typeof intent !== "object") {
    return json({ error: "upload intent is unavailable" }, 403);
  }
  const record = intent as Record<string, unknown>;
  if (record.verified_at != null) return json(record);
  const bucketId = record.bucket_id;
  const objectPath = record.object_path;
  const expectedMimeType = record.mime_type;
  const expectedByteSize = record.byte_size;
  if (
    typeof bucketId !== "string" || typeof objectPath !== "string" ||
    typeof expectedMimeType !== "string" ||
    typeof expectedByteSize !== "number"
  ) {
    return json({ error: "upload intent is malformed" }, 409);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: object, error: downloadError } = await admin.storage
    .from(bucketId)
    .download(objectPath);
  if (downloadError || object == null) {
    return json({ error: "uploaded object is unavailable" }, 409);
  }
  const bytes = await object.arrayBuffer();
  if (bytes.byteLength !== expectedByteSize) {
    return json({ error: "uploaded byte size does not match the intent" }, 409);
  }
  const uploadedMimeType = object.type.split(";")[0].trim().toLowerCase();
  if (
    uploadedMimeType.length === 0 ||
    uploadedMimeType !== expectedMimeType.toLowerCase()
  ) {
    return json(
      { error: "uploaded content type does not match the intent" },
      409,
    );
  }
  const verifiedHash = await sha256Hex(bytes);
  const { data: verified, error: verifyError } = await admin.rpc(
    "v1_verify_chat_attachment_upload",
    {
      p_upload_intent_id: intentId,
      p_verified_sha256: verifiedHash,
      p_verified_byte_size: bytes.byteLength,
      p_verified_mime_type: uploadedMimeType,
    },
  );
  if (verifyError) {
    return json({ error: "chat attachment verification failed" }, 409);
  }
  return json(verified);
});
