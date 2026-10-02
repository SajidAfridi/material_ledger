# Reviewed notification copy

`module_events.v1.json` owns Accounts and Workforce title, action text, urgency
and fallback workspace destination. It generates the Dart module catalogue and
the Edge module catalogue.

`workflow_events.v1.json` contains Project and Company material workflows,
returns, project membership, Team Chat and the privacy-safe unknown-event
fallback. It generates Edge copy. The generator checks exact title/body parity
with the retained Dart workflow-copy API, including its aliases. All envelopes
support English, Arabic, Urdu and Hindi. OS copy contains no user-supplied
comments, person or project names, amounts or arbitrary database text.

Run `python3 tool/generate-notification-catalogue.py` after reviewing a copy
change, then `python3 tool/generate-notification-catalogue.py --check` to verify
the generated output and producer coverage. `--check` never edits tracked files.

Producer coverage projects the effective migration-defined functions by
signature, including replacement, drop and retained rename behavior. It reads
the `event_code` expression of actual notification inserts, including bounded
decision suffixes and the Workforce event/capability pairs. Superseded function
bodies and one-time historical backfills do not create false requirements. An
unsupported dynamic producer fails visibly and must be reviewed. This is a
static source gate; it does not replace live migration/function verification or
delivery tests.

Each installation records its chosen `notification_language` through the
protected registration RPC. The Edge sender chooses copy for that installation
and sends web language and writing direction with the same safe envelope.
Missing or unsupported language values fall back to English.
