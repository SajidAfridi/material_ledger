# Yorks Material Request Discussion — Product, UX and Engineering Specification

Status: **approved; D01-D02 and exact-anchor routing implemented locally; D03
delivery/read acceptance and D04 staging acceptance pending**
Prepared: **6 September 2026**
Scope: **one contextual discussion attached to each server-backed Material Request**

## 1. Outcome

Every Material Request has one calm, dependable discussion at the end of its
detail page. Questions, decisions, mentions and supporting evidence remain
beside the request from its first server-backed draft through its retained
history.

The discussion replaces the current narrow right-rail treatment. It does not
replace Team Chat. **Start team conversation** remains an optional secondary
action for broader conversation and links the resulting conversation back to
the Material Request.

This specification extends the accepted normalized Material Request comments
and mentions. It must not introduce a legacy/local comment store or a second
notification system.

## 2. Current baseline and gap

Yorks already has:

- trusted Material Request comment and mention RPCs;
- authorized mention candidates;
- newest-20 comment projection and cursor paging for older comments;
- durable mention notifications; and
- an optional action that creates a linked Team Chat conversation.

The current presentation is incomplete for daily use:

- desktop places the discussion in a narrow right column;
- the attachment control redirects to Team Chat instead of attaching evidence
  to the comment;
- a notification can open the request but cannot reliably load, scroll to and
  focus an exact older comment;
- replies and comment-linked workflow context are not first-class; and
- the discussion competes with the request summary rather than reading as the
  final part of the request record.

## 3. Product contract

### 3.1 Canonical location

The discussion appears after **Delivery Orders and returns**, at the end of the
complete Material Request detail flow. It spans the full available request
content width. The right rail retains concise request facts and actions only.

The section is visible only after a Material Request has a server-issued ID.
A private server-backed Draft exposes discussion only to its creator. Other
authorized request participants gain access after successful submission, in
line with the accepted approval-first Material Request rules.

### 3.2 One record, one discussion

- A Material Request has exactly one canonical discussion.
- The same discussion is shown to Engineering, Procurement, Admin and other
  authorized participants through role-safe projections.
- Arrangement, dispatch, receipt and return screens may link to this section;
  they must not create parallel discussion histories.
- Comments communicate context. They never approve, arrange, reserve,
  dispatch, receive, return, cancel or close a request.
- Chat messages never become comments or workflow decisions automatically.

### 3.3 Comment content

Each comment records and displays:

- stable comment ID and Material Request ID;
- author display name, exact role and immutable author identity reference;
- server creation time;
- localized visible time and full timestamp on hover/focus;
- plain text body;
- zero or more authorized mentions;
- zero or more protected document attachments;
- optional one-level parent comment reference for replies;
- optional context reference to the request, a request line or a retained
  lifecycle record; and
- server-generated audit attribution.

The visible comment body allows **1–4,000 Unicode characters** after trimming.
Store plain text as authority. Render URLs safely as links if the existing link
policy permits them. Do not accept or render arbitrary HTML.

Comments are immutable operational facts in the first release. A correction is
posted as a reply or new comment. No browser client receives a hard-delete
command. A later redaction feature, if required, must preserve a tombstone,
reason, actor and original protected audit evidence.

### 3.4 Replies

Reply creates a new comment with `parent_comment_id`. The UI shows a compact
quote containing the original author and the first two lines. Replies remain
in chronological order in the main timeline. Replying to a reply references
the root comment; deeper nesting is not supported.

### 3.5 Mentions

- Typing `@` opens a server-returned, searchable list of people who can
  currently view the request.
- A selected mention stores the protected user ID separately from visible
  text. Typed text alone does not create a mention.
- A mention never grants access.
- Revoked, inactive or out-of-scope people are omitted by the server.
- Posting creates at most one durable notification per mentioned recipient and
  comment, even when the command is retried.
- Mentioning oneself does not create a notification.

### 3.6 Attachments

The paperclip attaches operational evidence directly to the pending comment
through the existing protected Team Chat attachment-intent and private Storage
pipeline. Controlled commercial documents remain in the classified project
document workflow and must not be copied into this participant-wide discussion.

- Draft uploads are private to the current authenticated actor until the
  comment command succeeds.
- Posting atomically finalizes attachment links or fails without publishing a
  partial comment.
- Retry uses one idempotency key and cannot duplicate comments, document links,
  notifications or audit events.
- Cancelled and abandoned uploads are cleaned by the existing controlled
  cleanup process.
- The server verifies the file allowlist, maximum size, filename, declared MIME
  type and SHA-256 evidence before finalization.
- Each attachment chip shows filename and size with an authorized Download
  action. File preview remains a later enhancement; it is not simulated.

### 3.7 Request and line context

The composer may optionally attach the comment to:

