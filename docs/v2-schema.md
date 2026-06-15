# pptz v2 Schema Architecture

`pptz v2` expands the TOML-to-PPTX capability surface while keeping a thin
semantic layer over `moon-pptx`. The schema should stay close to what
`moon-pptx` can generate, but it must remain validated `pptz` TOML rather than
raw OpenXML or serialized MoonBit backend types.

This document is the v2 design milestone. A published `pptz` release is still
bounded by capabilities that compile from TOML to PPTX.

## Principles

- Use snake_case for every user-facing key and enum value.
- Reject unknown fields before 1.0.
- Do not introduce schema-version negotiation for v2.
- Do not expose raw OpenXML, arbitrary XML extension, or backend-passthrough
  fields.
- Design shared presentation primitives once, then reuse them across element
  families.
- Implement release-facing features by capability slice so each exposed feature
  compiles end-to-end.

## Shared Primitives

`bounds` remains the shared positioning primitive:

```toml
bounds = [x, y, width, height]
```

All values are `Double` slide coordinates in the deck's coordinate system.

### Fill

The v2 fill model should be shared by shapes, table cells, and future element
families:

- `solid`
- `gradient`
- `none`

Opacity belongs to the color/fill model and should not be treated as an effect.

### Basic Stroke

Shape borders, connector lines, and table cell borders share a basic stroke
primitive:

- `color`
- `width`
- `dash`

Connector arrowheads are connector-specific fields, not part of the shared
stroke model.

### Text Run Properties

Text styling should extend the current text style model toward the
`moon-pptx` run properties surface while staying in `pptz` terminology.
The current writer supports font size, font family, color, bold, italic,
line height, paragraph spacing, bullets, external hyperlinks, body insets, and
autofit controls. Underline, strikethrough, caps, baseline, and internal slide
hyperlinks remain future schema extensions.

Plain text remains valid:

```toml
[elements.content]
style = "$body"
text = "Hello"
```

Rich text uses explicit paragraphs and runs. Do not mix `text` and
`paragraphs` in the same text element.

```toml
[elements.content]
style = "$body"
align = ["left", "top"]
wrap = true

[elements.content.body]
auto_fit = "shape"

[elements.content.body.inset]
left = 8
right = 8
top = 4
bottom = 4

[[elements.content.paragraphs]]
text = "Agenda item"
space_after = 6
margin_left = 18
indent = -9

[elements.content.paragraphs.bullet]
kind = "char"
char = "-"

[[elements.content.paragraphs]]

[[elements.content.paragraphs.runs]]
text = "Read "

[[elements.content.paragraphs.runs]]
text = "docs"
style = "$link"
hyperlink = "https://example.com"
tooltip = "Documentation"
```

### Crop Rectangle

Image crop uses normalized edge insets:

```toml
[elements.content.crop]
left = 0.1
top = 0.0
right = 0.1
bottom = 0.0
```

Each value is a `Double` in `0.0..1.0` and means "crop this fraction from that
source edge". Crop values are not pixel rectangles.

### Effects

The current writer supports outer shadows on shape and connector elements. Do
not expose the full `moon-pptx` `EffectList` surface in the first v2 slice.

## Image Element

The first `0.2.0` capability release implemented the image slice.

```toml
[[elements]]
id = "hero"
type = "image"
bounds = [80, 120, 520, 320]

[elements.content]
path = "images/hero.png"
fit = "cover"

[elements.content.crop]
left = 0.05
top = 0.0
right = 0.05
bottom = 0.0
```

Supported `fit` values:

- `stretch`: map the source to element bounds exactly.
- `cover`: preserve source aspect ratio and fill the bounds, cropping overflow.
- `contain`: preserve source aspect ratio and fit inside bounds.

`cover` and `contain` use intrinsic image size. For explicit crop plus
`cover` or `contain`, `pptz` first crops the source region and then fits that
cropped region into the element bounds.

SVG images are allowed directly:

```toml
[elements.content]
path = "images/logo.svg"
fit = "contain"
```

The schema does not accept a user-provided raster fallback for SVG.

## Icon Element

The current writer supports a small built-in icon set by mapping icon names to
PowerPoint preset shapes. Supported names are `cube`, `circle`, `square`,
`star`, `heart`, and `plus`; names may also use a prefix such as `fas:cube`.

```toml
[[elements]]
id = "cube_icon"
type = "icon"
bounds = [80, 80, 80, 80]

[elements.content]
name = "fas:cube"

[elements.content.fill]
type = "solid"
color = "$accent"
```

Unknown icon names are writer capability errors.

## Shape Element

Shape subtypes expand toward the `moon-pptx` preset-shape surface. User-facing
shape names use `pptz` snake_case names, not OpenXML camelCase names. `pptz`
maintains one mapping from snake_case names to `moon-pptx` preset shape values.

