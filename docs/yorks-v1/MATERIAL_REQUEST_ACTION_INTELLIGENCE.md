# Material Request Action Intelligence

Status: **implemented additive operating contract**
Scope: Material Request register, request line ledger and modest operational
reporting only

This release makes the existing controlled workflow easier to operate. It does
not add a second workflow engine, change any approval authority, expose
commercial values or rewrite retained records.

## Register views

- **Register** shows every Material Request the protected server permits the
  signed-in person to read.
- **My Material Requests** shows records created by that person.
- **Coordinated Requests** shows records where that person is the optional
  follow-up Coordinator. Coordination does not grant workflow authority.
- **My Work** shows only records for which the signed-in person can perform the
  current protected action now. The server reuses the existing approval,
  arrangement, dispatch, receipt and close authorization functions.
- **Exceptions** shows readable, unresolved operational exceptions. It is not
  a client-side status guess.

Every desktop and phone register card continues to show the server-projected
Current owner and Next action. Scheduled requests also show Required on site,
an overdue warning when that date has passed and the request is unresolved,
and the age of the current workflow step.

## Exception definitions

The protected server projection derives these codes from current workflow
facts:

1. unavailable supply in the current arrangement;
2. partial arrangement in the current arrangement;
3. external supply that is not ready after its expected date;
4. unresolved missing receipt quantity;
5. unresolved damaged receipt quantity;
6. replacement quantity still required within the approved cap; and
7. an unresolved Material Return after its requested return date.

Closed or cancelled requests do not retain supply/receipt exceptions. A
missing or damaged fact remains in history, but its current exception clears
when subsequent good receipt resolves the approved requirement.

## Trusted line ledger

The request detail shows one server-aggregated quantity trail per line:

`Requested | Arranged | Reserved | Dispatched | Good | Missing | Damaged | Returned | Still Needed`

- **Reserved** is the remaining quantity on active or partially consumed
  warehouse reservations.
- **Returned** is good quantity physically confirmed back into the warehouse.
- **Still Needed** is requested less good received and in transit. Returning
  legitimate surplus does not reopen the original requirement.
- Existing approval, replacement-eligible and arrangement-reason facts remain
  available where they help the operator understand the record.

The ledger is read-only. Existing transactional commands remain the sole
writers and retain their row locks, quantity caps and idempotency checks.

## Operational insights

The Insights panel is role- and project-scoped and contains no unit cost,
total cost or supplier commercial value. It reports:

- average Engineering approval time from submission to approved decision;
- average arrangement time from approval to the first saved arrangement;
- warehouse fill rate as confirmed good warehouse receipt divided by approved
  warehouse quantity, capped at 100 percent;
- average receipt turnaround from dispatch to confirmed receipt review;
- outstanding replacement quantity within the approved cap; and
- average confirmed Material Return closure time from submission to decision.

Empty samples show an em dash rather than a fabricated zero. Quantities use
Postgres numeric arithmetic and are returned as decimal text.

## Deliberate action-due boundary

Yorks has not approved an SLA that says how many hours each role receives for
approval, arrangement, dispatch, receipt or return work. Therefore:

- Action age is factual and is measured from the request's latest trusted
  workflow update.
- Required-on-site overdue is factual for Scheduled requests.
- An Action due date is **not configured** and is never guessed from role,
  urgency or Required-on-site date.

Adding action deadlines later requires an approved per-action SLA, timezone,
working-calendar behavior, pause rules and escalation owner. Until then the UI
states this limitation clearly.

## Security, compatibility and rollback

- All register, exception, action and insight facts are protected server RPC
  results; UI hiding is not authorization.
- Internal action/exception helpers are executable only by the service role
  and are reached by authenticated users only through protected projections.
- Existing project participation and exact-role rules remain authoritative.
- Existing request, arrangement, reservation, dispatch, receipt and return
  rows are not rewritten.
- Rollback is forward-only by restoring the earlier read projections in a new
  migration. Underlying workflow and audit facts remain intact.
