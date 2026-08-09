import { assertEquals } from "jsr:@std/assert@1";
import {
  type PushClaim,
  routeFor,
  safePushCopy,
  webLinkFor,
} from "./notification_payload.ts";

const claim = (requestId?: string | null): PushClaim => ({
  notificationId: "11000000-0000-4000-8000-000000000001",
  recipientAuthUserId: "12000000-0000-4000-8000-000000000001",
  eventCode: "material_request_submitted",
  entityType: "material_request",
  entityId: "13000000-0000-4000-8000-000000000001",
  requestId,
  attemptCount: 1,
});

Deno.test("trusted event copy is server-owned and non-commercial", () => {
  const copy = safePushCopy("material_request_submitted");
  assertEquals(copy.title, "New material request");
  assertEquals(copy.type, "request");
  assertEquals(copy.body.includes("cost"), false);
  assertEquals(copy.body.includes("quantity"), false);
});

Deno.test("unknown events use a safe generic envelope", () => {
  assertEquals(safePushCopy("future_event"), {
    title: "Yorks workflow update",
    body: "A record assigned to you has changed.",
    type: "info",
  });
});

Deno.test("deep link accepts only a resolved UUID request id", () => {
  const requestId = "14000000-0000-4000-8000-000000000001";
  assertEquals(
    routeFor(claim(requestId)),
    `/yorks/material-requests/${requestId}`,
  );
  assertEquals(routeFor(claim("//attacker.example")), "/notifications");
  assertEquals(routeFor(claim(null)), "/notifications");
});

Deno.test("web link is absolute HTTPS and rejects unsafe configuration", () => {
  assertEquals(
    webLinkFor(
      "/yorks/material-requests/14000000-0000-4000-8000-000000000001",
      "https://yorks-r35.vercel.app",
    ),
    "https://yorks-r35.vercel.app/yorks/material-requests/14000000-0000-4000-8000-000000000001",
  );
  assertEquals(
    webLinkFor("//attacker.example", "https://yorks-r35.vercel.app"),
    null,
  );
  assertEquals(webLinkFor("/notifications", "http://localhost:8080"), null);
  assertEquals(webLinkFor("/notifications", "not-an-origin"), null);
});
