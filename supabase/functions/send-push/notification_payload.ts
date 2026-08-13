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
    case "material_request_approval_required":
    case "material_request_updated_for_approval":
      return {
        title: "Material request approval required",
        body: "A material request is ready for Engineering approval.",
        type: "request",
      };
    case "material_request_approved_for_arrangement":
      return {
        title: "Material request approved",
        body: "Engineering approved the request for Procurement arrangement.",
        type: "request",
      };
    case "material_request_changes_requested":
      return {
        title: "Material request changes required",
        body: "Engineering returned the request with a reason.",
        type: "request",
      };
    case "material_request_mentioned":
      return {
        title: "You were mentioned",
        body: "A teammate mentioned you in a material request comment.",
        type: "info",
      };
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
    case "arrangement_ready_for_dispatch":
      return {
        title: "Materials ready for dispatch",
        body: "Procurement completed the approved arrangement.",
        type: "request",
      };
    case "arrangement_completed_unavailable":
      return {
        title: "Arrangement completed",
        body:
          "Procurement recorded that no requested material can be provided now.",
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
    case "material_return_confirmed":
      return {
        title: "Material return confirmed",
        body:
          "Procurement confirmed physical receipt of the returned material.",
        type: "request",
      };
    case "material_return_rejected":
      return {
        title: "Material return rejected",
        body: "Procurement returned the material return with a reason.",
        type: "request",
      };
    case "material_request_cancelled":
      return {
        title: "Material request cancelled",
        body: "The material request was cancelled and open work was released.",
        type: "request",
      };
    case "material_request_closed":
      return {
        title: "Material request completed",
        body: "The received material request was closed.",
        type: "request",
      };
    case "project_member_assigned":
      return {
        title: "Project access assigned",
        body: "You were assigned to a Yorks project.",
        type: "project",
      };
    case "project_member_revoked":
      return {
        title: "Project access changed",
        body: "Your active assignment to a Yorks project ended.",
        type: "project",
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
  if (
    (claim.entityType === "project" || claim.entityType === "project_member") &&
    typeof claim.projectId === "string" &&
    /^[0-9a-f-]{36}$/i.test(claim.projectId)
  ) {
    return `/yorks/projects/${claim.projectId}`;
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
