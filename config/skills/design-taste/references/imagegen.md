# Visual Art Direction for `generate_image`

This guide defines the prompt engineering and art direction formulas for Antigravity's native `generate_image(Prompt, ImageName, AspectRatio, ImagePaths)` tool. It actively eliminates repetitive AI image cliches and forces studio-grade outputs.

---

## 1. Antigravity Tool Parameter Contract

When calling `generate_image`, always map your visual intent to the exact tool parameters:

| Parameter | Required Format | Allowed Values / Conventions |
| :--- | :--- | :--- |
| `Prompt` | String | Structured prompt containing: Subject, Composition, Palette, Lighting, Surface Texture, Anti-Slop negative directives. |
| `ImageName` | String | Lowercase alphanumeric slug with underscores (max 3 words): `saas_hero_comp`, `mobile_auth_flow`, `brand_identity_board`. |
| `AspectRatio` | String | Must be chosen based on medium: **`16:9`** (Web sections), **`9:16`** (Mobile apps), **`1:1`** or **`4:3`** (Brand kits & logos). |
| `ImagePaths` | Array (optional)| Paths to reference images when iterating or editing. |

---

## 2. Hard Anti-Slop Image Directives

Standard image models collapse into predictable, low-value defaults:
- Centered dark hero with purple/blue glowing orb.
- Floating meaningless translucent blobs.
- Random cards packed inside other cards with fake chart scribbles.
- Unreadable micro-typography.
- Pure black `#000` backgrounds or flat muddy grays.

### Mandatory Directives:
1. **Rule of One Section Per Image (Web):** Never attempt to generate an entire 8-section landing page into a single image. Generate **one horizontal `16:9` image per section** (`hero_comp`, `features_bento_comp`, `pricing_comp`).
2. **Defined Lighting & Surface Texture:** Specify physical media: matte graphite, brushed aluminum, unbleached cotton paper, etched glass, subtle film grain, or studio diffused top-lighting.
3. **Typography Legibility:** Prompt for bold, structural sans-serif headings with high contrast against the background.

---

## 3. Domain A: Web Section Art Direction (`AspectRatio: "16:9"`)

### 3.1 Prompt Formula
```
High-fidelity website UI mockup of [SECTION_TYPE] for [INDUSTRY/PRODUCT].
[COMPOSITION_STYLE] on a [BACKGROUND_TONE] canvas.
Left side: Large crisp typography with headline '[HEADLINE_TEXT]' in modern grotesk font, accompanied by subtext and a single pill-shaped CTA button in [ACCENT_COLOR].
Right side: [PRIMARY_VISUAL_ASSET] featuring [PHYSICAL_MATERIALS] with subtle rim lighting and frosted glass accents.
Clean spatial grid, generous whitespace, sharp edge definition, studio product presentation.
Zero generic AI purple glow, zero floating abstract blobs, zero cluttered card spam.
```

### 3.2 Concrete Web Example
```json
{
  "AspectRatio": "16:9",
  "ImageName": "cloud_hero_comp",
  "Prompt": "High-fidelity website hero section mockup for an enterprise telemetry platform. Asymmetric split composition on a deep graphite #0e1013 canvas. Left side features bold white sans-serif headline 'Observability at Kernel Scale' with tight letter spacing, short subtext, and a single electric blue #2563eb pill button with trailing arrow. Right side displays a physical-looking server chassis telemetry card with subtle frosted glass, hairline white borders, and green telemetry status indicators. Clean layout, ample breathing room, professional UI art direction. Zero purple mesh glow, zero floating blobs."
}
```

---

## 4. Domain B: Mobile Screen Art Direction (`AspectRatio: "9:16"`)

### 4.1 Prompt Formula
```
High-end mobile application screen mockup for [APP_TYPE].
Rendered inside a subtle, premium dark titanium smartphone frame with realistic bezel.
Screen content displays [SCREEN_NAME] featuring a clean native [PLATFORM] UI hierarchy.
Top: [HEADER/NAV] with clear typography.
Center: [MAIN_CONTENT] utilizing [CARD_STRUCTURE] on a [SURFACE_COLOR] substrate.
Bottom: Clean floating tab bar with minimalist iconography.
Coherent color palette of [BACKGROUND_COLOR] and [ACCENT_COLOR].
Readable typography, generous tap targets, realistic status bar and home indicator.
Zero gradient spam, zero fake fintech charts, zero cluttered pills.
```

### 4.2 Concrete Mobile Example
```json
{
  "AspectRatio": "9:16",
  "ImageName": "fintech_dashboard_mobile",
  "Prompt": "High-end mobile application dashboard screen for a modern wealth management app. Shown inside a subtle matte black smartphone mockup frame. Top section features user greeting, account balance in clean tabular monospace numerals, and a quick transfer action bar. Main body displays three stacked transaction cards with subtle dark surfaces #16181d, hairline dividers, and clean merchant icons. Bottom navigation features a minimalist 4-icon dock. Palette is charcoal, off-white, and warm tan accent. Clean typography, high contrast, WCAG compliant. Zero neon gradients."
}
```

---

## 5. Domain C: Brand Identity & Style Boards (`AspectRatio: "1:1"` or `"4:3"`)

### 5.1 Prompt Formula
```
Studio-grade brand identity guideline board for [BRAND_NAME], a [INDUSTRY] company.
Presentation layout on a dark charcoal #121316 background divided into structured grid panels:
Panel 1: Minimalist geometric logo mark in [ACCENT_COLOR] with construction grid lines.
Panel 2: Primary typography specimen displaying alphabet in modern sans-serif display type.
Panel 3: Curated 4-color palette chips with hex codes and color roles (Canvas, Surface, Neutral, Accent).
Panel 4: Realistic brand application on tactile stationery or matte black packaging with subtle embossed finish.
Sparse layout, disciplined negative space, museum-quality presentation.
Zero cluttered moodboards, zero messy AI collages.
```

### 5.2 Concrete Brandkit Example
```json
{
  "AspectRatio": "1:1",
  "ImageName": "aerospace_brandkit",
  "Prompt": "Studio-grade brand identity presentation board for an autonomous aerospace robotics firm. Modular 4-panel grid layout on a matte dark slate canvas. Top-left shows a minimalist vector logo mark resembling an orbital trajectory in hazard red and white. Top-right shows typographic hierarchy with heavy Swiss neo-grotesk headlines. Bottom-left displays a calibrated palette strip: off-black, slate gray, aviation red, and paper white. Bottom-right shows the logo precision-etched onto an anodized matte titanium plate. Clean, sparse, high-end design studio presentation."
}
```
