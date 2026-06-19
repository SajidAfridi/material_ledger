# GodownPro — Development & Architecture Guide

> **Codename**: The Architectural Ledger  
> **Framework**: Flutter (Dart ^3.10.4)  
> **Last Updated**: April 2026

---

## 1. Project Overview

GodownPro is an **HVAC supply warehouse management app** built with Flutter. It targets mobile (iOS/Android) and adapts to tablet/desktop viewports. The app manages inventory materials (valves, pipes, fittings, fasteners, ducts, insulation, etc.), tracks incoming/outgoing transactions, and presents data through a premium editorial UI.

### Brand Identity
- **App Name**: GodownPro
- **Design Language**: "The Architectural Ledger" — industrial precision meets editorial clarity
- **Primary Audience**: HVAC supply warehouse managers, site engineers, and office admins
- **Industry Focus**: HVAC supplying — valves, gates, pipes, fittings, nuts, bolts, ducts, insulation, controls
- **Language**: English primary + bilingual secondary (Arabic, Urdu, Hindi)
- **Default Currency**: AED (Dirhams) — configurable to PKR, INR, USD

---

## 2. Architecture & Project Structure

### Layer Separation
```
lib/
├── main.dart                    # Entry point, SharedPreferences init, ProviderScope
├── app/
│   ├── app.dart                 # MaterialLedgerApp root widget + appRouterProvider
│   ├── router.dart              # GoRouter config with redirect logic + RoutePaths
│   └── shell_screen.dart        # Persistent bottom NavigationBar shell
├── core/
│   ├── constants/
│   │   ├── constants.dart       # Barrel export
│   │   ├── app_colors.dart      # All color tokens (MD3 tonal system)
│   │   ├── app_spacing.dart     # Spacing, radius, blur, tap-target tokens
│   │   └── app_typography.dart  # Full text style scale (Inter + Urdu style)
│   ├── extensions/
│   │   └── context_extensions.dart  # BuildContext helpers (theme, screen size)
│   ├── theme/
│   │   └── app_theme.dart       # ThemeData assembly from all tokens
│   └── widgets/
│       ├── widgets.dart         # Barrel export
│       ├── app_buttons.dart     # PrimaryButton (gradient), SecondaryButton (ghost)
│       ├── bilingual_text.dart  # BilingualText (English + secondary language pair)
│       ├── category_icons.dart  # CategoryIcons mapping enum → IconData
│       ├── ledger_card.dart     # LedgerCard (tonal layering, no borders)
│       ├── ledger_text_field.dart  # LedgerTextField (flat, bottom-stroke focus)
│       └── status_chip.dart     # StatusChip (10% fill + 100% text color)
├── features/
│   ├── onboarding/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── splash_screen.dart           # Animated brand splash
│   │       │   └── language_selection_screen.dart  # Language picker + onboarding
│   │       └── widgets/                         # (empty — inline widgets)
│   ├── login/
│   │   └── presentation/
│   │       └── screens/
│   │           └── login_screen.dart            # Responsive login (mobile + wide)
│   ├── dashboard/
│   │   └── presentation/
│   │       └── screens/
│   │           └── dashboard_screen.dart        # Hero metric, quick stats, recent activity
│   ├── inventory/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── inventory_screen.dart        # Material list with CRUD
│   │       └── widgets/
│   │           └── add_material_sheet.dart       # Bottom sheet form for adding materials
│   ├── transactions/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── transactions_screen.dart     # Transaction history list
│   │       └── widgets/
│   │           └── record_transaction_sheet.dart # Bottom sheet for recording in/out
│   └── settings/
│       └── presentation/
│           └── screens/
│               └── settings_screen.dart         # Language, currency, logout, pickers
└── shared/
    ├── models/
    │   ├── app_currency.dart         # AppCurrency enum (AED, PKR, INR, USD)
    │   ├── app_language.dart         # AppLanguage enum (en, ar, ur, hi) + RTL flag
    │   ├── app_strings.dart          # TranslatableString + ALL UI string translations
    │   ├── inventory_transaction.dart # InventoryTransaction model + JSON serialization
    │   └── material_item.dart        # MaterialItem + MaterialCategory + MaterialUnit + StockStatus
    └── providers/
        ├── language_provider.dart    # Language, currency, onboarding, auth providers
        └── inventory_provider.dart   # Materials, transactions, derived providers
```

