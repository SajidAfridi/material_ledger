# Material Requests for project and company use

Status: **advisory audit and proposed product extension; not approved or implemented**

Audit date: 4 September 2026

Source baseline: local `f37ee8a40515` plus existing uncommitted work.

Follow-up: the [lifecycle and control review](COMPANY_MATERIAL_REQUEST_LIFECYCLE_REVIEW.md)
develops the safety-jacket example, approval routing, demand planning and
beneficiary issue history after review of the actual desktop screenshots. Use
that review for the expanded process proposal. The earlier in-conversation interactive form is exploratory placement evidence,
not a replacement desktop design.

## Recommendation

Keep **Material Requests** as the shared place to request materials and track
fulfilment. Extend its existing **New request** action with two choices inside
the Details step: **Project use** and **Company use**. Keep one authorized
Procurement work queue, with a visible request type and destination.

Project use already supports materials that are not in the BOQ. Company use
means supplies for an internal office, workshop or other approved company
destination without charging the need to a particular project. It needs an
explicit ownership and approval model, not just a new form field.

This proposal interprets “company materials” as physical supplies. Services,
maintenance jobs, employee reimbursements, tool loans and warehouse
replenishment planning are separate product decisions.

## What the audit established

| Finding | Consequence | Local evidence |
|---|---|---|
| Engineering and Procurement already have Material Requests in primary navigation on desktop and mobile. | The existing destination fits both audiences and avoids an additional top-level module. | [Workspace shell](../../lib/app/yorks_v1_workspace_shell.dart), lines 327–345, 395–404 and 695–701. |
| The register already provides New Request; project workspace and BOQ also provide contextual creation. | Keep the global action and preserve shortcuts that prefill project context. | [Desktop register](../../lib/features/materials/presentation/screens/yorks_v1_material_request_centre.dart), line 1021; [phone register](../../lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart), line 616; [project workspace](../../lib/features/projects/presentation/screens/yorks_v1_projects_screen.dart), line 3791; [BOQ workspace](../../lib/features/projects/presentation/screens/yorks_v1_boq_screens.dart), line 2741. |
| Custom rows and Excel rows are already allowed. Free text remains available when catalogue search has no match. | An engineer can request an unplanned project material without first adding it to BOQ or inventory. | [Product decisions](PRODUCT_DECISIONS.md), lines 288–350. |
| All current operational MRs require a project and a real Common/building scope. | A wholly custom request is still a project request. There is no current company-use lane. | [MR model](../../lib/shared/models/yorks_v1_material_request.dart), line 1510; [MR schema](../../supabase/migrations/20260802020000_yorks_v1_batch5_material_requests.sql), lines 5–8; [draft-save command](../../supabase/migrations/20260804114500_yorks_v1_material_request_technical_flexibility.sql), lines 112–145. |
| Mobile blocks continuation to Items until project and scope are selected; desktop custom entry also needs project context. | The current composer cannot truthfully represent office-only or general workshop demand. | [MR screens](../../lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart), lines 2841–2848 and 4721–4726. |
| Common is owned by a particular project. | Common / All Buildings is not an organization-wide destination. | [Product decisions](PRODUCT_DECISIONS.md), lines 176–193. |
| New requests follow approval before Procurement arrangement, and Procurement cannot read the unapproved new request. | Submission and handoff to Procurement must be described as separate events. | [Current guide](CURRENT_MATERIAL_REQUEST_USER_GUIDE.md), lines 9–35; [approval-first migration](../../supabase/migrations/20260813101547_material_request_preapproval_comments_inventory_receipt_photos.sql), lines 919–950 and 1092–1102; [capability cutover](../../supabase/migrations/20260824084245_scoped_capability_core_workflow_cutover.sql), lines 236–279. |
| Numbering, authorization, summaries and documents depend on project identity. | Making project optional in the UI or database would leave downstream gaps. | [Product decisions](PRODUCT_DECISIONS.md), section 15; [tracked summary projection](../../supabase/migrations/20260901220449_material_request_action_intelligence.sql), lines 622–623; [MR document projection](../../supabase/migrations/20260813155117_material_request_document_approval_actor.sql), lines 30–60 and 77–79. |

## Classify by intended use

The material name alone should not select the workflow. The same item may
belong to either context.

| Example | Best route | Current support |
|---|---|---|
| Duct fittings already listed in a project's BOQ | Project use → project + scope → Add from BOQ | Supported. |
| Gloves, fixings or an unexpected material needed for a particular job | Project use → project + scope → catalogue/custom item | Supported, even if absent from BOQ. |
| Office stationery or general workshop consumables used across jobs | Company use → internal destination → catalogue/custom item | Proposed extension. |
| Stock bought to replenish the central warehouse | Inventory receiving for actual incoming stock; separately specify any replenishment-request process | Receiving exists; it is not evidence of an approved replenishment-demand workflow. |
| A reusable tool loan, repair service or reimbursement | A separately defined custody, service or expense process | Do not silently treat this as ordinary material consumption. |

