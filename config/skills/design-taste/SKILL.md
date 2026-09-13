---
name: design-taste
description: Master visual design, styling, and art direction skill. Use for any design or styling task: websites, UI components, HTML/PDF reports, presentations, brand identity systems, mobile screens, or image generation mockups.
user-invocable: true
risk: safe
---

# `design-taste`: Universal Visual Design & Anti-Slop Skill

> A production-grade visual engineering and art-direction skill. Enforces deliberate brief inference, calibrated styling dials, pure modern Vanilla CSS architecture, strict anti-slop rules, and precision prompt engineering for visual generation.
> Every rule below is **contextual**. First infer the intent, calibrate the dials, then pull only the required reference modules.

---

## 0. BRIEF INFERENCE (Read the Room First)

Before writing any CSS, markup, or prompt, **infer the underlying design requirements**. LLM visual output is often degraded because models leap to generic defaults rather than discerning specific intent.

### 0.A Signals to Identify
1. **Medium & Format:** Web landing page, SaaS application, standalone UI component, printable PDF/HTML document, executive presentation, mobile app screen, or brand identity board.
2. **Vibe & Intent:** Minimalist, editorial, tactical/technical, calm luxury, playful consumer, or dense utilitarian.
3. **Audience & Context:** B2B decision-makers, technical engineers, design-conscious consumers, recruiters, or public-sector users.
4. **Existing Assets & Constraints:** Brand colors, existing typography, accessibility baselines (WCAG AA), or print margins.

### 0.B Declare a One-Line "Design Read"
Before generating code or prompts, output a single declaration line:
> **"Design Read: \<medium> for \<audience>, using a \<vibe> language, calibrated to \<aesthetic archetype>."**

*Example:*  
`Design Read: Executive PDF performance report for stakeholders, using a restrained editorial language, calibrated to Utilitarian Minimalist.`

### 0.C Anti-Default Discipline
Actively avoid AI tropes:
- No automatic purple/blue gradient button glows.
- No centered dark hero over purple mesh canvas.
- No 3 identical feature card columns.
- No generic Inter typography on all designs.
- No em-dashes (`—`) anywhere in UI or display copy.

---

## 1. THE THREE DIALS (Global Configuration)

After declaring the design read, calibrate the 3 core visual dials (1–10):

* **`DESIGN_VARIANCE`** (1 = Rigid Symmetry, 10 = Asymmetric / Expressive)
* **`MOTION_INTENSITY`** (1 = Completely Static, 10 = Fluid Spring Dynamics)
* **`VISUAL_DENSITY`** (1 = Airy Art Gallery, 10 = High-Density Data Cockpit)

### 1.A Baseline & Presets
* **Universal Baseline:** `VARIANCE: 7` | `MOTION: 5` | `DENSITY: 4`

| Context / Deliverable | VARIANCE | MOTION | DENSITY | Primary Reference |
| :--- | :---: | :---: | :---: | :--- |
| **SaaS / Web Product** | 6–7 | 5–6 | 4–5 | [web-ui.md](./references/web-ui.md) |
| **Reports & Documents (HTML/PDF)** | 3–4 | 1 | 6–7 | [general-styling.md](./references/general-styling.md) |
| **Presentation Slides** | 7–8 | 2–3 | 3–4 | [general-styling.md](./references/general-styling.md) |
| **Visual Comps (`generate_image`)** | 8–9 | 1 | 3–4 | [imagegen.md](./references/imagegen.md) |
| **Mobile App Flows** | 5–6 | 6–7 | 4–5 | [imagegen.md](./references/imagegen.md) |
| **Project UI Modernization** | Match existing | +1 | Match existing | [redesign-audit.md](./references/redesign-audit.md) |

---

## 2. UNIVERSAL DESIGN LAWS & HARD ANTI-SLOP BANS

These rules are non-negotiable across all code, markup, and generated layouts:

### 2.1 The Em-Dash Ban
- **Zero em-dashes (`—`)** anywhere in UI titles, button labels, subtitles, eyebrows, or descriptions. Use standard hyphens (`-`), colons, or restructure the sentence.

### 2.2 Color Discipline & Accent Locking
- **Single Locked Accent:** Exactly one accent color per interface. An accent chosen in section 1 remains the accent across all buttons, status indicators, and highlights.
- **No Emissive AI Gradients:** Banned: purple-to-blue neon glowing borders, radial purple gradient background blobs. Use neutral canvas bases (zinc, graphite, off-white, paper) with clean high-contrast single accents.
- **Pure Black Ban:** Do not use `#000000` as the canvas background. Use tinted darks (`#090a0b`, `#111215`, `#16171a`).