- the complete request;
- one retained request line;
- the current arrangement revision;
- a dispatch or Delivery Order snapshot;
- a receipt review; or
- a material return.

The user chooses context from a short **Regarding** control or arrives with it
preselected from the relevant lifecycle action. The server verifies that the
context belongs to the same request. The visible context chip opens that
retained record without changing the discussion.

## 4. Visual handoff

### 4.1 Desktop

- The section occupies the full detail canvas below the lifecycle layout.
- Use the existing request surface, border, radius, shadow and typography
  tokens.
- Header padding: `AppSpacing.lg`; body and composer spacing use existing
  `AppSpacing` tokens.
- Header order: icon, **Request discussion**, comment-count pill, helper text,
  then trailing **Start team conversation**.
- The timeline uses rows separated by `AppColors.line`; it must not resemble
  chat bubbles or social media.
- Author, exact role and timestamp stay visible. Mentions use the standard blue
  link treatment. Context and attachments use compact bordered chips/cards.
- The composer spans the card width. It grows from one to six lines and keeps
  Mention, Attach and **Post comment** visible.
- The complete section uses normal page scrolling. With many comments, show
  the newest 20 and a **Load earlier comments** control rather than nesting a
  long independent scroll region.

### 4.2 Tablet

- Use the same one-column order as desktop with `AppSpacing.lg` page padding.
- Header actions wrap below the title when required.
- Comment metadata may wrap to a second line; body and evidence remain full
  width.
- The composer remains inline in landscape and portrait.

### 4.3 Mobile

- Use a single full-width card with the standard mobile horizontal inset.
- Minimum interactive target is 44 by 44 logical pixels.
- Put **Start team conversation** below the helper as a full-width outlined
  action.
- Each comment shows avatar, name/role, timestamp, body, context/evidence and
  Reply in logical reading order.
- The composer remains at the end of the section. When focused, keep the field
  and post action above the keyboard and safe-area inset.
- The mobile screen uses page scrolling; it must not shrink the desktop row or
  create horizontal scrolling.

### 4.4 Design tokens

| Purpose | Repository token |
|---|---|
| Primary action and links | `AppColors.blue` / existing primary token |
| Main text | `AppColors.ink` |
| Secondary text | `AppColors.muted` / `onSurfaceVariant` |
| Surface | existing request/card surface tokens |
| Border and separators | `AppColors.line` / `lineStrong` |
| Title | `AppTypography.titleMedium` with established strong weight |
| Body | `AppTypography.bodyMedium` |
| Metadata | `AppTypography.labelMedium` / `bodySmall` |
| Spacing, radius, targets | `AppSpacing` tokens only |

No new palette, font family, arbitrary radius or hard-coded user-facing string
is introduced.

## 5. Interaction states

| State | Required behavior |
|---|---|
| Loading | Preserve the request page; show bounded comment skeleton rows. |
| Empty | Show “No comments yet” and keep the composer immediately available. |
| Typing mention | Show authorized results anchored to the composer; keyboard navigation and Escape work. |
| Uploading | Show each file with progress, retry and remove-before-post actions. |
| Posting | Disable duplicate submission, retain text/files and show progress. |
| Success | Append the server-returned comment, clear the composer and announce success. |
| Recoverable failure | Keep the complete draft and attachments; explain whether retry is safe. |
| Uncertain result | Reconcile by idempotency key before enabling another post. |
| Offline | Preserve a local comment draft, label it “Not posted”, and require online server confirmation. |
| Stale access | Keep readable confirmed data where allowed; disable posting and refresh authority. |
| Unauthorized | Show no comment body, count, attachment metadata or mention candidate. |
| Closed request | Allow authorized comments with a clear “Request closed” context; comments do not reopen it. |
| Archived request | Read-only retained discussion through the authorized history route. |

## 6. Exact-comment notification navigation

A comment mention notification stores structured destination data:

- event code `material_request_mentioned`;
- canonical entity type `chat_message`;
- Material Request ID;
- comment ID; and
- optional project ID for authorized context.

Opening it performs this sequence:

1. resolve current request access on the server;
2. open the canonical Material Request detail route with the comment ID as a
   route parameter/query value;
3. fetch the comment context and the cursor window containing it if it is not
   in the newest page;
4. build the discussion section and scroll the page to the comment;
5. move accessibility focus to the comment, announce author and time, and show
   a subtle two-second highlight unless reduced motion is enabled; and
6. retain the existing server-owned notification read command and unread-count
   authority. Delaying acknowledgement until after anchor rendering is a D04
   staging acceptance follow-up, not a locally verified claim.

If the request is no longer accessible, show an actionable access message and
do not reveal the comment. If the comment was redacted or cannot be found,
open the discussion and explain its retained state.

## 7. Security and server authority

