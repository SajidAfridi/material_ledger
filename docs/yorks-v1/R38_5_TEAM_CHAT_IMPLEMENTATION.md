# R38.5 Team Chat and contextual collaboration

## Authority and purpose

The client-review pack `Yorks_R38_5_Team_Chat_Client_Review_Pack` is the visual
and interaction authority for this additive feature where it does not conflict
with the Yorks V1 SRS, exact-role rules, current project membership, controlled
workflow or commercial-data boundaries. Team Chat is a coordination surface;
it never approves, changes a quantity, reserves stock, dispatches material or
replaces the controlled Project/MR record.

The feature is guarded by `YORKS_R38_TEAM_CHAT`. The canonical `tool/r35.sh`
chain enables it together with Documents, because private attachments depend
on the accepted Storage/document boundary. A release without complete Supabase
configuration still fails closed.

## Conversation policy

| Kind | Creation | Participants | Send policy |
|---|---|---|---|
| Direct | Any active exact role | Exactly the caller and one selected active user; canonical pair prevents duplicates | Either active participant |
| Project | Any active user who can read the Project | Current authorized Project participants; one canonical conversation per Project | Current authorized participant |
| Material Request | Any active user who can read the MR | Current authorized MR/project participants; one canonical conversation per MR | Current authorized participant |
| Group | Admin, Project Manager or Senior Mechanical Engineer | Explicit active-user selection; creator is owner | Active member; owner or active Admin participant manages title/members |
| Announcement | Admin | Controlled organization audience | Admin only |

Admin has no implicit access to a Direct conversation. Context membership is
not a permanent bypass: Project/MR access is re-checked when listing, searching,
opening, sending and downloading. Historical sender name/role and system facts
remain attributable after membership changes without granting future access.

## Client architecture

The production path is:

`responsive widget -> Riverpod controller -> Team Chat repository -> trusted RPC / private Storage / verification Edge Function`

The controller owns server search, 50-message cursor pagination, selected
thread state, a 30-second safety refresh and Realtime-as-refresh-signal. Loading
older pages preserves the visible scroll offset. New messages auto-scroll only
when the user is already near the bottom; otherwise a new-message affordance
preserves reading position. Failed sends retain the same idempotency key and
payload for an explicit retry, while changed content receives a new command
identity.

The Flutter UI provides:

- pinned/muted/archived/unread conversation preferences;
- Direct, Project, MR, Group and Announcement filters and server search;
- reply, acknowledge, message pin and linked-record shortcuts;
- version-checked sender edit and soft-delete actions for ordinary
  conversations, with Material Request discussion remaining append-only;
- server-derived sent, delivered and read marks without presence inference;
- participant-only `@` suggestions and server-validated mention IDs;
- owner/Admin group management;
- verified PDF, Excel, Word, image and text attachments up to 20 MB;
- authorized image preview and platform save/download;
- compact shell badges and exact thread deep links from notifications;
- English, Arabic, Urdu and Hindi UX copy.

## Message lifecycle and receipts

The original sender may update only the body of their own non-system message
in an ordinary Direct, Project, Group or Announcement conversation while they
remain an active member. Delete is a soft-delete: the body, attachment and
interaction projection are replaced by a localized tombstone, while the row,
actor, timestamp and a private server-only prior-body revision remain intact.
Material Request conversation messages are not editable or deletable because
AT-26 keeps controlled MR discussion append-only.

Edit and delete commands re-check sender, active membership, conversation kind
and expected message version in one trusted transaction. They are idempotent,
audited without copying the prior body into the general audit payload, and do
not optimistically alter the client before server confirmation. A sender sees
Sent, Delivered or Read from member delivery/read cursors. Delivery advances
only for incoming messages, read also advances delivery, and neither cursor is
used as an online-presence claim.

## Responsive contract

- At 1250px and above, the workspace is a 320px conversation list, flexible
  thread and 316px details panel.
- Below 1250px, the details pane becomes an explicit modal/sheet rather than
  compressing message content.
- Around tablet width the conversation list is 285px and the thread remains a
  full interaction surface.
- At 720px and below, the client shows either the conversation list or one
  focused thread. The thread owns its back/header controls and its composer
  remains above the shell safe area.
- All icon buttons and primary taps use the Yorks minimum 44x44 target. Motion
  is short/non-blocking and follows the application theme.

## Attachments and notifications

An upload is not a message. The client first obtains a short-lived upload
intent whose private object path is scoped to the authenticated actor and
conversation. After upload, `finalize-chat-attachment` re-authenticates the
caller, downloads with service authority and checks stored byte count, content
type and SHA-256 before invoking the service-only verification RPC. Only a
verified, unexpired, same-actor/same-conversation attachment can be bound by
`v1_send_chat_message`.

Normal messages notify active non-muted peers. Mentions notify even in muted
conversations. System messages do not increase unread counts or generate user
pushes. Notification payload copy is server-owned/non-commercial and resolves
to `/yorks/team-chat/:conversationId`. If that exact thread is foregrounded,
the in-app host suppresses its redundant toast/tone. Chat message/mention rows
in `v1_notifications` are private durable push-transport acknowledgements;
`v1_list_my_notifications` and the workflow bell exclude them. Conversely,
workflow **Mark all read** cannot acknowledge Chat. `v1_mark_chat_read`
advances the server cursor and acknowledges only the exact conversation's
hidden transport rows, so native mobile, browser and installed PWA converge on
one Team Chat unread truth without showing a second notification badge.

## Data preservation and rollback

The schema and bucket are additive. MR discussion is projected into the one
canonical MR conversation; compatibility IDs/read APIs remain so older clients
do not create a second visible history. Workflow audit-to-system-message
projection is best-effort and cannot interrupt the source transaction.

Rollback disables the flag and lifecycle RPC grants and deploys the previous
complete client/functions. It retains all messages, private revisions,
memberships, delivery/read cursors, verified attachments, notifications and
audit attribution. The additive columns and tombstone facts may remain dormant;
no rollback deletes or rewrites committed collaboration history.

## Acceptance evidence

- `supabase/tests/database/yorks_r38_5_team_chat.test.sql`: 66 database tests
  for exact roles, Direct privacy, canonical creation, RLS, idempotency,
  cross-device read state, mute/mentions, announcements, contextual revocation,
  private Storage, verification, authorized search, record-link authority,
  reply/reaction/pin facts, archive restore, bounded pagination and inactive-user denial.
- `supabase/tests/database/yorks_r38_5_chat_message_lifecycle.test.sql`: sender
  edit/delete authority, Material Request protection in the command contract,
  stale-version conflict, idempotent revision capture, tombstone access,
  delivery/read cursor projection and direct-write/RLS negatives.
- `test/yorks_v1_team_chat_test.dart`: projection/payload/file/unread tests,
  focused edit/delete/receipt interactions and four responsive visual states.
- `supabase/functions/send-push/notification_payload_test.ts`: trusted Team
  Chat copy, exact deep link and unsafe-route rejection.
- [`evidence/r38-5-team-chat-20260814/README.md`](evidence/r38-5-team-chat-20260814/README.md): visual evidence index and gate record.