### State Management: Riverpod

All state is managed via **flutter_riverpod** `StateNotifierProvider`s:

| Provider | Type | Purpose |
|---|---|---|
| `sharedPreferencesProvider` | `Provider<SharedPreferences>` | Injected at app start via `ProviderScope.overrides` |
| `onboardingCompleteProvider` | `StateNotifierProvider<bool>` | Tracks whether user completed language selection |
| `authSessionProvider` | `StateNotifierProvider<bool>` | Tracks login/logout state |
| `languageProvider` | `StateNotifierProvider<AppLanguage>` | Currently selected secondary language |
| `currencyProvider` | `StateNotifierProvider<AppCurrency>` | Currently selected currency |
| `materialsProvider` | `StateNotifierProvider<List<MaterialItem>>` | All inventory materials |
| `transactionsProvider` | `StateNotifierProvider<List<InventoryTransaction>>` | All transaction records |
| `totalStockValueProvider` | `Provider<double>` | Derived: sum of all item values |
| `materialCountProvider` | `Provider<int>` | Derived: count of unique materials |
| `transactionCountProvider` | `Provider<int>` | Derived: count of transactions |
| `recentTransactionsProvider` | `Provider<List<InventoryTransaction>>` | Derived: last 10 transactions |

### Routing: GoRouter

Navigation uses **go_router** with a centralized redirect guard:

```
Splash → Language Selection → Login → [Shell: Dashboard | Inventory | Transactions | Settings]
```

**Redirect logic:**
1. Splash screen always allowed through
2. If not onboarded → force to splash/language selection
3. If onboarded but not logged in → force to login
4. If logged in and visiting onboarding/login → redirect to dashboard

The **ShellRoute** wraps the 4 main tabs with a persistent `NavigationBar`.

### Persistence: SharedPreferences

All data is stored locally via `shared_preferences`:
- Language selection (`selected_language`)
- Currency selection (`selected_currency`)
- Onboarding completion flag (`onboarding_complete`)
- Login session flag (`is_logged_in`)
- Materials list (JSON-encoded string: `materials_list`)
- Transactions list (JSON-encoded string: `transactions_list`)

Models have `toJson()` / `fromJson()` and static `encodeList()` / `decodeList()` helpers for serialization.

---

## 3. Design Principles (Enforced in Code)

These are the non-negotiable design rules from `design.md` — **enforced programmatically** in the theme and widget layer:

### 🚫 The "No-Line" Rule
> **1px solid borders are PROHIBITED for sectioning.**

- Boundaries are defined through background color shifts (tonal layering)
- `DividerTheme` is set to `thickness: 0`, `color: transparent`
- List items separated by 12px white space (`AppSpacing.listItemGap`)
- `LedgerCard` uses `surfaceContainerLowest` on `surface` background — no borders, no shadows

### 🎨 Tonal Surface Hierarchy
Depth via stacking, not shadows:
- **Layer 0 (Base)**: `#F7F9FB` — scaffold/screen background
- **Layer 1 (Worksurface)**: `#ECEEF0` — sidebars, containers
- **Layer 2 (Sheet)**: `#FFFFFF` — cards, primary content

### 🔲 Ghost Borders
When accessibility requires a visible container (e.g., input fields), use `outlineVariant` at **15% opacity** — a suggestion, not a wall. Implemented as `AppColors.ghostBorder`.

### ✨ Glass & Gradient
- Floating elements use semi-transparent `primaryContainer` at 90% opacity + backdrop blur
- Primary CTA buttons use a `LinearGradient` from `primary` → `onPrimaryFixedVariant` at 135°
- Implemented in `AppColors.primaryGradient` and `PrimaryButton`

### 🔤 Bilingual Typography
- Font: **Inter** (via google_fonts) for English — neutral Swiss aesthetic
- Every English label paired with secondary language text
- Secondary text is **2pt smaller**, uses `onSurfaceVariant` color
- **4px gap** between English baseline and secondary text
- Urdu gets special `NotoNastaliqUrdu` font with `lineHeight: 1.5`
- RTL direction applied automatically for Arabic/Urdu
- `BilingualText` widget handles all of this automatically