One request should have one use context and one destination. Mixed project and
company baskets should be split into separate drafts rather than losing the
approval, receipt and reporting boundary.

## Proposed placement and interaction

### Entry points

- **Desktop:** existing sidebar Material Requests → existing New request.
- **Phone:** existing Requests destination → existing New request button.
- **Inside a project:** existing New Request opens Project use with that
  project prefilled. A BOQ-origin request also retains its actual scope and
  source references.
- **Company use:** starts from the global register. Only eligible users see an
  actionable Company use choice; project-only users retain their simple flow.

Do not add a competing Company Requests sidebar item. Do not put initial
request creation inside Inventory, which is primarily a stock-control
workspace with different access. Contextual Team Chat can discuss a request,
but a message is not a submitted, approved or fulfilled request.

### Details → Items → Review

Preserve the current three-step phone flow. Add the use choice at the top of
Details rather than creating a fourth step or another wizard.

| Step | Project use | Company use proposal |
|---|---|---|
| Details | Existing project, Common/building, title, timing and delivery note. | Approved internal destination, purpose, authorized receiving person, timing and delivery note. Requester identity comes from the account. |
| Items | Existing BOQ, catalogue/custom entry and supported import. | Non-commercial catalogue search and free text. No BOQ picker. Description, quantity and unit are required; technical details remain available where relevant. |
| Review | Existing scope, line quantities and applicable Engineering approval destination. | Explicit Company use, location, receiving person, purpose, line quantities and configured approval destination. |

Keep Urgent, Normal and Scheduled semantics; Scheduled requires its date. Do
not invent approval deadlines or spending thresholds. Quantity is deliberate
input, and catalogue selection is not a promise of warehouse availability.

In a populated draft, changing use or destination must explain affected source
links, approval routing and delivery details before proceeding. It must never
silently remap project BOQ rows to company stock demand. After submission,
context changes require a controlled correction or a new linked request.

Suggested copy is **Submit for approval**, followed by **Waiting for [the
authorized approver]** and, only after approval, **Sent to Procurement**. The
existing project-specific approval wording can remain where more precise.
Save draft stays visibly separate. Offline recovery never claims submission.

### Register and Procurement

Keep the existing My Work / All Requests phone views. Add **Use: All / Project /
Company** and destination under the existing Filters control. Provide a
Requested by me filter so the requester can track a submission after its next
action belongs to someone else; My Work must continue to mean actionable work.

Each row/card should show request reference, meaningful title, Project/Company
label, destination, requester, timing, status, current owner and next action.
Show the responsible receiving person in detail. Coordinator, approver,
receiver and workflow owner are distinct responsibilities.

Procurement's My Work includes authorized, approved company requests alongside
project requests. Filters, counts, search, pagination and next-action flags
must come from protected server projections across the full authorized set,
not from client-side merging of independently paginated lists. “All” never
means access to every employee's request.

## Company-use authority to approve before implementation

Recommended initial policy: allow explicitly enabled existing users to request
for assigned internal locations; route approval to an explicitly configured
Admin or company approver; let a designated authorized receiver confirm the
physical delivery. These are proposed rules, not authority currently granted
by job titles, project membership or this audit.

| Decision | Recommended starting rule |
|---|---|
| Who may request? | Existing active accounts with explicit company-request capability and allowed locations. Do not create a new role or enable every employee implicitly. |
| Who approves? | A configured internal approver with location responsibility; an Admin can be explicitly configured initially. Missing configuration blocks submission with a useful explanation. |
| Creator self-approval? | Require a distinct authorized approver for company use initially. Do not inherit the project's temporary adoption policy accidentally. |
| What can Procurement do? | Arrange and dispatch approved demand and confirm physical warehouse returns. It cannot approve the company demand it fulfils. Any future ability to request its own supplies needs the same separate approval. |
| Who confirms delivery? | The designated authorized receiver, with any substitute separately authorized and audited. A typed name or Coordinator assignment cannot grant receipt authority. |
| Who can see the record? | Private draft owner; submitted requester and authorized approver; Procurement after approval; authorized receiver and controlled support according to explicit company policy. Commercial fields remain separately protected. |

Company requests must not grant project/BOQ access, expose inventory balances
to requesters, or enter project billing, progress or Accounts allocations.
Department or location is operational context, not a new accounting ledger.

## Fulfilment and backend boundary

The intended company flow is:

`Private draft → Submit → Internal approval → Procurement arrangement → Dispatch → Receiver review → Explicit closure`

Return for changes, partial supply, Cannot Provide Now, missing/damaged goods,
replacement deliveries, cancellation and eligible returns need explicit
company rules before release. Approval does not reserve or consume stock.
Warehouse stock changes once on committed dispatch; a direct external-source
delivery must not decrement warehouse stock. Only confirmed good warehouse
returns restore usable stock.

