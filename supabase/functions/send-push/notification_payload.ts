export type PushClaim = {
  notificationId: string;
  recipientAuthUserId: string;
  eventCode: string;
  entityType: string;
  entityId: string;
  requestId?: string | null;
  projectId?: string | null;
  attemptCount: number;
};

export type PushCopy = {
  title: string;
  body: string;
  type: "request" | "project" | "info";
};

export function safePushCopy(eventCode: string): PushCopy {
  switch (eventCode) {
    case "material_request_submitted":
      return {
        title: "New material request",
        body: "A material request is ready for Procurement arrangement.",
        type: "request",
      };
    case "arrangement_review_required":
      return {
        title: "Arrangement ready for review",
        body: "Procurement submitted an arrangement for Engineering approval.",
        type: "request",
      };
    case "arrangement_approved":
      return {
        title: "Arrangement approved",
        body: "The material request is ready for controlled dispatch.",
        type: "request",
      };
    case "arrangement_returned":
      return {
        title: "Arrangement returned",
        body: "Engineering returned the arrangement to Procurement.",
        type: "request",
      };
    case "receipt_review_required":
      return {
        title: "Delivery ready for receipt review",
        body: "Dispatched materials are awaiting the project team review.",
        type: "request",
      };
    case "receipt_review_confirmed":
      return {
        title: "Receipt review confirmed",
        body: "The project team recorded the delivered material condition.",
        type: "request",
      };
    case "material_return_submitted":
      return {
        title: "Material return submitted",
        body: "A project material return is awaiting Procurement confirmation.",
        type: "request",
      };
    default:
      return {
        title: "Yorks workflow update",
        body: "A record assigned to you has changed.",
        type: "info",
      };
  }
}

export function routeFor(claim: PushClaim): string {
  const id = claim.requestId;
  if (typeof id === "string" && /^[0-9a-f-]{36}$/i.test(id)) {
    return `/yorks/material-requests/${id}`;
  }
  return "/notifications";
}

export function webLinkFor(route: string, origin: string): string | null {
  try {
    const base = new URL(origin);
    if (base.protocol !== "https:") return null;
    if (!route.startsWith("/") || route.startsWith("//")) return null;
    return new URL(route, base).toString();
  } catch {
    return null;
  }
}
