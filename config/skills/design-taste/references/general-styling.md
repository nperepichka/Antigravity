# Universal Styling Engine: Documents, Reports, Slides & Data

This guide extends the `design-taste` visual discipline beyond web landing pages to **any design and styling task**: printable documents, PDF/HTML executive reports, presentation slides, data tables, admin dashboard widgets, and emails.

---

## 1. Printable Documents, Invoices & PDF Reports

When authoring documents, invoices, or whitepapers that may be exported to PDF or printed:

### 1.1 Page Architecture & `@media print`
```css
@page {
  size: A4 portrait;
  margin: 20mm 15mm 20mm 15mm;
}

@media print {
  body {
    background: #ffffff !important;
    color: #111827 !important;
    font-size: 10pt;
    line-height: 1.5;
  }

  .no-print {
    display: none !important;
  }

  .page-break {
    page-break-before: always;
    break-before: page;
  }

  .avoid-break {
    page-break-inside: avoid;
    break-inside: avoid;
  }
}
```

### 1.2 Document Typography & Hierarchy
- **Header:** Clean typographic letterhead with metadata (Document ID, Date, Author) aligned right.
- **Section Dividers:** Ultra-fine `1px solid #e5e7eb` rules. Avoid heavy dark banners.
- **Summary Metrics Strip:** 3 or 4 metric boxes with light gray background (`#f8fafc`), small uppercase label (`9pt`, `letter-spacing: 0.05em`), and bold value (`18pt`, monospace or tabular-nums).

---

## 2. High-Impact Presentation Slides (16:9)

When styling slide decks, pitch decks, or HTML-based presentations:

### 2.1 Slide Canvas Specs
```css
.slide-canvas {
  width: 100vw;
  height: 56.25vw; /* 16:9 Aspect Ratio */
  max-height: 100vh;
  max-width: 177.78vh;
  aspect-ratio: 16 / 9;
  background: #090a0d;
  color: #f8fafc;
  padding: clamp(2.5rem, 5vw, 5rem);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  box-sizing: border-box;
  overflow: hidden;
}
```

### 2.2 Slide Content Rules
- **One Core Concept Per Slide:** Avoid jamming 5 bullet points and 3 diagrams together.
- **Hero Statement Size:** Large statement typography (`clamp(2rem, 4vw, 3.75rem)`), maximum 2 lines.
- **Accent Highlighting:** Use the single locked accent color on exactly one keyword in the slide statement.
- **Bottom Telemetry Bar:** Slide category, page number (`04 / 12`), and subtle brand tag placed along the bottom margin.

---

## 3. High-Density Data Tables

For technical dashboards, audit logs, and financial tables:

```css
.data-table-container {
  width: 100%;
  overflow-x: auto;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  background: #111317;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
  font-family: var(--font-body);
  font-size: 0.875rem;
}

.data-table th {
  padding: 0.875rem 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  color: #94a3b8;
  font-weight: 500;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.data-table td {
  padding: 1rem 1.25rem;
  color: #f1f5f9;
  border-bottom: 1px solid rgba(255, 255, 255, 0.04);
}

.data-table tr:hover td {
  background: rgba(255, 255, 255, 0.02);
}

/* Numeric Columns: Absolute alignment and tabular numerals */
.data-table td.numeric,
.data-table th.numeric {
  text-align: right;
  font-family: var(--font-mono);
  font-variant-numeric: tabular-nums;
}
```

---

## 4. Status Badges & Telemetry Pills

Replace generic primary-colored tags with restrained, tinted pill indicators:

```css
.badge-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.25rem 0.625rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
  letter-spacing: 0.025em;
  border: 1px solid transparent;
}

/* Success / Active Status */
.badge-active {
  background: rgba(16, 185, 129, 0.1);
  color: #34d399;
  border-color: rgba(16, 185, 129, 0.2);
}

.badge-active::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
}

/* Neutral / Staging Status */
.badge-neutral {
  background: rgba(148, 163, 184, 0.1);
  color: #cbd5e1;
  border-color: rgba(148, 163, 184, 0.2);
}

.badge-neutral::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #94a3b8;
}
```

---

## 5. Responsive Email Layouts

For transactional emails and updates:
- **Max Width:** Hard constraint at `600px` centered.
- **Base Typography:** System sans-serif font stack (`-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`).
- **Single CTA Button:** Minimum 44px height, high-contrast solid background, centered or left-aligned.
- **Footer:** Clean unsubscribe and physical address metadata with 12px muted text (`#64748b`).
