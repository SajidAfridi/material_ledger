# Yorks mobile batch 05 — documents, tools and system states

This batch covers mobile-pack references 40, 41, and 48–52 at the approved
390×844 logical viewport and the required 360×800 adaptive viewport.

## Evidence

The provider-backed Flutter captures are tracked as goldens:

| Ref | Surface | 390×844 | 360×800 | Production boundary |
|---:|---|---|---|---|
| 40 | Documents | [capture](../../../../test/goldens/mobile_batch5/40_documents_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/40_documents_360x800.png) | Existing authorized workspace, classification, link and version commands |
| 41 | Document viewer | [capture](../../../../test/goldens/mobile_batch5/41_document_viewer_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/41_document_viewer_360x800.png) | Existing authorized byte read; PDFs render from those bytes, other types remain download-only |
| 48 | Duct Sizer | [capture](../../../../test/goldens/mobile_batch5/48_duct_sizer_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/48_duct_sizer_360x800.png) | Existing local calculation, save/open/import/export/print behavior |
| 49 | ESP Calculator | [capture](../../../../test/goldens/mobile_batch5/49_esp_calculator_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/49_esp_calculator_360x800.png) | Existing local calculation, row editor, save/open/import/export/print behavior |
| 50 | Profile & Settings | [capture](../../../../test/goldens/mobile_batch5/50_profile_settings_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/50_profile_settings_360x800.png) | Existing preferences, session/profile routes and app-lock control |
| 51 | Offline / sync state | [capture](../../../../test/goldens/mobile_batch5/51_offline_sync_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/51_offline_sync_360x800.png) | Existing connectivity/outbox state and retry command; record conflicts stay at the record editor |
| 52 | Empty state | [capture](../../../../test/goldens/mobile_batch5/52_empty_documents_390x844.png) | [capture](../../../../test/goldens/mobile_batch5/52_empty_documents_360x800.png) | A real zero-document projection with the existing authorized Add action |

The fixture is deliberately production-shaped: documents carry actual links,
classification, immutable revision metadata and server actor data. The test
does not use direct Supabase access, a fake commercial field, or a fabricated
conflict payload. It also asserts real document link filters and that global
sync does not offer an invented "Use server" conflict command.

## Visual interpretation

The supplied pack is the hierarchy, density and interaction reference. The
Flutter surfaces intentionally retain the following production exceptions:

- Documents are filtered only by real linked entity types; there is no static
  lifecycle status because the current document projection has none.
- PDF preview reads through the existing authorized repository boundary.
  Excel, Word and image versions remain download-only instead of pretending to
  render a document type the app cannot truthfully preview.
- Duct and ESP preserve their existing calculation input/result shape and
  locally persisted state. The mobile cards are a focused presentation, not a
  second calculator implementation.
- The global sync sheet reports only connectivity and outbox facts. A
  competing-writer conflict must be reconciled on its originating record,
  where both server and local values are available.

No claim of literal pixel parity is made from this capture set: the R38/mobile
pack contains a visual prototype, while these screens retain existing
controller-backed behavior and documented production exceptions.

## Verification

```text
flutter test test/yorks_mobile_documents_tools_system_batch5_test.dart
```

Result: 16/16 passing after golden generation and on the subsequent normal
comparison run. The suite checks 14 captures, actual document-scope filtering,
and truthful global conflict handling.
