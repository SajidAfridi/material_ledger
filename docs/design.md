# Design System Specification: The Architectural Ledger
 
## 1. Overview & Creative North Star
This design system is built for the rugged precision of construction management. Our Creative North Star is **"The Architectural Ledger"**—a visual language that balances the industrial weight of raw materials with the sophisticated clarity of a high-end editorial publication. 
 
Instead of a generic utility tool, this system treats data as a curated exhibition. We move beyond the "standard dashboard" by utilizing intentional white space, bold typographic scales, and a departure from traditional structural lines. By favoring **asymmetric layouts** and **tonal layering** over borders, we create an interface that feels open, breathable, and premium.
 
## 2. Colors & Chromatic Logic
The color palette is rooted in a deep, authoritative blue, supported by high-visibility functional tones. We utilize the Material Design 3 (MD3) tonal system to define hierarchy through color rather than chrome.
 
### The "No-Line" Rule
To achieve a signature premium look, **1px solid borders are prohibited for sectioning.** Boundaries between content areas must be defined solely through background color shifts.
*   **Background (`#F7F9FB`)**: Use as the base canvas for the entire application.
*   **Surface Container Low (`#F2F4F6`)**: Use for large structural areas like sidebars or secondary content zones.
*   **Surface Container Lowest (`#FFFFFF`)**: Reserved for primary content "sheets" or cards. The shift from a `low` background to a `lowest` surface creates a natural, soft-edge lift without the need for a stroke.
 
### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. 
*   **Layer 0 (Base)**: `surface` (`#F7F9FB`)
*   **Layer 1 (The Worksurface)**: `surface_container` (`#ECEEF0`)
*   **Layer 2 (The Sheet)**: `surface_container_lowest` (`#FFFFFF`)
*   **The "Glass & Gradient" Rule**: For floating mobile elements (e.g., FABs or floating navigation), use a semi-transparent `primary_container` (`#1A56DB` at 90% opacity) with a `backdrop-blur` of 12px. Main CTAs should feature a subtle linear gradient from `primary` to `on_primary_fixed_variant` at a 135° angle to provide "soul" and depth.
 
## 3. Typography: The Bilingual Stack
The typography system uses **Inter** for its neutral, high-legibility "Swiss" aesthetic. In this system, typography is the primary driver of the brand's authoritative voice.
 
### The Editorial Scale
*   **Display Large (56px)**: Used for hero metrics (e.g., Total Stock Value). High-contrast, tight tracking (-2%).
*   **Headline Medium (28px)**: Used for section titles.
*   **Label Medium (12px)**: Used for metadata and the Urdu translation layer.
 
### Bilingual Implementation
Every English label must be paired with its Urdu counterpart. This is not just a translation; it is a typographic element.
*   **English (Primary)**: Set in `title-sm` or `body-md` using `on_surface`.
*   **Urdu (Secondary)**: Set 2pt smaller than the English text, using `on_surface_variant` (`#434654`). 
*   **Layout**: The Urdu text sits exactly 4px below the English baseline. The Urdu font should utilize a slightly increased line-height (1.5) to accommodate the descending calligraphic strokes of the script without crowding the English text.
 
## 4. Elevation & Depth: Tonal Layering
We reject the "drop shadow" of 2010. Depth in this system is achieved through ambient light and tonal shifts.
 
*   **The Layering Principle**: Depth is created by "stacking." Place a `surface_container_lowest` card on a `surface_container_low` section to create a soft, natural lift.
*   **Ambient Shadows**: Shadows are only permitted for "Level 3" elevation (floating modals/drawers). Use a 24px blur, 0px offset, and a 4% opacity shadow tinted with `primary` (`#003FB1`). It should feel like an atmospheric glow, not a dark smudge.
*   **The "Ghost Border"**: For input fields or where accessibility requires a container, use the `outline_variant` token at **15% opacity**. This creates a "suggestion" of a container that guides the eye without cluttering the canvas.
 
## 5. Components & Interaction Patterns
 
### Buttons
*   **Primary**: Fully rounded (`full` radius) to contrast against the sharp, rectangular nature of construction materials. Use the primary-to-variant gradient.
*   **Secondary**: No fill. Uses a `ghost border` (15% outline-variant). 
*   **Large Tap Targets**: On mobile, all interactive elements must have a minimum height of 48px to accommodate industrial environments where users may have limited dexterity.
 
### Cards & Lists (The Divider-Free Rule)
Forbid the use of divider lines. 
*   **Lists**: Separate list items using 12px of vertical white space or a subtle hover state shift to `surface_container_high`.
*   **Inventory Cards**: Use a `surface_container_lowest` background. Overlap a small "Status Chip" on the top-right corner, breaking the container's grid slightly (asymmetric positioning) to create visual interest.
 
### Input Fields
*   **Styling**: Flat design. Use `surface_container_highest` for the field background with a bottom-only `primary` stroke (2px) that activates on focus. 
*   **Bilingual Labels**: The English label sits above the field; the Urdu helper text sits inside the field as a permanent placeholder until text entry.
 
### Inventory Chips
*   **Success/Warning/Error**: Do not use heavy solid blocks of color. Use a 10% opacity fill of the status color with a 100% opacity text color (e.g., `on_error_container` text on `error_container` background).
 
## 6. Do’s and Don’ts
 
### Do:
*   **Do** use extreme white space. If you think there is enough padding, add 8px more.
*   **Do** use the `primary_fixed` color for "Selected" states in the sidebar navigation to create a soft, high-end highlight.
*   **Do** ensure the Urdu script is vertically aligned to its own optical center, not the English baseline.
 
### Don’t:
*   **Don't** use 100% black. Ever. Use `on_surface` (`#191C1E`) for all dark text.
*   **Don't** use sharp 90-degree corners for buttons; use the `full` or `xl` roundedness scale to keep the UI approachable.
*   **Don't** use standard Material shadows. Rely on background color changes (`surface_container` tiers) to define content blocks.