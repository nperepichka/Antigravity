# Web UI Architecture & Pure Vanilla CSS Token Engine

This guide provides the complete Pure Modern Vanilla CSS foundation for web interfaces, landing pages, and interactive components. It strictly enforces standard CSS custom properties, native CSS Grid, Flexbox, and zero third-party CSS dependencies.

---

## 1. Universal Design Tokens (`:root`)

Place this token foundation at the top of your main stylesheet (`style.css` or `index.css`):

```css
:root {
  /* =========================================
     1. TYPOGRAPHY SYSTEM
     ========================================= */
  --font-display: 'Cabinet Grotesk', 'Outfit', 'Geist', -apple-system, sans-serif;
  --font-body: 'Geist', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', monospace;

  /* Fluid Display Scales */
  --text-hero: clamp(2.5rem, 6vw, 4.75rem);
  --text-h1: clamp(2rem, 4vw, 3.25rem);
  --text-h2: clamp(1.5rem, 3vw, 2.25rem);
  --text-h3: clamp(1.15rem, 2vw, 1.5rem);
  --text-body: clamp(0.95rem, 1vw, 1.05rem);
  --text-sm: 0.875rem;
  --text-xs: 0.75rem;

  --leading-tight: 1.05;
  --leading-snug: 1.25;
  --leading-relaxed: 1.6;

  --tracking-tight: -0.035em;
  --tracking-normal: 0em;
  --tracking-wide: 0.08em;

  /* =========================================
     2. CHROMATIC PALETTE (Tinted Dark Canvas)
     ========================================= */
  --color-canvas: #090a0c;
  --color-surface-base: #111317;
  --color-surface-elevated: #181b22;
  --color-surface-overlay: #21252f;

  /* Hairline Borders & Dividers */
  --border-hairline: 1px solid rgba(255, 255, 255, 0.08);
  --border-highlight: 1px solid rgba(255, 255, 255, 0.16);

  /* Contrast-Calibrated Typography Colors */
  --color-text-primary: #f8fafc;
  --color-text-secondary: #94a3b8;
  --color-text-muted: #64748b;

  /* Single Locked Accent (Contrast > 5:1 against surface) */
  --color-accent: #2563eb;
  --color-accent-hover: #1d4ed8;
  --color-accent-subtle: rgba(37, 99, 235, 0.12);

  /* =========================================
     3. HARDWARE RADII (Concentric Geometry)
     ========================================= */
  --radius-outer: 1.5rem;   /* 24px container shell */
  --radius-inner: 1.125rem; /* 18px concentric content */
  --radius-sm: 0.5rem;      /* 8px elements */
  --radius-pill: 9999px;    /* Full interactive pills */

  /* =========================================
     4. PHYSICAL MOTION & SPRINGS
     ========================================= */
  --ease-spring: cubic-bezier(0.32, 0.72, 0, 1);
  --duration-fast: 160ms;
  --duration-base: 240ms;
  --duration-slow: 400ms;

  /* Elevation Shadows (Tinted, Never Pure Black) */
  --shadow-subtle: 0 4px 20px -2px rgba(0, 0, 0, 0.5);
  --shadow-elevated: 0 12px 36px -4px rgba(0, 0, 0, 0.65);
}
```

---

## 2. Core Layout Architecture

### 2.1 Viewport Container & Section Spacing
```css
.container {
  width: 100%;
  max-width: 1320px;
  margin-inline: auto;
  padding-inline: 1.5rem;
}

.section-spacing {
  padding-block: clamp(4.5rem, 10vw, 8.5rem);
}
```

### 2.2 Hero Viewport Discipline
The hero section must command attention without spilling over on standard viewports:

```css
.hero-section {
  min-height: 100dvh; /* Never use h-screen */
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding-top: clamp(4rem, 8vw, 6rem);
  padding-bottom: 3rem;
  position: relative;
  overflow: hidden;
}

.hero-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 3rem;
  align-items: center;
}

@media (min-width: 1024px) {
  .hero-grid {
    grid-template-columns: 1.15fr 0.85fr; /* Asymmetric balance */
  }
}

.hero-title {
  font-family: var(--font-display);
  font-size: var(--text-hero);
  line-height: var(--leading-tight);
  letter-spacing: var(--tracking-tight);
  color: var(--color-text-primary);
  max-width: 16ch;
}

.hero-subtext {
  font-family: var(--font-body);
  font-size: var(--text-body);
  line-height: var(--leading-relaxed);
  color: var(--color-text-secondary);
  max-width: 52ch;
  margin-block: 1.5rem 2rem;
}
```

---

## 3. High-End Component Patterns

### 3.1 The Double-Bezel Card (Hardware Look)
Never render cards as flat boxes with 1px gray borders. Implement concentric nesting:

```css
/* Outer Shell */
.card-shell {
  background: var(--color-surface-base);
  border: var(--border-hairline);
  border-radius: var(--radius-outer);
  padding: 0.5rem; /* Concentric gutter */
  box-shadow: var(--shadow-subtle);
  transition: transform var(--duration-base) var(--ease-spring),
              border-color var(--duration-base) ease;
}

.card-shell:hover {
  border-color: rgba(255, 255, 255, 0.18);
  transform: translateY(-2px);
}

/* Inner Core */
.card-core {
  background: var(--color-surface-elevated);
  border: var(--border-hairline);
  border-radius: var(--radius-inner);
  padding: 2rem;
  height: 100%;
  display: flex;
  flex-direction: column;
}
```

### 3.2 Island Buttons (Button-in-Button Architecture)
Interactive primary buttons simulate physical hardware with generous padding and isolated trailing icons:

```css
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 1rem;
  padding: 0.625rem 0.75rem 0.625rem 1.5rem;
  background: var(--color-accent);
  color: #ffffff;
  font-family: var(--font-body);
  font-size: var(--text-sm);
  font-weight: 500;
  border-radius: var(--radius-pill);
  border: none;
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;
  box-shadow: 0 2px 10px rgba(37, 99, 235, 0.3);
  transition: background var(--duration-fast) ease,
              transform var(--duration-fast) var(--ease-spring);
}

.btn-primary:hover {
  background: var(--color-accent-hover);
}

.btn-primary:active {
  transform: scale(0.98);
}

/* Trailing icon circular pill */
.btn-primary .btn-icon {
  width: 2rem;
  height: 2rem;
  border-radius: var(--radius-pill);
  background: rgba(255, 255, 255, 0.18);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.875rem;
}
```

### 3.3 Asymmetric Bento Grid
Use native CSS Grid to construct expressive, rhythmic layouts without empty placeholders:

```css
.bento-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

@media (min-width: 768px) {
  .bento-grid {
    grid-template-columns: repeat(12, 1fr);
  }
  
  .bento-col-8 {
    grid-column: span 8;
  }
  
  .bento-col-4 {
    grid-column: span 4;
  }
  
  .bento-col-6 {
    grid-column: span 6;
  }
  
  .bento-col-12 {
    grid-column: span 12;
  }
}
```

### 3.4 Floating Navigation Bar
```css
.navbar-floating {
  position: fixed;
  top: 1.5rem;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 3rem);
  max-width: 1100px;
  height: 64px;
  background: rgba(17, 19, 23, 0.75);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: var(--border-hairline);
  border-radius: var(--radius-pill);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-inline: 1.75rem;
  z-index: 100;
  box-shadow: var(--shadow-subtle);
}
```
