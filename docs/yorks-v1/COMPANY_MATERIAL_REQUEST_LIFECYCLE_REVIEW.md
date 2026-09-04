# Company Material Requests — lifecycle and control review

Status: **proposed operating contract for discussion; not approved or implemented**

Reviewed: 4 September 2026, against local `f37ee8a40515` plus the existing
uncommitted work and the two screenshots supplied in this conversation.

## 1. Conclusion and correction to the first proposal

Company use should be a complete company-material requisition process within
Material Requests. The existing project experience stays intact. A selector
beside Request Title chooses the appropriate context, approval route and
receipt rules; it does not itself provide a process.

The earlier [placement audit](COMPANY_MATERIAL_REQUEST_UX_AUDIT_AND_PROPOSAL.md)
identified the right entry point, but did not define planning, approval routing,
beneficiary tracking and post-receipt accountability deeply enough. This review
develops those parts. The earlier interactive composer is an exploratory
concept, not a replacement design for the supplied desktop screen.

Four connected records are needed:

1. **Requisition:** who needs what, why, for whose use, and when.
2. **Approval:** the exact authorized need, responsible approver and decision.
3. **Supply plan and fulfilment:** source, outstanding demand, commitments,
   reservation, dispatch and receipt.
4. **Issue history:** who actually received an individually issued item, or
   which responsible location accepted general supplies, and any later return
   or replacement links.

All company behavior below is a recommendation requiring product approval.
No existing project approval, quantity, receipt or closure rule is changed by
this document.

## 2. Evidence from the current product

The supplied register already has My Material Requests, Coordinated Requests,
My Work, Exceptions, Insights, a project grouping and current-owner/next-action
information. The supplied composer has Request Information, Material Items,
Save draft, Submit for Engineering approval and Stage 1 of 7. These are useful
existing structures to preserve.

| Evidence | Meaning for the extension |
|---|---|
| [Seven stage labels](../../lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart), lines 5566–5584 | Created, Engineering Approval, Procurement Arrangement, Ready for Delivery, Dispatch, Received and Completed already form a familiar lifecycle. |
| [Form fields](../../lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart), line 6667 onward; [UI contract](R35_UI_CONTRACT.md), section 8 | Project and real scope are fundamental current inputs, not optional captions. |
| [Product decisions](PRODUCT_DECISIONS.md), sections 7–12 | Custom materials already work, but project ownership, approval, stock, receipt and closure remain controlled. |
| [Action Intelligence](MATERIAL_REQUEST_ACTION_INTELLIGENCE.md) | The existing product has action ownership, exceptions, quantity history and bounded operational insights worth extending. |
| [Receipt schema](../../supabase/migrations/20260802040000_yorks_v1_batch7_logistics.sql), lines 111–153; [current receipt permission](../../supabase/migrations/20260824084245_scoped_capability_core_workflow_cutover.sql), lines 532–576 | Receipt identifies an authenticated reviewer and dispatch quantities. It does not establish a separate named-beneficiary PPE issue ledger. |
| [Workforce identity](WORKFORCE_ATTENDANCE_TIMESHEETS.md), Worker identity; [worker schema](../../supabase/migrations/20260829225746_yorks_workforce_t01_foundation.sql), lines 230–270 | A worker can have a stable identity without a login. Workforce permissions do not automatically authorize company-material actions. |
| [Controlled returns](MATERIAL_RETURN_CONTROLLED_WORKFLOW.md) | Stock is restored only after protected physical warehouse confirmation. Return provenance and eligibility must extend to company issues. |

Targeted searches found no implemented company-material approval routing or
PPE beneficiary/issue-history domain in the inspected normalized MR paths.
This is a source review, not proof of the current production database state.

## 3. Separate ownership, destination and beneficiary

Company use means the company owns the need independently of a particular
project BOQ. A company-issued safety jacket may still be delivered to a site.
Delivery to a project address does not turn the request into project demand or
grant project membership. Conversely, an item requested under a project's
responsibility remains Project use even if it is collected at the warehouse.

| Field | Purpose |
|---|---|
| Requester | Authenticated person raising the request. |
| Responsible unit | Company department/workshop/site team responsible for the need and approval route. |
| Request for | Myself, named person/people, or general supplies for an authorized location. |
| Beneficiary | Person who will use an individually issued item, distinct from the person entering the request. |
| Delivery/collection point | Where the handover will physically occur. |
| Authorized receiver | Person permitted to acknowledge the delivery or record a witnessed handover. |
| Approver | Independently authorized person who confirms the need. |
| Procurement handler | Person arranging supply and issuing/dispatching it. |
| Coordinator | Optional follow-up responsibility; confers no approval or stock authority. |

