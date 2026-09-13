# Multi-Modal Image-to-Code Design Pipeline

This guide specifies the sequential, multi-modal workflow for turning visual concepts into production-grade Pure Vanilla CSS code.

---

## The 3-Step Pipeline Overview

```
┌────────────────────────────────────────────────────────┐
│ Step 1: Visual Generation                              │
│ Call native generate_image using imagegen.md recipes   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Step 2: Visual Deconstruction                          │
│ Inspect artifact image -> Extract tokens & layout grid │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Step 3: Production Implementation                      │
│ Code HTML & Pure Vanilla CSS matching extracted tokens │
└────────────────────────────────────────────────────────┘
```

---

## Step 1: Visual Generation

1. When a task requires designing a new visual experience from scratch, **generate a reference comp first** using `generate_image`.
2. Select the correct aspect ratio:
   - Web hero or section: `AspectRatio: "16:9"`
   - Mobile application screen: `AspectRatio: "9:16"`
   - Brand identity / logo board: `AspectRatio: "1:1"`
3. Formulate the prompt using the recipes in [imagegen.md](./imagegen.md).
4. Note the saved artifact file path.

---

## Step 2: Visual Deconstruction & Audit

Before writing a single line of CSS or HTML, inspect the generated image and document the extracted tokens:

### 2.1 Extraction Checklist
- **Canvas Substrate:** Exact background tone (e.g. `#0e1013`, `#121316`, `#fbfbf9`).
- **Surface Elevation:** Card and panel tones (e.g. `#16191f`, `#1d2028`).
- **Single Accent Color:** Exact accent hue and hex code (e.g. Cobalt `#2563eb`, Emerald `#10b981`, Orange `#f97316`).
- **Typography DNA:**
  - Headline style (Geometric sans, Compressed neo-grotesk, or Modern serif).
  - Letter spacing (Tight `-0.03em` or Wide `0.05em`).
  - Text color hierarchy (Primary off-white `#f8fafc`, Secondary muted `#94a3b8`).
- **Component Geometry:**
  - Corner radii (Sharp `4px`, Medium `12px`, or Large `24px`).
  - Framing style (Hairline border `1px solid rgba(255,255,255,0.08)`, frosted glass backdrop, or nested double-bezel).
- **Spatial Grid:**
  - Layout structure (Asymmetric 60/40 split, 12-column bento grid, or centered low).

---

## Step 3: Production Implementation (Pure Vanilla CSS)

Translate the extracted properties directly into standard CSS custom properties and semantic markup:

### 3.1 Mapping Extracted Tokens to `:root`
```css
:root {
  /* Extracted from generated image artifact */
  --color-canvas: #0e1013;
  --color-surface: #16191f;
  --color-accent: #2563eb;
  --color-accent-hover: #1d4ed8;
  
  --font-display: 'Cabinet Grotesk', -apple-system, sans-serif;
  --font-body: 'Geist', -apple-system, sans-serif;
  
  --radius-card: 1.25rem;
  --radius-btn: 9999px;
  
  --border-subtle: 1px solid rgba(255, 255, 255, 0.08);
}
```

### 3.2 Faithful Semantic Markup
- Write clean HTML5 semantic tags (`<header>`, `<main>`, `<section>`, `<nav>`, `<article>`).
- Implement the exact layout grid identified in Step 2.
- Integrate the generated reference image as an asset demonstration (using local artifact paths).
- Seal with the Pre-Flight Checklist in `SKILL.md`.
