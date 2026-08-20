import { assertEquals } from "jsr:@std/assert@1";
import {
  isTeamChatEvent,
  normalizedUnreadCount,
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

Deno.test("badge counts are finite server-owned integers", () => {
  assertEquals(normalizedUnreadCount(12.8), 12);
  assertEquals(normalizedUnreadCount(1200), 999);
  assertEquals(normalizedUnreadCount(-4), 0);
  assertEquals(normalizedUnreadCount("17"), 0);
  assertEquals(normalizedUnreadCount(undefined), 0);
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

Deno.test("project membership alerts use the protected project route", () => {
  assertEquals(
    routeFor({
      ...claim(null),
      entityType: "project_member",
      projectId: "15000000-0000-4000-8000-000000000001",
    }),
    "/yorks/projects/15000000-0000-4000-8000-000000000001",
  );
});

Deno.test("Team Chat alerts use trusted copy and the exact conversation route", () => {
  const conversationId = "16000000-0000-4000-8000-000000000001";
  assertEquals(safePushCopy("team_chat_message"), {
    title: "New Team Chat message",
    body: "A conversation you participate in has a new message.",
    type: "info",
  });
  assertEquals(
    safePushCopy("team_chat_mention").title,
    "You were mentioned in Team Chat",
  );
  assertEquals(isTeamChatEvent("team_chat_message"), true);
  assertEquals(isTeamChatEvent("team_chat_mention"), true);
  // Preserved pre-Team-Chat Material Request mentions keep their workflow
  // event; all new contextual Chat mentions use Team Chat's own code.
  assertEquals(isTeamChatEvent("material_request_mentioned"), false);
  assertEquals(isTeamChatEvent("material_request_submitted"), false);
  assertEquals(
    routeFor({
      ...claim(null),
      entityType: "chat_conversation",
      chatConversationId: conversationId,
    }),
    `/yorks/team-chat/${conversationId}`,
  );
  assertEquals(
    routeFor({
      ...claim(null),
      chatConversationId: "//attacker.example",
    }),
    "/notifications",
  );
});

Deno.test("approval-first and return events have specific safe copy", () => {
  assertEquals(
    safePushCopy("material_request_approval_required").title,
    "Material request approval required",
  );
  assertEquals(
    safePushCopy("material_return_confirmed").title,
    "Material return confirmed",
  );
});

Deno.test("web link is absolute HTTPS and rejects unsafe configuration", () => {
  assertEquals(
    webLinkFor(
      "/yorks/material-requests/14000000-0000-4000-8000-000000000001",
      "https://yorks-r35.vercel.app",
      "11000000-0000-4000-8000-000000000001",
    ),
    "https://yorks-r35.vercel.app/#/yorks/material-requests/14000000-0000-4000-8000-000000000001?notificationId=11000000-0000-4000-8000-000000000001",
  );
  assertEquals(
    webLinkFor("//attacker.example", "https://yorks-r35.vercel.app"),
    null,
  );
  assertEquals(webLinkFor("/notifications", "http://localhost:8080"), null);
  assertEquals(webLinkFor("/notifications", "not-an-origin"), null);
});