The same person may be requester, beneficiary and receiver. The proposed
normal company policy excludes the requester, beneficiary and Procurement
fulfilment actor from approving that demand. A supervisor requesting for a
team therefore uses a separate configured approver.

For general consumables such as printer paper, location receipt is sufficient;
do not require a named end user for every sheet. For personally issued PPE,
retain named-person issue evidence. Reusable asset loans and asset custody need
a separately approved extension; do not infer them from a jacket issue ledger.

## 4. Who approves the jacket?

Use one independent need approval for an ordinary request. Resolve it from a
published company responsibility/routing matrix. Do not force every ordinary
jacket through several management layers, and do not let the requester select
any colleague as an approver.

Recommended starting matrix:

| Request scenario | Proposed approval route |
|---|---|
| Site Engineer requests a jacket for their own use | Configured site/department company-material approver, independent of that engineer. |
| Authorized supervisor requests jackets for workshop staff | Configured workshop approver, such as Workshop In-Charge when that person is neither requester nor beneficiary. |
| Workshop In-Charge requests their own jacket or submits a team request | Configured management approver or named alternate, such as an authorized Project Manager, Senior Mechanical Engineer or Admin. |
| Procurement employee needs company supplies | Independent company approver, if company-request creation is explicitly enabled for that employee. Procurement authority alone does not grant this right. |
| Approver is absent, inactive or conflicted | An explicitly configured eligible alternate; otherwise show Approval route not configured and retain the draft. |

These titles identify possible assignees, not automatic grants. The existing
exact role is `workshop_in_charge`; “workshop manager” in the example does not
create another platform role. Company approval requires its own accepted
capability and effective responsibility, without inheriting global project
Engineering authority.

Configuration must show primary approver, alternate, covered unit/category,
effective dates and policy version. Display the resolved name before Submit.
At approval, recheck current eligibility and reject stale or self-conflicted
decisions. Any rerouting is a reasoned, attributed event; it never rewrites an
earlier decision. Permission administration must also prevent self-granting
company authority.

The approver sees purpose, beneficiary, quantity/specification, relevant prior
issues, overlapping open requests and any available published entitlement rule.
They may approve the exact request version, return it for changes, or reject
with a reason. Quantity reduction should first create a revised request for
review, not silently overwrite the original need.

Company management must decide any PPE allowance, replacement interval,
mandatory evidence, exceptional approvals or spending policy. Until configured,
the product must not invent such limits or claim compliance. Need approval is
not a Purchase Order or a grant of financial authority.

## 5. Worked example: one safety jacket

Illustrative case: an authorized Site Engineer needs one company-issued
safety jacket, size L, replacing a worn jacket. No real employee or transaction
is created by this example.

| Stage | Actor and screen behavior | Committed evidence |
|---|---|---|
| 1. Created | Engineer selects Company use, their responsible unit, Myself, jacket/size/quantity, replacement reason and collection/delivery point. Save draft remains private. | Draft owner/version; current request contents. No stock commitment. |
| 2. Company Approval | Submit allocates a company request reference and sends it to the resolved independent approver. The approver reviews prior issue context and approves, returns or rejects. | Submitted snapshot; routing/policy version; approved need; decision, actor, exact role, reason and time. |
| 3. Procurement Arrangement | After approval, Procurement chooses the actual matching stock item or external source, records supply quantity, readiness/expected date and any shortage action. | Versioned supply plan; reservation when stock is committed; source and follow-up ownership. |
| 4. Ready for Delivery / Collection | The correct jacket is genuinely available for handover. Notify the receiver. An unconfirmed supplier estimate is not readiness. | Confirmed ready quantity and destination; remaining shortage stays explicit. |
| 5. Dispatch / Handover | Procurement hands over or dispatches one jacket against the approved need. Direct collection does not require invented driver/vehicle data. | Immutable delivery/issue note; actual issuer, item/size, quantity, destination and time; warehouse stock movement once. |
| 6. Receipt and Issue Confirmation | Engineer confirms the correct jacket in acceptable condition. The resulting issue is linked to that person. If a supervisor receives for a team, beneficiary allocation is still required. | Receipt outcome plus issue-to-person record; actual confirmer and evidence basis. |
| 7. Completed | An authorized requester/receiver or company request owner explicitly closes after the server confirms no unresolved need, receipt, allocation or custody exception. | Closure actor/time and verified final quantities; history remains searchable. |

This preserves the recognizable seven-stage presentation. Company labels are
contextual; the project labels and commands remain unchanged. The seven labels
are milestones, not a substitute for exact partial, blocked and exception
states.