- Widgets call a Riverpod controller, which calls the normalized repository
  and trusted RPCs. Widgets never write Supabase directly.
- Read/post/reply/mention/attachment checks occur on the server using active
  identity, exact capability, request participation and current dated scope.
- Admin has no silent bypass that fabricates missing workflow membership or
  history.
- Direct table APIs remain denied to browser clients.
- Storage authorization follows current request and document access.
- Comment, attachment, notification and audit creation is transactional and
  idempotent.
- The count pill reports loaded rows and appends `+` whenever older rows may
  exist; it never presents a partial page as the exact total.
- Realtime is a refresh signal only.

## 8. Data and API additions

Use additive, repeatable migrations. Preserve every existing normalized
comment and mention ID.

Required additions, subject to the existing schema audit:

- nullable `parent_comment_id` with same-request validation;
- typed nullable context kind and context ID;
- normalized comment-to-document links;
- a protected “comment context/window” read RPC for exact anchors;
- a truthful bounded-history indicator in the role-safe request surface; and
- structured notification destination metadata for comment anchors.

The existing add-comment RPC should be extended or versioned to accept parent,
context and finalized attachment IDs with one request hash and idempotency key.
It must validate every relation, lock deterministically, and return the complete
new role-safe comment.

## 9. Accessibility and localization

- All copy is centralized for English and every configured secondary language.
- Arabic and Urdu render RTL while IDs, references and email addresses retain
  their correct direction.
- Screen-reader order is header, context, author/role/time, body, evidence,
  reply/actions, composer.
- New comments, post success, upload failure and exact-comment arrival are
  announced through a polite live region.
- Tab/Shift+Tab order follows visible order. Enter posts only when the composer
  uses the documented shortcut; plain Enter inserts a new line. Provide a
  visible keyboard hint if `Cmd/Ctrl+Enter` posts.
- Focus is never lost after loading earlier comments.
- Status and mention meaning do not depend on color alone.

## 10. Performance requirements

- Request summary/register projections contain no comment bodies or attachment
  metadata.
- Detail loads the newest 20 comments. Earlier history uses cursor paging.
- Exact-comment navigation fetches a bounded window around the requested ID.
- Attachment previews are lazy; images use thumbnails rather than original
  bytes in the timeline.
- Posting one comment causes one bounded reconciliation, not a full workspace
  reload.
- Prove acceptable behavior with 500 comments, 20 attachments in the visible
  page, long localized names and a slow connection. Record observed timings;
  do not invent an SLA.

## 11. Acceptance scenarios

The release is incomplete until tests and staging witnesses prove:

1. Creator can comment on their server-backed Draft; another participant
   cannot discover that discussion before submission.
2. Every authorized lifecycle participant sees the same ordered discussion.
3. An unauthorized, revoked, inactive or wrong-project actor receives no
   comment or attachment data through UI, route, RPC, table or Storage access.
4. A selected mention notifies exactly once; typed unselected `@name` does not.
5. A notification opens and focuses an exact newest and exact older comment.
6. A retry cannot duplicate a comment, reply, attachment, notification or
   audit event.
7. A failed/uncertain post preserves the complete draft and reconciles safely.
8. An attachment cannot be downloaded after its viewer loses request access.
9. A reply keeps one-level chronology and the correct immutable parent.
10. A comment cannot mutate any Material Request lifecycle state or quantity.
11. Closed requests remain discussable; archived requests remain read-only.
12. Desktop, tablet and 390/360 mobile layouts have no overflow and retain
    44-by-44 targets.
13. Keyboard, screen reader, 200% text, RTL and reduced-motion checks pass.
14. Large history paging preserves position and does not duplicate rows.
15. Team Chat creation is optional, separately authorized and linked back to
    the request without copying comments.

## 12. Delivery plan

### D01 — Layout and canonical thread

Move the existing normalized discussion to the full-width final section,
remove the right-rail card, preserve current comments/mentions and prove
desktop/tablet/mobile states.

### D02 — Replies, context and direct attachments

Add the protected schema/RPC extensions, controlled uploads, one-level replies
and lifecycle context chips with database authorization and idempotency tests.

### D03 — Exact navigation and production notification behavior

Add the bounded comment-window projection, structured destinations, scroll,
focus, highlight, Realtime refresh and delivery/read reconciliation.

### D04 — Staging acceptance and release

Deploy one immutable candidate to Yorks staging. Witness Engineering,
Procurement, Admin and negative personas across desktop, tablet and mobile;
verify files, notifications, deep links, offline recovery and accessibility.
Only the accepted artifact advances to the normal production release gates.

## 13. Visual references

- `designs/material-request-discussion-desktop-v1.png`
- `designs/material-request-discussion-mobile-v1.png`

These images define information hierarchy and composition. Repository design
tokens and this behavioral specification remain authoritative for exact
implementation.