### 2.3 Typography & Readability
- **Hierarchy by Weight & Tracking:** Display headers use negative tracking (`letter-spacing: -0.03em`) and tight line-height (`1.05` to `1.15`). Body copy max width is `65ch` with comfortable line-height (`1.5` to `1.65`).
- **Italic Descender Clearance:** When display type uses italic containing descender letters (`y, g, j, p, q`), never use `line-height: 1`. Enforce `line-height: 1.15` minimum and reserve `padding-bottom: 0.25rem` to prevent clipped descenders.
- **Monospace for Data:** All tabular numbers, metrics, timestamps, and coordinates MUST use monospace typography or `font-variant-numeric: tabular-nums`.

### 2.4 Button & Contrast Architecture (WCAG AA)
- **Contrast Parity:** Every button label and input text MUST pass WCAG AA contrast (minimum 4.5:1 for body, 3:1 for large display elements).
- **No Unbacked Ghost Buttons:** Ghost buttons over images or multi-tonal backgrounds MUST have a semi-opaque backdrop (`backdrop-filter: blur(12px)`) and a visible hairline border (`1px solid rgba(255,255,255,0.15)`).
- **Desktop Button Wrap Ban:** Primary CTAs must never wrap to multiple lines at desktop viewport sizes. Keep labels concise (1–3 words).

### 2.5 Spatial Rhythm & Viewport Discipline
- **Hero Viewport Stability:** Web hero sections MUST use `min-height: 100dvh` (never `height: 100vh`) to prevent mobile viewport layout jumps.
- **Desktop Navigation:** Height capped at 64px–80px max. Must render cleanly on a single line on desktop (`>= 1024px`).
- **Consistent Radius Scale:** Maintain a single border-radius system per view. Do not combine sharp-cornered cards with fully pill-rounded buttons without deliberate nesting rules.

---

## 3. SPECIALIZED REFERENCE MODULES

Pull into context only what your active task requires:

1. 🌐 **[web-ui.md](./references/web-ui.md)**  
   *Pure Vanilla CSS Tokens (`:root`), Grid/Flex layouts, double-bezel cards, island buttons, fluid navigation, and responsive patterns.*
2. 📄 **[general-styling.md](./references/general-styling.md)**  
   *Universal styling: PDF/HTML reports, presentation slides, data tables, email layouts, dashboard widgets, and `@media print`.*
3. 🎨 **[imagegen.md](./references/imagegen.md)**  
   *Visual art direction for Antigravity's native `generate_image` tool (16:9 Web sections, 9:16 Mobile apps, 1:1 Brand kits, prompt blueprints).*
4. 🔄 **[image-to-code.md](./references/image-to-code.md)**  
   *The multi-modal pipeline: Generate visual reference -> Deconstruct aesthetics -> Write pure Vanilla CSS code.*
5. 🛠️ **[redesign-audit.md](./references/redesign-audit.md)**  
   *Surgical 3-step audit (Scan -> Diagnose -> Modern CSS Uplift) for improving legacy or unstyled code without breaking functionality.*
6. ✨ **[styles-presets.md](./references/styles-presets.md)**  
   *Complete Pure CSS aesthetic archetypes: Ethereal Soft/High-End, Utilitarian Minimalist, and Industrial Brutalist.*

---

## 4. FINAL PRE-FLIGHT CHECKLIST

Before shipping any styling, markup, or image prompt, audit against this checklist:

- [ ] **Brief Declared:** Design read declared before generating.
- [ ] **Pure Vanilla CSS:** Standard CSS Custom Properties (`var(--...)`) used.
- [ ] **Zero Em-Dashes:** No `—` present in any titles, descriptions, or CTAs.
- [ ] **Color Locked:** Exactly 1 accent color used consistently throughout.
- [ ] **Contrast Verified:** All text meets WCAG AA contrast against its immediate background.
- [ ] **No Default AI Glow:** No generic purple/blue emissive button glows or gradient meshes.
- [ ] **Layout Scaled:** Desktop navigation is single line; hero fits initial viewport with `min-height: 100dvh`.
- [ ] **Tabular Numerals:** Monospace or `tabular-nums` applied to data and metrics.
