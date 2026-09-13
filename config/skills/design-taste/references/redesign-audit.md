# Surgical UI Redesign & Modernization Audit

This guide specifies the surgical 3-step audit workflow for uplifting existing, dated, or unstyled codebases to premium quality without breaking functionality or business logic.

---

## The 3-Step Sequence

```
┌─────────────┐       ┌────────────────┐       ┌─────────────┐
│ 1. SCAN     │  ──>  │ 2. DIAGNOSE    │  ──>  │ 3. FIX      │
│ Codebase    │       │ Defect Audit   │       │ Surgical CSS│
└─────────────┘       └────────────────┘       └─────────────┘
```

---

## Step 1: Scan the Codebase

1. **Identify Existing Technologies:** Vanilla CSS, CSS Modules, or inline styles.
2. **Catalog Assets:** Existing logos, color tokens, and font declarations.
3. **Verify Non-Breakable Contracts (Rule D):**
   - Do NOT rename form field `name` or `id` attributes.
   - Do NOT alter API routes or JavaScript state bindings.
   - Do NOT rewrite existing logic; focus strictly on styling, typography, and layout.

---

## Step 2: Diagnose (The Anti-Slop Audit Matrix)

Inspect the interface against these recurring AI and legacy flaws:

### 2.1 Typography Defects
- [ ] **Browser Default or Plain Arial/Inter:** Replace display headlines with a font of character (`Cabinet Grotesk`, `Outfit`, `Geist`).
- [ ] **Headlines Lack Impact:** Tighten letter spacing (`letter-spacing: -0.03em`), reduce line-height (`1.1`), increase weight to 700+.
- [ ] **Body Lines Exceed 65 Characters:** Wrap in `max-width: 65ch` with `line-height: 1.6`.
- [ ] **Numeric Data in Proportional Fonts:** Apply `font-variant-numeric: tabular-nums` or monospace font stack.
- [ ] **Em-Dashes in Copy:** Replace all `—` with clean hyphens or commas.

### 2.2 Color & Surface Defects
- [ ] **Harsh `#000000` Canvas:** Shift to tinted dark (`#090a0c`, `#111317`).
- [ ] **Oversaturated or Multiple Accents:** Desaturate accents (< 80% saturation) and lock to exactly ONE accent color across the page.
- [ ] **Pure Black Low-Opacity Drop Shadows:** Tint box-shadows to match the background hue (e.g. `rgba(0, 0, 0, 0.45)` with ambient spread).
- [ ] **Generic Emissive Glows:** Remove radial purple/blue button glows and blurred neon mesh backgrounds.

### 2.3 Layout & Spacing Defects
- [ ] **Everything Symmetrical / 3 Equal Cards:** Convert to asymmetric 2-column or bento grid with unequal visual weights.
- [ ] **`height: 100vh` in Hero Section:** Replace with `min-height: 100dvh` to fix mobile Safari viewport jumping.
- [ ] **Cramped Padding:** Double vertical section spacing (`padding-block: clamp(4rem, 8vw, 7rem)`).
- [ ] **Mismatched Corner Radii:** Enforce a single concentric radius scale (`--radius-outer` and `--radius-inner`).

### 2.4 Interactive State Defects
- [ ] **Buttons Lack Tactile Feedback:** Add active state `transform: scale(0.98)`.
- [ ] **Ghost Button Low Contrast:** Add semi-opaque background blur (`backdrop-filter: blur(12px)`) and hairline border.
- [ ] **Wrapped Button Text at Desktop:** Shorten labels or remove artificial max-width limits.

---

## Step 3: Surgical Modern CSS Uplift

Apply improvements using isolated CSS overrides:

1. **Inject Modern Design Tokens:** Create or update `:root` custom properties.
2. **Apply Concentric Card Structures:** Upgrade card containers to double-bezel styling.
3. **Refactor Responsive Layouts:** Use native CSS Grid with clean breakpoints (`@media (min-width: 768px)` and `@media (min-width: 1024px)`).
4. **Audit WCAG AA Contrast:** Verify all button labels and text meet minimum 4.5:1 contrast ratios.