```toml
[[elements]]
id = "badge"
type = "shape"
bounds = [80, 80, 220, 80]

[elements.content]
shape = "round_rect"

[elements.content.fill]
type = "solid"
color = "$accent"

[elements.content.stroke]
color = "$ink"
width = 2.0
dash = "solid"
```

Lines and connectors are not shape subtypes.

## Connector Element

Connectors are a separate element family. The first connector slice supports
coordinate endpoints and element endpoints.

```toml
[[elements]]
id = "flow"
type = "connector"

[elements.content]
kind = "straight"
start = [220, 180]
end = { element = "target" }
end_arrow = "triangle"

[elements.content.stroke]
color = "$accent"
width = 2.0
dash = "solid"
```

Element endpoints refer to another element by id. The first connector schema
does not expose raw PowerPoint connection site indices; `pptz` chooses the
backend connection site.

## Table Element

Tables have a canonical PowerPoint table form and an optional shorthand. The
current writer renders rectangular tables, including cells that declare
`col_span` or `row_span`.

Canonical form:

```toml
[[elements]]
id = "summary"
type = "table"
bounds = [80, 120, 720, 300]

[elements.content]
style = "$compact"
col_widths = [240, 240, 240]
row_heights = [48, 48]

[[elements.content.rows]]
cells = [
  {
    text = "Metric",
    col_span = 3,
    fill = { type = "solid", color = "$surface" },
  },
]
```

The canonical model covers rows, cells, merge spans, fills, borders, margins,
anchors, and a table-level theme style token. A table style may define
`font_size`, `font_family`, `header_fill`, `header_color`, `body_color`, and
`border`; explicit cell fill or border values override the table style.

Shorthand form:

```toml
[elements.content]
data = [
  ["Metric", "Q1", "Q2"],
  ["Revenue", "100", "150"],
]
```

The parser normalizes shorthand into the canonical rows/cells model. Omitted
column widths and row heights are evenly distributed inside the table bounds by
the writer.
Explicit `col_widths` and `row_heights` may override equal distribution.
Weight-based sizing is outside the v2 shorthand scope.

## Chart Element

The current writer renders the first chart schema.

The current chart slice covers these chart families:

- `bar`
- `line`
- `pie`
- `doughnut`
- `area`
- `scatter`
- `bubble`
- `radar`

Chart data is inline in page TOML for the first slice. Category charts may use
either explicit `categories` plus `series` tables or the compact `data`
matrix shorthand.

```toml
[[elements]]
id = "revenue_chart"
type = "chart"
bounds = [80, 120, 720, 360]

[elements.content]
kind = "bar"
title = "Quarterly revenue"
legend = "bottom"
style = 4
data_labels = "outside_end"
rounded_corners = false
categories = ["Q1", "Q2", "Q3", "Q4"]

[[elements.content.series]]
name = "Revenue"
values = [100.0, 200.0, 300.0, 250.0]
```

Equivalent category chart shorthand:

```toml
[elements.content]
kind = "bar"
data = [
  ["", "Q1", "Q2", "Q3", "Q4"],
  ["Revenue", 100.0, 200.0, 300.0, 250.0],
]
```

Supported `legend` values are `hidden`, `bottom`, `top_right`, `left`,
`right`, and `top`. Supported `data_labels` values are `hidden`, `best_fit`,
`bottom`, `center`, `inside_base`, `inside_end`, `left`, `outside_end`,
`right`, and `top`.

Scatter series use `x_values` plus `values` for Y values. Bubble series add
`bubble_sizes`.

3D charts, stock charts, surface charts, of-pie charts, chartEx families, and
external CSV/TOML/spreadsheet-backed data are outside the current chart slice.
Scatter and bubble charts still use explicit series with `x_values` and cannot
use the category `data` shorthand.

## 0.3.0 Release Boundary

`0.3.0` promotes authoring ergonomics for real content decks:

- rich text paragraphs, styled runs, bullets, external hyperlinks, body insets,
  and autofit controls;
- table-level theme styles for header/body text, header fill, and borders;
- category chart `data` shorthand normalized into the existing chart AST.

## 0.2.x Release Boundary

`0.2.0` shipped after:

- this v2 schema architecture is documented;
- the image slice compiles end-to-end from TOML to PPTX;
- `stretch`, `cover`, `contain`, explicit crop, and SVG pictures are covered by
  the maintained example deck and tests;
- writer capability errors are removed for implemented image slice features.

Later 0.2.x releases promote documented shape, connector, table, and chart
schema from design-only concepts into implemented writer slices. The current
writer state is documented in `README.md` and `REFERENCE.md`.