Direct warehouse collection can complete stages 5 and 6 in the same visit, but
the issue and receiver acknowledgement are distinct facts. Issuing the item
must not automatically mark it received.

For a worker without a login, an authorized receiving supervisor can record
the witnessed handover against the worker's stable identity under a published
attestation policy. Record Beneficiary, Recorded by and Acknowledgement basis
separately. Do not label it as a worker's digital acknowledgement or signature
unless that evidence actually exists. Only the minimum authorized worker
directory fields should be exposed; no salary, leave or unrelated HR data.

## 6. Planning without a project BOQ

Company use needs an approved-demand register and a supply plan. A single
jacket request is valid without an annual plan. A workshop can also submit a
batch request for named staff and a planned period through the same approval
process. Unsubmitted plans and drafts are not Procurement commitments.

Inside Material Requests, selecting Company use should expose an authorized
Planning view with:

- approved material/specification/size and unit;
- responsible unit, beneficiary group and required date, or Not scheduled;
- approved need, delivered-good quantity and outstanding need;
- stock reserved, ready quantity and in-transit quantity;
- external supply quantity, confirmed/estimated availability and reference;
- shortage reason, named handler, next action and manually committed review date;
- links back to each source requisition, without creating duplicate demand.

Procurement can combine compatible supply needs operationally, while every
reservation, delivery and recipient allocation retains its source request.
Keep different sizes/specifications separate. Counts of requests may be
aggregated; quantities with incompatible units must not be summed.

Procurement must record either a meaningful expected availability date or
Unknown availability with a next follow-up action/date for a shortage. An
estimated date is labelled as an estimate. Changing a commitment retains its
former value, actor and reason. These are explicit planning commitments, not
an invented approval SLA. Normal/Urgent/Scheduled request timing remains
consistent with the existing product.

### Approved need must remain distinct from arranged supply

In the current project flow, arrangement snapshots supplied quantities into
the operational approved quantity. That accepted behavior is described in
[PRODUCT_DECISIONS](PRODUCT_DECISIONS.md), section 9. Company demand planning
needs a separate frozen **approved need**, so Procurement shortages cannot
silently reduce the original authorization or erase unmet demand.

Example: **10 jackets approved; 6 supplied and accepted; 4 still required**.
The plan and request remain Partially fulfilled, with Procurement responsible
for the four. They do not become Completed because the first arrangement was
delivered. Only supply or an independently approved withdrawal of the remaining
need resolves the balance.

For a company line, the proposed operational quantities are:

`Requested | Need approved | Reserved | Ready | In transit | Good received | Issued to beneficiary | Outstanding need | Withdrawn remainder | Returned`

Outstanding need is approved need minus confirmed good receipt minus approved
withdrawal of the unfulfilled remainder. It includes quantities in transit;
show transit separately so it is not mistaken for an additional purchasing
requirement. Stock reservation is a subset of that outstanding need, not
another addition to demand.

Goods accepted by a supervisor but not yet issued to the intended workers
appear as **Awaiting beneficiary handover**, not Supply shortage. Retain the
accountable receiver and unallocated quantity. This is transit/issue
accountability, not a new workshop warehouse or a second available-stock pool.

A later legitimate surplus return does not automatically reopen a fulfilled
request. A new replacement after accepted use is a linked new requisition with
its own approval. Cumulative dispatch can exceed approved need when replacing
documented missing/damaged/rejected deliveries; the server caps current good
receipt plus in-transit quantity, not the lifetime dispatch sum.

Periodic templates, entitlement-based demand forecasts, budgets and automated
replenishment are later options. They must never double-count the actual
approved requisitions or manufacture stock/financial commitments.

## 7. Exceptions and alternative paths

