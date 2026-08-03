# Yorks AC. & Ref. — Controlled Project Workspace

> Precision-engineered inventory management for the modern construction site.

<p align="center">
  <img src="assets/logo.png" width="120" alt="Yorks logo" />
</p>

---

## Authority and R35 build

`AGENTS.md`, `docs/yorks-v1/` and the Rev 2.0/R35 source artifacts are the
current product authority. Legacy GodownPro/Nexus documents and workflows are
retained only as migration and regression evidence. Yorks V1 R35 is the
ordinary build experience, while every Supabase target is explicit.

## Overview

Yorks AC. & Ref. is a Flutter-based controlled workspace for projects,
materials, procurement and documents. It helps engineers, procurement and
management coordinate traceable work across projects through a localized,
responsive interface.

## Features

- **📊 Dashboard** — Hero stock value metric, quick stats, recent activity feed
- **📦 Inventory** — Add, view, and delete materials with category/unit/price tracking
- **🔄 Transactions** — Record incoming/outgoing stock movements with audit trail
- **⚙️ Settings** — Language, currency, appearance, and account management
- **🌐 Localization** — English, Arabic, Urdu, or Hindi can be selected; the UI shows the configured language cleanly
- **💱 Multi-Currency** — AED, PKR, INR, USD with formatted display
- **📱 Responsive** — Mobile-first with tablet/desktop adaptive layouts

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart ^3.10.4) |
| State Management | Riverpod (`flutter_riverpod`) |
| Routing | GoRouter (`go_router`) |
| Persistence | Supabase/Postgres authority; SharedPreferences for drafts/cache only |
| Typography | Google Fonts (Inter) |
| Design System | Material Design 3 — custom tonal tokens |

## Getting Started

```bash
# Clone and install dependencies
git clone <repo-url>
cd material_ledger
flutter pub get

# Configure the backend once. This file is ignored by Git and must contain the
# URL and publishable key for the intended local, staging or production target.
cp tool/r35.env.example .r35.env
# Edit .r35.env, then run the complete Yorks V1 R35 experience.
./tool/r35.sh run
```

### Controlled PDF and print builds

The Material Request and final Delivery Order use the same generated A4 PDF
bytes for download, printing and document storage. Build release artifacts with
`--dart-define=use_arabic=true` so the formal bilingual document header is
correctly shaped:

```bash
flutter build web --release
```

### Requirements
- Flutter SDK ^3.10.4
- iOS 12+ / Android API 23+

## Current R35 UI direction

The current Yorks surface follows the effective R35 prototype and
`docs/yorks-v1/R35_UI_CONTRACT.md`: a persistent desktop workspace sidebar,
responsive spreadsheet behavior, focused mobile editors, single-language labels
per user preference, short non-blocking motion and accessible tap targets.
The historical Architectural Ledger rules remain in `docs/design.md` only as
legacy evidence and are not a current UI authority.

## Project Structure

```
lib/
├── app/          # App root, router, shell navigation
├── core/         # Theme, design tokens, reusable widgets
├── features/     # Feature modules (onboarding, login, dashboard, inventory, transactions, settings)
└── shared/       # Data models, providers, translations
```

See [`docs/claude.md`](docs/claude.md) for the full architecture guide.

## Documentation

| Document | Contents |
|---|---|
| [`TERRA.md`](TERRA.md) | Current Yorks V1/R35 reading order and canonical build launcher |
| [`docs/claude.md`](docs/claude.md) | Legacy architecture reference — not current product authority |
| [`docs/design.md`](docs/design.md) | Legacy visual reference — not current product authority |

## License

Private — All rights reserved. © 2024–2026 The Architectural Ledger.