### 📐 Spacing Philosophy
> *"If you think there is enough padding, add 8px more."*

- Base unit: 4px
- Screen padding: 16px horizontal, 24px vertical
- Card content padding: 24px
- Min tap target: 48px (industrial environment accessibility)

### 🎯 Status Chips
- **No heavy solid blocks** — 10% opacity fill + 100% opacity text
- `StatusChip.success()`, `.warning()`, `.error()`, `.info()` factories
- Stadium-shaped (fully rounded)

### 🔘 Button Design
- **Primary**: Fully rounded (stadium), gradient fill, 48px min height
- **Secondary**: No fill, ghost border only
- Text buttons have stadium shape

### 🚫 No 100% Black
All dark text uses `onSurface` (`#191C1E`), never `#000000`.

### 🚫 No Standard Material Shadows
- Shadows only for Level 3 elevation (floating modals/drawers)
- When used: 24px blur, 0px offset, 4% opacity tinted with primary
- `AppColors.shadow` = `Color(0x0A003FB1)`

---

## 4. Feature Implementation Details

### 4.1 Onboarding Flow

**Splash Screen** (`splash_screen.dart`):
- Full primary-blue gradient background
- 4-phase animation sequence: Logo → Text cascade → Footer → Auto-navigate
- Uses `TickerProviderStateMixin` with 4 separate `AnimationController`s
- Staggered reveal: logo scale/opacity → brand name slide → tagline → Arabic tagline → footer line expand
- Auto-navigates to Language Selection after ~3 seconds
- Sets light status bar icons for dark background

**Language Selection** (`language_selection_screen.dart`):
- Supports: English, Arabic, Urdu, Hindi
- Each language shown as a tonal card with selection indicator (animated checkmark)
- Sticky gradient "Get Started" CTA at bottom
- Info banner about data sync
- Footer with privacy/terms/support links and copyright
- Staggered entrance animations (header → cards → footer)

### 4.2 Login

**Login Screen** (`login_screen.dart`):
- **Responsive**: `< 768px` → mobile layout; `≥ 768px` → wide layout
- **Mobile**: Single column — logo, bilingual "Login" title, email/password fields (LedgerTextField), gradient CTA, hero banner, security footer
- **Wide/Tablet**: Split panel — left branded panel (gradient bg, warehouse image overlay, stats), right sign-in card on surface background
- Form validation: email format + required password
- Auto-login via `authSessionProvider.notifier.login()`
- Uses `AutofillGroup` for credential autofill

### 4.3 Dashboard

**Dashboard Screen** (`dashboard_screen.dart`):
- **Hero Metric Card**: Total stock value in display-large typography with currency format
- **Quick Stats Row**: Material count + Transaction count in paired cards
- **Recent Activity**: Last 10 transactions as cards with direction indicator (green↓ incoming / red↑ outgoing)
- Empty states with bilingual messaging
- Uses `CustomScrollView` with `SliverList.separated`

### 4.4 Inventory

**Inventory Screen** (`inventory_screen.dart`):
- Material list with category icon, name (+ secondary language), status chip, quantity/price/total value stats
- Each card tappable → opens Record Transaction sheet (preselected material)
- Delete with confirmation dialog
- Add button opens `AddMaterialSheet`
- Search icon (placeholder — not yet wired)

**Add Material Sheet** (`add_material_sheet.dart`):
- `DraggableScrollableSheet` modal (92% initial)
- Fields: Name, secondary name, category (horizontal chip selector), unit (horizontal chip selector), quantity + price (side by side), min stock level
- Category/Unit selectors are animated `Wrap` chip grids
- Form validation with bilingual error messages
- Saves via `materialsProvider.notifier.addMaterial()`

### 4.5 Transactions

**Transactions Screen** (`transactions_screen.dart`):
- Chronological list of all transactions
- Each card: direction icon, material name, timestamp, formatted quantity (+/−)
- Notes shown in italic if present
- Filter icon (placeholder — not yet wired)
- Add button opens `RecordTransactionSheet`