Reuse the existing decimal quantity rules, locking, idempotency, immutable
decisions and movements, protected commercial shapes and explicit server
confirmations. Company demand competes with project reservations for the same
single warehouse stock; it cannot introduce a second balance or an independent
reservation pool.

Prefer an additive company-request domain with explicit location ownership and
protected commands, exposed through a common typed register. Preserve current
project request constraints and historical IDs. Shared presentation and
transaction helpers can be reused only where their inputs and invariants
support both contexts. Final schema design should follow a reviewed dependency
map; this document does not prescribe weakening existing foreign keys.

The implementation must cover more than creation:

- company approval routing, read/write authorization, draft recovery and
  capability revocation;
- reservation/dispatch/receipt/return links and competing-stock checks;
- independent controlled numbering and company-appropriate document identity,
  destination and receiver snapshots;
- protected attachments, discussion, notifications, deep links and exports;
- typed register/detail projections and separate project/company reporting.

Workforce already has an internal-location catalogue with code, name and
department. Its [contract](WORKFORCE_ATTENDANCE_TIMESHEETS.md) is Workforce-only;
any shared catalogue needs an explicit ownership and migration decision.
Reusing a location label must not inherit Workforce permissions or create
another warehouse.

Do not create a fictional Company project, reinterpret a project's Common
scope, repurpose a stock adjustment as fulfilment, or revive the legacy request
screen. Those paths do not establish the right requester, approval, receiving
and reporting history.

## Source reconciliation findings

1. The supplied AGENTS canonical chain places arrangement before approval.
   [SOURCE_OF_TRUTH](SOURCE_OF_TRUTH.md), lines 276–311, records the later
   approval-first revision, and the local implementation follows it. This
   audit reports the discrepancy without changing either rule or any workflow.
   Reconcile the contract set before implementation.
2. The phone-creation paragraph in the current guide says Procurement receives
   nothing until Submit. That is an incomplete handoff description:
   [PRODUCT_DECISIONS](PRODUCT_DECISIONS.md), lines 320–321, additionally
   requires Engineering approval before Procurement can read the new request.
3. Project self-approval wording also needs reconciliation.
   PRODUCT_DECISIONS, lines 439–446, excludes a Site Engineer creator. The
   later [capability cutover](../../supabase/migrations/20260824084245_scoped_capability_core_workflow_cutover.sql),
   lines 361–423 and 929–977, allows a Site Engineer with dated Project Engineer
   membership and the relevant capability, and rejects creator approval when
   the published self-approval policy is disabled. The existing
   [test](../../supabase/tests/database/scoped_capability_core_workflow_cutover.test.sql),
   lines 642–662, covers that membership-based approval but not creator
   self-approval. This is a source-level policy inconsistency, not a claimed
   reproduced runtime exploit. Company policy should be explicit.

## Proposed implementation sequence and acceptance

1. Approve company scope, requester/approver/receiver eligibility, self-approval,
   location ownership and controlled-document identity. Reconcile the relevant
   authority documents in the same reviewed change.
2. Implement the protected company domain behind a default-off flag, including
   complete fulfilment and return semantics. Prove positive and negative
   access, stock competition, retry safety and data preservation.
3. Extend the existing composer, register and detail using those server
   projections. Verify desktop and 360px/390px phone layouts, keyboard,
   localization/RTL, 44px actions and honest empty/error/offline states.
4. Run the full applicable Flutter, database and signed-release gates, then
   witness one project request and one company request from draft through
   approval, partial delivery, receipt exceptions, replacement and return.
   Keep project documents, Accounts, Workforce, existing history and other
   modules unchanged except for approved additive integration.

The first accepted slice should complete a real company request end to end.
A visible Company option with no protected approval, receiving or document
path is not a releasable feature.

## Verification and limitations of this audit

- Inspected current local contracts, Flutter routes/navigation/composer,
  repositories, model validation, ordered migrations and relevant test source.
- Viewed stored desktop register, 360px phone register and phone Details
  goldens. They support layout assessment; they are not a fresh live-app or
  production witness. Relevant captures are
  [desktop](../../test/goldens/r35/mr_centre_desktop.png),
  [phone register](../../test/goldens/mobile_batch3/mr_register_360x800.png) and
  [phone Details](../../test/goldens/mobile_batch3/mr_information_360x800.png).
- The checkout was already substantially dirty. Existing work was preserved;
  this audit adds only this advisory document to the repository.
- `git diff --check` passed at the audit baseline. Relative links in this
  document were checked against local files after creation.
- Flutter tests/builds, database reset/pgTAP, authenticated UI and production
  checks were not run for this advisory task. The complete applicable gate is
  **not revalidated against the current dirty baseline**. No schema, app
  behavior, feature flag or deployment was changed.

The in-conversation interactive concept illustrates the use selector only. It
has no backend connection and is not implementation or acceptance evidence.
