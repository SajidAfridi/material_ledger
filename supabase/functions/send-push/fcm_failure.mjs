// Pure FCM HTTP v1 classifier. Only these allowlisted codes reach Postgres.
// Never include error.message, raw response, a registration token or secrets.
export function classifyFcmFailure(httpStatus, body, retryAfterHeader) {
  const error = body && typeof body === "object" ? body.error : null;
  const details = Array.isArray(error?.details) ? error.details : [];
  const fcm = details.find((detail) =>
    detail?.["@type"] ===
      "type.googleapis.com/google.firebase.fcm.v1.FcmError"
  );
  const badRequest = details.some((detail) =>
    detail?.["@type"] === "type.googleapis.com/google.rpc.BadRequest"
  );
  const code = fcm?.errorCode ?? error?.status;
  const retryAfterSeconds = parseRetryAfter(retryAfterHeader);
  if (code === "UNREGISTERED") {
    return {
      category: "TOKEN_UNREGISTERED",
      retryable: false,
      staleToken: true,
    };
  }
  if (code === "INVALID_ARGUMENT" && fcm && !badRequest) {
    return { category: "TOKEN_INVALID", retryable: false };
  }
  if (code === "SENDER_ID_MISMATCH") {
    return { category: "SENDER_ID_MISMATCH", retryable: false };
  }
  if (code === "THIRD_PARTY_AUTH_ERROR") {
    return { category: "THIRD_PARTY_AUTH", retryable: false, global: true };
  }
  if (code === "QUOTA_EXCEEDED" || httpStatus === 429) {
    return { category: "QUOTA_EXCEEDED", retryable: true, retryAfterSeconds };
  }
  if (code === "UNAVAILABLE" || httpStatus === 503) {
    return { category: "FCM_UNAVAILABLE", retryable: true, retryAfterSeconds };
  }
  if (code === "INTERNAL" || httpStatus >= 500 && httpStatus < 600) {
    return { category: "FCM_INTERNAL", retryable: true, retryAfterSeconds };
  }
  if (code === "INVALID_ARGUMENT" || badRequest || httpStatus === 400) {
    return { category: "MALFORMED_REQUEST", retryable: false };
  }
  if (httpStatus === 401 || httpStatus === 403) {
    return { category: "AUTH_CONFIGURATION", retryable: false, global: true };
  }
  return { category: "UNKNOWN_ERROR", retryable: true, retryAfterSeconds };
}

export function parseRetryAfter(value, now = Date.now()) {
  if (typeof value !== "string" || !value.trim()) return null;
  const trimmed = value.trim();
  const seconds = /^\d+$/.test(trimmed)
    ? Number(trimmed)
    : Math.ceil((Date.parse(trimmed) - now) / 1000);
  return Number.isFinite(seconds)
    ? Math.max(0, Math.min(2147483647, seconds))
    : null;
}

// The function supplies the request closure so tests can provide a fake FCM
// transport without credentials, network access or a real device token.
export async function sendFcmRequest(send) {
  try {
    const response = await send();
    if (response.ok) return { accepted: true };
    const body = await response.json().catch(() => ({}));
    return {
      accepted: false,
      failure: classifyFcmFailure(
        response.status,
        body,
        response.headers.get("Retry-After"),
      ),
    };
  } catch {
    return {
      accepted: false,
      failure: { category: "DELIVERY_OUTCOME_UNKNOWN", retryable: false },
    };
  }
}
