---
name: pptz
description: Create editable PowerPoint PPTX decks from pptz YAML sources with Milky2018/pptz. Use when Codex needs to design a new slide deck, write deck/page sources, compile them to .pptx, and deliver both sources and output. Do not use for editing an existing PPTX or for PowerPoint features outside the pptz schema.
---

# pptz

## Quick Reference

| Task | Read |
| --- | --- |
| Full schema, diagnostics, CLI contract | [REFERENCE.md](REFERENCE.md) |
| Known-good compiling source deck | [examples/minimal](examples/minimal) |
| Technical/API/architecture deck | [references/technical-deck.md](references/technical-deck.md) |
| Metrics/reporting deck | [references/data-report.md](references/data-report.md) |
| Product launch/demo deck | [references/product-demo.md](references/product-demo.md) |
| Course/tutorial/workshop deck | [references/course-lecture.md](references/course-lecture.md) |

## Contract

Produce a source directory and a generated PPTX. The source directory is part of
the deliverable.

```text
deck-topic/
|-- deck.pptz.yaml
|-- pages/
|   |-- cover.page.yaml
|   `-- agenda.page.yaml
|-- images/
`-- dist/
    `-- deck.pptx
```

## Workflow

1. Create `deck.pptz.yaml` with deck size, theme colors, text/table styles, and
   ordered page paths.
2. Create `pages/*.page.yaml` with explicit `bounds` and theme tokens.
3. Put local assets under the deck directory and reference them with relative
   paths.
4. Compile from the deck directory:

   ```bash
   moon runwasm Milky2018/pptz@0.4.1 deck.pptz.yaml --out dist/deck.pptx
   ```

   When working inside this repository, use the local package instead:

   ```bash
   moon runwasm . examples/minimal/deck.pptz.yaml --out examples/minimal/dist/deck.pptx
   ```

5. Deliver the source directory and generated `.pptx`.

## Boundaries

- Use paths relative to the deck directory. Published wasm runs with sandboxed
  file access.
- Stay inside the documented pptz schema. Unknown fields are rejected before
  1.0, and raw OpenXML passthrough is intentionally unsupported.
- Treat writer capability errors as schema boundaries, not TODOs to work around
  with backend internals.
- Do not rely on `letter_spacing`, line/connector shape presets, unsupported
  icon names, unsupported connector kinds, or unsupported shape names.
- `font_family` must be one PowerPoint typeface name, not a CSS fallback list.
  Use `"Aptos"` or one concrete CJK font such as `"PingFang SC"`; do not write
  `"Aptos, Arial"` or `"MiSans, PingFang SC, Microsoft YaHei"`.

## Patterns

### Style Inheritance

Use `extends` to keep theme styles compact. A style can extend another style of
the same kind; local fields override inherited fields.

```yaml
theme:
  text_styles:
    body:
      font_size: 22
      font_family: "Aptos"
      color: "$text"
    caption:
      extends: "$body"
      font_size: 12
      color: "$muted"
  table_styles:
    base:
      font_size: 14
      font_family: "Aptos"
      border: { style: "solid", width: 1, color: "$line" }
    compact:
      extends: "$base"
      header_fill: "$surface_alt"
      header_text_color: "$text"
      body_text_color: "$text"
```

### Layout Templates

Use deck-level layouts for repeated slide chrome such as eyebrow, heading,
footer, and accent marks. Pages fill named text slots and keep their own content
elements focused.

```yaml
layouts:
  content:
    slots:
      eyebrow:
        bounds: [72, 38, 500, 24]
        style: "$caption"
      heading:
        bounds: [72, 72, 900, 72]
        style: "$title"
    elements:
      - id: "accent"
        type: "shape"
        bounds: [48, 40, 6, 96]
        content:
          shape: "rect"
          fill: { type: "solid", color: "$primary" }
```

```yaml
layout: "$content"
slots:
  eyebrow: "Risk model"
  heading: "风险分析"
```

### Components

Use components for repeated local element groups such as stat cards. Component
coordinates are local to the component bounds; instances place and scale the
group. Props replace whole-string `$name` text values.

```yaml
components:
  stat_card:
    bounds: [0, 0, 180, 90]
    elements:
      - id: "label"
        type: "text"
        bounds: [16, 14, 148, 24]
        content:
          style: "$caption"
          text: "$label"
```

```yaml
components:
  - id: "npm_card"
    use: "$stat_card"
    bounds: [72, 160, 180, 90]
    props:
      label: "npm packages"
```

### Diagram Safety

- Do not use spaces to align text across multiple visual objects. Use separate
  text boxes, table cells, or component instances.
- Treat colored cards, chips, and diagram nodes as semantic objects: each one
  needs its own label inside the same bounds, or a component that contains both
  the background shape and label.
- For node-to-node connectors, prefer element endpoints:
  `start: { element: "source" }` and `end: { element: "target" }`.
  `pptz` automatically anchors each endpoint to the facing edge. Add `anchor`
  only when a specific edge is needed.
- Do not draw a direct connector through a third node. `pptz` warns when a
  connector crosses a non-endpoint element; reroute the diagram instead.
- Use empty shapes only as decoration or background chrome. If a shape
  represents a step, category, state, metric, or concept, bind visible text to
  that shape.

### Rich Text

Use explicit paragraphs/runs for bullets and hyperlinks. Do not encode rich text
as Markdown inside `text`.
Text boxes shrink text to fit their bounds by default. Set `auto_fit: "none"`
only when exact font metrics matter more than overflow protection; use
`auto_fit: "shape"` only when resizing the text box is acceptable.

```yaml
content:
  style: "$body"
  align: ["left", "top"]
  wrap: true
  body:
    inset: { left: 8, right: 8, top: 4, bottom: 4 }
  paragraphs:
    - text: "Agenda item"
      space_after: 6
      margin_left: 18
      indent: -9
      bullet: { kind: "char", char: "-" }
    - runs:
        - text: "Read "
        - text: "docs"
          style: "$link"
          hyperlink: "https://example.com"
          tooltip: "Documentation"
```

### Table Style

Define table styles in the deck theme and reference them from table content.

```yaml
theme:
  table_styles:
    compact:
      font_size: 14
      font_family: "Aptos"
      header_fill: "$surface_alt"
      header_text_color: "$text"
      body_text_color: "$text"
      border: { style: "solid", width: 1, color: "$muted" }
content:
  style: "$compact"
  data:
    - ["Metric", "Q1", "Q2"]
    - ["Revenue", "100", "150"]
```

### Chart Data

Put repeated chart options in a theme chart style, then fill title and data on
each page.

```yaml
theme:
  chart_styles:
    report_bar:
      kind: "bar"
      legend: "bottom"
      style: 4
      data_labels: "outside_end"
content:
  chart_style: "$report_bar"
  title: "Revenue"
  data:
    - ["", "Q1", "Q2", "Q3"]
    - ["Revenue", 100.0, 150.0, 125.0]
```

Use `data` shorthand for category charts.

```yaml
content:
  kind: "bar"
  title: "Revenue"
  legend: "bottom"
  data:
    - ["", "Q1", "Q2", "Q3"]
    - ["Revenue", 100.0, 150.0, 125.0]
```

Scatter and bubble charts use explicit series with `x_values`; do not use this
category shorthand for them.

### Images

```yaml
content:
  path: "images/hero.png"
  fit: "cover"
  crop:
    left: 0.05
    right: 0.05
    top: 0.0
    bottom: 0.0
```

## Delivery Bar

- The PPTX is generated successfully.
- The YAML sources remain editable and are delivered with the PPTX.
- Assets are local to the deck directory and referenced relatively.
- The deck does not assume unsupported schema features.
- Prefer each slide to have a visual structure: image, chart, table, icon,
  connector, or shape composition.
- Render or preview every deck before delivery; do not leave unreadable table
  text, clipped text, broken wrapping, empty semantic cards, or labels floating
  outside their cards.
