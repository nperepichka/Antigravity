# Curated Pure Vanilla CSS Aesthetic Presets

This guide contains three battle-tested, high-signal aesthetic archetypes implemented in **100% Pure Modern Vanilla CSS**. Choose ONE archetype per project and commit to it consistently.

---

## Archetype 1: Ethereal Soft / High-End Agency

> **Best for:** Premium SaaS, creative studios, AI infrastructure, modern developer tools.  
> **Key Attributes:** Double-bezel hardware cards, island buttons, tinted dark canvas, frosted glass backdrops, subtle hairline highlights, fluid spring motion.

```css
:root {
  --font-display: 'Cabinet Grotesk', -apple-system, sans-serif;
  --font-body: 'Geist', -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  --color-canvas: #07080a;
  --color-surface-base: #0f1115;
  --color-surface-elevated: #15181f;
  
  --color-text-primary: #f8fafc;
  --color-text-secondary: #94a3b8;
  --color-accent: #3b82f6;
  --color-accent-hover: #2563eb;

  --radius-outer: 1.5rem;
  --radius-inner: 1.125rem;
  --radius-pill: 9999px;

  --border-hairline: 1px solid rgba(255, 255, 255, 0.07);
  --border-highlight: 1px solid rgba(255, 255, 255, 0.14);
  --ease-spring: cubic-bezier(0.32, 0.72, 0, 1);
}

/* Double-bezel hardware container */
.soft-card {
  background: var(--color-surface-base);
  border: var(--border-hairline);
  border-radius: var(--radius-outer);
  padding: 0.5rem;
  transition: transform 240ms var(--ease-spring);
}

.soft-card:hover {
  transform: translateY(-2px);
}

.soft-card-inner {
  background: var(--color-surface-elevated);
  border: var(--border-hairline);
  border-radius: var(--radius-inner);
  padding: 2rem;
}
```

---

## Archetype 2: Utilitarian Minimalist

> **Best for:** Knowledge bases, editorial products, productivity tools, document-driven applications (Linear / Notion vibe).  
> **Key Attributes:** High-contrast warm monochrome, sharp borders, zero gradients, ultra-flat bento boxes, muted spot pastel tags, monospace metadata.

```css
:root {
  --font-display: 'Geist', 'SF Pro Display', sans-serif;
  --font-body: 'Geist', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'SF Mono', 'JetBrains Mono', monospace;

  /* Warm Monochrome Canvas */
  --color-canvas: #fbfbf9;
  --color-surface-base: #ffffff;
  --color-surface-elevated: #f4f4f0;
  
  --color-text-primary: #121314;
  --color-text-secondary: #646566;
  --color-border: #e6e6e2;

  --color-accent: #121314;
  --color-accent-hover: #2a2b2c;

  /* Crisp, controlled geometry */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
}

/* Ultra-flat Minimalist Card */
.minimalist-card {
  background: var(--color-surface-base);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 1.75rem;
  box-shadow: none; /* Zero heavy drop shadows */
}

/* Muted Pastel Tag */
.tag-pastel-blue {
  background: #e8f2fc;
  color: #1a568c;
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.2rem 0.5rem;
  border-radius: var(--radius-sm);
  letter-spacing: 0.02em;
}
```

---

## Archetype 3: Industrial Brutalist

> **Best for:** Technical data infrastructure, security consoles, telemetry monitors, bold engineering portfolios.  
> **Key Attributes:** Swiss print light mode or Tactical CRT dark mode. Massive neo-grotesk headlines with compressed line-height (`0.9`), rigid grid dividing lines, monospace telemetry brackets (`[SYS_OK]`), hazard red accents.

```css
:root {
  /* Tactical Telemetry (Dark Mode) */
  --font-display: 'Archivo Black', 'Inter', sans-serif;
  --font-body: 'JetBrains Mono', 'IBM Plex Mono', monospace;
  --font-mono: 'JetBrains Mono', monospace;

  --color-canvas: #0a0b0d;
  --color-surface-base: #111317;
  --color-border: #262930;

  --color-text-primary: #f0f2f5;
  --color-text-secondary: #7e8494;
  --color-accent: #ff3333; /* Tactical Hazard Red */

  --radius-zero: 0px; /* Absolutely no rounded corners */
}

/* Rigid Grid Panel */
.brutalist-panel {
  background: var(--color-surface-base);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-zero);
  padding: 1.5rem;
}

/* Monolithic Structural Headline */
.brutalist-header {
  font-family: var(--font-display);
  font-size: clamp(2.5rem, 8vw, 6rem);
  line-height: 0.9;
  letter-spacing: -0.05em;
  text-transform: uppercase;
  color: var(--color-text-primary);
}

/* ASCII Telemetry Marker */
.telemetry-tag {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  color: var(--color-accent);
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
```