| Situation | Required company behavior |
|---|---|
| Approver returns request | Same reference/history, editable revision, reason and resubmission; Procurement cannot fulfil an unapproved revision. |
| Approver rejects request | Terminal rejection with reason; no reservation or stock effect. |
| No matching stock | Procurement records Cannot Provide Now or external sourcing, reason, owner and next follow-up. The approved need remains open. |
| Partial supply | Dispatch ready quantities; preserve remainder and its supply plan. Receipt of one batch does not close the full need. |
| Supplier delay | Retain promised/estimated date history; show an exception and next follow-up, without claiming goods are ready. |
| Wrong size or wrong item | Record Not accepted — incorrect item/size. It is neither good receipt nor falsely labelled damaged. A company-specific receipt outcome and physical custody/return resolution are required. |
| Missing or damaged delivery | Record exact receipt reconciliation; preserve replacement eligibility within the approved need and track any physically held exception goods. |
| Proposed substitute | Present changed specification/size to the authorized request owner/approver and record an approved revision before issue; Procurement cannot silently change the approved item. |
| Previously issued jacket is worn/lost | Create a new request linked to the prior issue, with replacement reason and the applicable policy. A missing older record is Unknown history, not proof of no prior issue. |
| Duplicate-looking request | Show overlapping requests and issue evidence to authorized reviewers. Require an explicit explanation/decision for proceeding; do not confuse legitimate replacement with a transport retry. |
| Requester withdraws remaining need | Approver/authorized company owner records the approved unfulfilled cancellation with reason; release only eligible reservations. Preserve delivered and in-transit facts. |
| Approver/receiver leaves or loses access | Block future unauthorized actions; explicitly reroute to an eligible person with history. Do not orphan the request or grant everyone access. |
| Used/surplus item is returned | Start a linked company return with eligibility and condition. Procurement confirms physical receipt; only accepted reusable stock returns to usable balance. Damaged/non-reusable PPE does not automatically restock. |
| Retry or lost response | Reconcile using the same idempotency identity; never issue, reserve, acknowledge or post stock twice. |

A current wrong-size delivery and a replacement after months of legitimate use
are different events. The first is unresolved fulfilment of the existing need;
the second is new demand linked to an earlier accepted issue.

Returns need company-scoped approval, provenance and eligible quantity checks.
They should remain visible in the existing Material Returns area through a
protected Company filter. A person-issue link must cap returns for that person
as well as for the source receipt, preventing two workers from returning the
same shared batch quantity.

## 8. Tracking and audit

Keep the existing register views, with a Project/Company filter and a clear
type/destination label. My Material Requests tracks the creator's records;
My Work follows actual current action authority. Coordination remains separate.

A partial company request can require Procurement to source the remainder
while a receiver acknowledges a delivered batch. Store actionable work at the
line/batch level and project all applicable authorized tasks. A prominent next
action may be prioritized, but a single owner label must not hide another
person's outstanding work. Request counts deduplicate request IDs; action
counts are labelled separately.

Inside the Company view, provide **Requests**, **Planning** and **Issue history**
as local views. Preserve the existing project grouping when Project use is
selected. Do not replace the screenshots' navigation or introduce a competing
top-level company-request module.

For an individual jacket, Issue history answers:

- Who received it, with stable identity and historical display details?
- What item, specification/size and quantity were issued?
- Which request, approval, supplier/warehouse source and dispatch supplied it?
- Who physically issued it, who recorded receipt, and when?
- Was acknowledgement direct, witnessed or supported by an actual attachment?
- Was it subsequently returned, replaced or otherwise resolved?

Do not call historical issues a count of currently usable jackets: subsequent
condition/use is unknown unless recorded. Viewing the ledger requires explicit
company/person scope; colleagues must not browse everyone's PPE history.

Each critical event is generated with the transaction on the server, retaining
actor, exact role, capability/responsibility, server time, request/line/version,
before/after facts, reason, policy version where relevant and related evidence.
Business history is append-only; correction appends a linked event.

Suggested event family: request submitted; approval routed/rerouted; returned,
rejected or approved; supply plan revised; reservation created/released;
delivery ready; dispatched/handed over; receipt confirmed/exception recorded;
beneficiary issue confirmed; remainder withdrawn; request closed; return
approved/confirmed; replacement linked. These are proposed names, not existing
RPCs or implemented audit types.

Documents should distinguish the submitted company requisition, approval,
delivery/issue note, receipt, person issue and return. Numbering is controlled
and company-specific. No fake project/job/BOQ identity is printed. Every
document retains a snapshot/revision; later corrections do not rewrite signed
or issued historical evidence. Commercial versions remain capability-controlled.

## 9. How the supplied screen changes

| Existing area | Company-context adaptation |
|---|---|
| Request Title row | Add Request use dropdown beside the title; stack it above title on narrow screens. Project remains the default and is prefilled from project/BOQ entry. |
| Project / Building fields | Show Responsible unit, Request for/beneficiaries and Delivery/collection point. No synthetic Company project. |
| Request Timing | Retain existing timing; Scheduled requires its date. |
| Material Items | Keep the established table/editor and technical fields. Use catalogue/custom entry; project BOQ actions are absent in Company context. Any company import must validate its own recipient/specification schema. |
| Request context panel | Show resolved approver, recipient/receiver, relevant prior issues and unresolved related requests. |
| Submit button | Submit for Company approval; confirmation names the actual resolved approver. Draft and critical-action confirmation behavior remain familiar. |
| Stage 2 | Company Approval, with the authorized person's name. |
| Stages 3–6 | Supply planning and delivery/collection, including partial need and beneficiary handover. |
| Request detail | Retain the existing layout; add company demand/issue facts, policy/approval route, evidence and exceptions. |
| Register and Insights | Type-aware filters and counts; company demand and issue measures stay separate from project BOQ and Accounts metrics. |