**Record Transaction Sheet** (`record_transaction_sheet.dart`):
- Toggle between Incoming/Outgoing (animated pill toggle with success/error tinting)
- Material dropdown selector (or locked preselected material card)
- Quantity input with unit symbol suffix
- Notes field
- Outgoing stock validation (can't exceed available)
- Records transaction AND adjusts material quantity atomically

### 4.6 Settings

**Settings Screen** (`settings_screen.dart`):
- Settings grouped in a single `LedgerCard`
- **Secondary Language**: Opens picker sheet (same card UI as onboarding)
- **Currency**: Opens picker sheet with flags + codes
- **Appearance**: Shows "Light" (placeholder — dark mode not implemented)
- **Backup & Sync**: Placeholder
- **About**: Placeholder
- **Logout**: Confirmation dialog → clears auth session → redirects to login
- App version footer

---

## 5. Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management |
| `go_router` | ^14.8.1 | Declarative routing with redirect guards |
| `google_fonts` | latest | Inter font loading |
| `gap` | latest | `Gap` / `SliverGap` spacing widgets |
| `flutter_svg` | ^2.0.17 | SVG rendering (available, not heavily used yet) |
| `intl` | latest | Date formatting (`DateFormat`) |
| `shared_preferences` | latest | Local key-value persistence |
| `uuid` | ^4.5.1 | UUID v4 generation for IDs |

---

## 6. Data Models

### MaterialItem
```
id: String (UUID v4)
name: String
urduName: String
category: MaterialCategory (valves, pipes, fittings, fasteners, ducts, insulation, electrical, copper, tools, other)
unit: MaterialUnit (kg, tons, bags, pcs, m, sqft, L, m³, rods, sheets, sets, boxes, rolls, ft, in)
quantity: double
unitPrice: double
minStockLevel: double
createdAt: DateTime
updatedAt: DateTime
— derived: totalValue, stockStatus, formattedQuantity
```

### InventoryTransaction
```
id: String (UUID v4)
materialId: String
materialName: String
type: TransactionType (incoming/outgoing)
quantity: double
unitSymbol: String
notes: String
timestamp: DateTime
— derived: formattedQuantity (with +/− prefix)
```

### AppLanguage
```
english (en), arabic (ar), urdu (ur), hindi (hi)
— properties: code, name, nativeName, subtitle, isRtl
```

### AppCurrency
```
aed (AED), pkr (PKR), inr (INR), usd (USD)
— properties: code, name, nativeName, symbol, flag
— method: format(double amount) → "AED 1234.56"
```

---

## 7. Translation System

All UI strings live in `AppStrings` as `TranslatableString` constants:

```dart
static const dashboard = TranslatableString(
  en: 'Dashboard',
  ar: 'لوحة القيادة',
  ur: 'ڈیش بورڈ',
  hi: 'डैशबोर्ड',
);
```

Usage:
```dart
BilingualText(
  english: AppStrings.dashboard.primary,        // always English
  secondary: AppStrings.dashboard.secondary(lang), // per user's language
)
```

When language mode is English, secondary text falls back to **Arabic** so the UI always shows a bilingual pair.

---

## 8. What's Implemented ✅

- [x] Full design token system (colors, spacing, typography, theme)
- [x] MD3 tonal surface hierarchy
- [x] Reusable widget library (BilingualText, LedgerCard, StatusChip, LedgerTextField, PrimaryButton, SecondaryButton, CategoryIcons)
- [x] Onboarding flow (splash → language selection)
- [x] Responsive login screen (mobile + tablet/desktop)
- [x] Dashboard with hero metrics, quick stats, recent activity
- [x] Inventory management (list, add, delete)
- [x] Transaction recording (incoming/outgoing with stock validation)
- [x] Transaction history
- [x] Settings (language picker, currency picker, logout)
- [x] 4-language translation system (EN, AR, UR, HI)
- [x] 4-currency support (AED, PKR, INR, USD)
- [x] SharedPreferences persistence for all data
- [x] GoRouter with redirect guards (onboarding → login → app)
- [x] BuildContext extensions for responsive breakpoints
- [x] Staggered entrance animations on splash and onboarding
- [x] **Browse Materials screen** — hero stats, category filters, data table (web) / card list (mobile), "Add to Request", pagination, **search bar with real-time filtering**
- [x] **Create Material Requisition screen** — project selector (admin-created), general notes, dynamic line items, Save Draft / Submit actions, responsive two-panel (web) / single-column (mobile)
- [x] **Request Detail screen** — back nav, large ID header, status chip, stats row, **dynamic material breakdown from real line items**, request timeline, verification card, action buttons (Download/Print for submitted, Submit/Delete for drafts)
- [x] **Engineer Home screen** — request list with filter tabs (All / Recent / Drafts), responsive grid/list, empty state
- [x] **Engineer Profile screen** — avatar, settings tiles, logout with confirmation
- [x] **Engineer Shell** — responsive navigation (bottom bar mobile, NavigationRail desktop)
- [x] **Project model** — admin-created projects for engineer selection
- [x] **RequestLineItem model** — material + quantity + unit for requisition items
- [x] **MaterialRequest model** — stores actual `lineItems` with request, supports `draft` status, `estimatedValue` and `categoryCount` derived fields
- [x] **Draft line items provider** — manages the request builder state
- [x] **Browse providers** — category filtering, search query filtering, pagination, "Add to Request" integration
- [x] **Save as Draft** — fully functional, saves draft with line items, can submit or delete drafts from detail screen
- [x] **Draft management** — Drafts filter tab, draft status chip, Submit Draft / Delete Draft actions on detail screen
- [x] **SharedPreferences persistence for material requests** — requests survive app restarts, seed data on first launch
- [x] **Browse search** — real-time search filtering by material name, secondary name, or category
- [x] **Quick stats badges** on engineer home — Total / Pending / Drafts count pills
- [x] **Shared About screen** — reusable across Engineer and Admin, brand card, app info tiles, legal links, open source licenses
- [x] **Shared Language/Currency picker sheets** — extracted to `core/widgets/`, used by both Engineer Profile and Admin Settings
- [x] **Engineer Profile** — functional language/currency pickers, About navigation, logout
- [x] **HVAC Supply Optimization** — categories (valves, pipes, fittings, fasteners, ducts, insulation, electrical, copper, tools), units (ft, in, sets, boxes, rolls), 45+ seed materials, HVAC-themed projects and requests, browse filters (Valves & Fittings / Pipes & Ducts / Fasteners & Tools)
- [x] Transaction filtering (fully wired transaction filter dropdown matching `transactionFilterProvider`)
- [x] Material editing (extended `AddMaterialSheet` to support editing existing items, and removed duplicate `EditMaterialSheet` logic)
- [x] Unit test suite for `MaterialsNotifier` (covering HVAC seed materials loading, add/update/delete actions, quantity adjustments, and negative quantity clamping behavior)

## 9. What's Not Yet Implemented 🚧

- [ ] Dark mode theme
- [ ] Backend / cloud sync (Backup & Sync is placeholder)
- [ ] Real authentication (currently mock — any credentials work)
- [ ] Mobile screenshots adaptation (web designs implemented, mobile pending review)

---

## 10. Conventions & Rules for Contributors

1. **Never use 1px borders for layout** — use tonal layering
2. **Never use `Colors.black`** — use `AppColors.onSurface` (#191C1E)
3. **Never use standard Material drop shadows** — use tonal stacking or `AppColors.shadow`
4. **Always show bilingual text** for user-facing labels — use `BilingualText` widget
5. **All interactive elements ≥ 48px height** on mobile
6. **All strings must be in `AppStrings`** with all 4 language translations
7. **All colors must come from `AppColors`** — no inline hex values in feature code
8. **All spacing must come from `AppSpacing`** — no magic numbers
9. **Features follow** `features/<name>/presentation/screens/` and `/widgets/` structure
10. **Models are pure Dart** — no Flutter imports in `shared/models/`
11. **Providers centralized** in `shared/providers/` — features read from these, not create their own
12. **Barrel exports** via `constants.dart` and `widgets.dart` to keep imports clean

