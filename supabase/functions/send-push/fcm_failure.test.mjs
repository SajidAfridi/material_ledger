import test from "node:test";
import assert from "node:assert/strict";
import {
  classifyFcmFailure,
  parseRetryAfter,
  sendFcmRequest,
} from "./fcm_failure.mjs";

const fcm = (status, errorCode) => ({
  error: {
    status,
    details: [{
      "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
      errorCode,
    }],
  },
});

test("definitively stale tokens are terminal", () => {
  for (
    const [http, body] of [
      [404, fcm("NOT_FOUND", "UNREGISTERED")],
    ]
  ) {
    const result = classifyFcmFailure(http, body, null);
    assert.equal(result.retryable, false);
    assert.equal(result.staleToken, true);
  }
});

test("malformed message is terminal but never deletes a token", () => {
  const result = classifyFcmFailure(400, {
    error: {
      status: "INVALID_ARGUMENT",
      details: [{ "@type": "type.googleapis.com/google.rpc.BadRequest" }],
    },
  }, null);
  assert.equal(result.category, "MALFORMED_REQUEST");
  assert.equal(result.staleToken, undefined);
});

test("sender mismatch is token-specific; third-party auth is global", () => {
  const mismatch = classifyFcmFailure(
    403,
    fcm("PERMISSION_DENIED", "SENDER_ID_MISMATCH"),
    null,
  );
  assert.equal(mismatch.global, undefined);
  assert.equal(mismatch.retryable, false);
  const auth = classifyFcmFailure(
    401,
    fcm("UNAUTHENTICATED", "THIRD_PARTY_AUTH_ERROR"),
    null,
  );
  assert.equal(auth.global, true);
  assert.equal(auth.retryable, false);
  assert.equal(
    classifyFcmFailure(401, {}, null).category,
    "AUTH_CONFIGURATION",
  );
});

test("rate limits and server failures have bounded retry metadata", () => {
  assert.deepEqual(
    classifyFcmFailure(429, fcm("RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED"), "120"),
    {
      category: "QUOTA_EXCEEDED",
      retryable: true,
      retryAfterSeconds: 120,
    },
  );
  assert.equal(
    classifyFcmFailure(503, fcm("UNAVAILABLE", "UNAVAILABLE"), null).category,
    "FCM_UNAVAILABLE",
  );
  assert.equal(
    classifyFcmFailure(500, fcm("INTERNAL", "INTERNAL"), null).category,
    "FCM_INTERNAL",
  );
});

test("unknown response stays finite-retry eligible", () => {
  assert.equal(
    classifyFcmFailure(418, { error: { message: "sensitive" } }, null).category,
    "UNKNOWN_ERROR",
  );
  assert.equal(parseRetryAfter("not-a-date"), null);
  assert.equal(parseRetryAfter("999999"), 999999);
});

test("fake FCM accepts one send and preserves one result", async () => {
  let calls = 0;
  const result = await sendFcmRequest(async () => {
    calls += 1;
    return new Response(JSON.stringify({ name: "projects/test/messages/1" }), {
      status: 200,
    });
  });
  assert.equal(calls, 1);
  assert.deepEqual(result, { accepted: true });
});

test("fake FCM rate limit carries Retry-After into SQL classification", async () => {
  const result = await sendFcmRequest(async () =>
    new Response(JSON.stringify(fcm("RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED")), {
      status: 429,
      headers: { "Retry-After": "90" },
    })
  );
  assert.equal(result.accepted, false);
  assert.equal(result.failure.category, "QUOTA_EXCEEDED");
  assert.equal(result.failure.retryAfterSeconds, 90);
});

test("fake FCM network failure becomes a safe bounded category", async () => {
  const result = await sendFcmRequest(async () => {
    throw new Error("private transport detail");
  });
  assert.deepEqual(result.failure, {
    category: "DELIVERY_OUTCOME_UNKNOWN",
    retryable: false,
  });
});

test("ambiguous invalid argument is permanent without token pruning", () => {
  const result = classifyFcmFailure(
    400,
    fcm("INVALID_ARGUMENT", "INVALID_ARGUMENT"),
    null,
  );
  assert.equal(result.retryable, false);
  assert.equal(result.staleToken, undefined);
});

test("Retry-After HTTP date is honored without shortening long delays", () => {
  const now = Date.parse("2026-09-29T00:00:00Z");
  assert.equal(parseRetryAfter("Tue, 29 Sep 2026 02:00:00 GMT", now), 7200);
});