On phones, keep Details → Items → Review as the composer steps. Those three
entry steps are different from the seven lifecycle milestones. The previous
proposal should not be read as replacing the desktop layout with a small
three-step form.

## 10. Implementation scope and maturity gate

The shared user interface can remain familiar while company ownership and
authorization are implemented additively. Reuse proven UI, quantity arithmetic,
document tooling and transactional helpers where semantics match. Preserve
project constraints; do not make a null project ID mean organization-wide access.

P0 is a complete company requisition, independent approval, bounded demand
planning, supply/receipt exceptions, issue-to-person/location history,
notifications, controlled documents, returns and final closure. Company
inventory reservations compete atomically with project reservations for the
same single warehouse. No parallel balance or reservation authority is allowed.

The first release can focus on general supplies and personally issued PPE.
Recurring demand templates, formal budgets, automated entitlement decisions,
asset loans, payroll deductions, PO approval and regulatory certification are
outside this proposed first slice. External buying follows the separately
authorized company buying process; source/reference/expected delivery evidence
can be linked without claiming this MR is a Purchase Order or payment approval.

Acceptance must prove:

1. An eligible Site Engineer can request one jacket, but cannot approve their
   own request or read another unit's protected history.
2. A Workshop In-Charge request resolves to an independent management approver,
   and missing/expired/conflicted routing fails explicitly.
3. Procurement cannot approve demand or impersonate a receiver; approvals and
   evidence require their exact authority even through direct RPC/table attempts.
4. Ten approved jackets with six accepted leave four visible and actionable;
   neither partial supply nor all-unavailable supply silently closes the need.
5. An unchanged retry creates one reference, approval, reservation, movement,
   receipt and issue event. Competing project/company dispatches cannot oversell.
6. Wrong size, missing, damaged and substitute cases retain accurate facts and
   controlled replacement/return eligibility.
7. Supervisor receipt of a batch does not fabricate worker handovers. Named
   issue quantities cannot exceed attributable good receipt or be allocated twice.
8. A worker without a login can receive through explicit authorized attestation;
   recorded-by and beneficiary identities remain separate.
9. Revoked roles, inactive recipients and stale versions are handled without
   silent overwrite, leaked costs or invented authority.
10. Partial receipt and partial supply expose simultaneous tasks correctly;
    request counts do not double-count the tasks.
11. Closure requires zero unresolved approved need and applicable receipt,
    beneficiary-allocation and custody exceptions. Later returns preserve history.
12. UI, server queries, caches, search, exports, attachments, Team Chat and
    notifications all apply the same company scope and commercial restrictions.
13. Existing project request behavior and documents pass regression evidence;
    Accounts, Workforce, HR and other module authority do not expand implicitly.
14. Desktop and 360px/mobile evidence covers English/secondary language, RTL
    where applicable, keyboard/focus, 44px actions, offline/uncertain states and
    large-request pagination. Full repository release gates remain applicable.

Measure approval-to-arrangement time, outstanding approved demand by compatible
item/unit, commitment slippage, receipt turnaround, unallocated person issues
and exceptions from real server facts. Acceptance targets for orphan actions,
duplicate movements and false closure are zero. Operational time targets and
PPE allowances require company policy; no numerical SLA is invented here.

## 11. Decisions needed and audit limits

The recommended design is concrete enough to review. The business still needs
to nominate company units, primary/alternate approvers, eligible requester and
receiver populations, and the person-handover/attestation policy. Any allowance,
replacement evidence or additional spending approval must be supplied rather
than guessed. Authorizing this review does not publish those settings.

The earlier audit also records the mismatch between the supplied AGENTS
arrangement-before-approval wording and the repository's later approval-first
revision, plus self-approval wording that needs reconciliation. This review
uses the screenshot and current source to describe observed project behavior;
it does not resolve conflicting authority by changing a project command.

Reviewed current screenshots, source, mandatory product contracts, action
intelligence, receipt authorization, worker identity and return controls. No
application code, schema, feature flag, access assignment or production data
was changed. Full Flutter/database/live-app gates were not rerun for this
document-only review; the dirty application baseline remains unverified by
this turn. Documentation links and whitespace were checked locally.
