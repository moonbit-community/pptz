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
Font size, font family, color, bold, italic, underline, strikethrough, caps,
baseline, bullets, and numbering belong here as the schema grows.

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

The first effect slice supports shadow only. Do not expose the full
`moon-pptx` `EffectList` surface in the first v2 slice.

## Image Element

The first `0.2.0` capability release implements the image slice.

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

Tables have a canonical PowerPoint table form and an optional shorthand.

Canonical form:

```toml
[[elements]]
id = "summary"
type = "table"
bounds = [80, 120, 720, 300]

[elements.content]
col_widths = [240, 240, 240]
row_heights = [48, 48]

[[elements.content.rows]]
cells = [
  { text = "Metric", fill = "$surface" },
  { text = "Q1" },
  { text = "Q2" },
]
```

The canonical model covers rows, cells, merge spans, fills, borders, margins,
and anchors.

Shorthand form:

```toml
[elements.content]
data = [
  ["Metric", "Q1", "Q2"],
  ["Revenue", "100", "150"],
]
```

The loader normalizes shorthand into the canonical rows/cells model. Omitted
column widths and row heights are evenly distributed inside the table bounds.
Explicit `col_widths` and `row_heights` may override equal distribution.
Weight-based sizing is outside the v2 shorthand scope.

## Chart Element

The first chart slice covers these chart families:

- `bar`
- `line`
- `pie`
- `doughnut`
- `area`
- `scatter`
- `bubble`
- `radar`

Chart data is inline in page TOML for the first slice.

```toml
[[elements]]
id = "revenue_chart"
type = "chart"
bounds = [80, 120, 720, 360]

[elements.content]
kind = "bar"
categories = ["Q1", "Q2", "Q3", "Q4"]

[[elements.content.series]]
name = "Revenue"
values = [100.0, 200.0, 300.0, 250.0]
```

3D charts, stock charts, surface charts, of-pie charts, chartEx families, and
external CSV/TOML/spreadsheet-backed data are outside the first chart slice.

## 0.2.0 Release Boundary

`0.2.0` ships only after:

- this v2 schema architecture is documented;
- the image slice compiles end-to-end from TOML to PPTX;
- `stretch`, `cover`, `contain`, explicit crop, and SVG pictures are covered by
  the maintained example deck and tests;
- writer capability errors are removed for implemented image slice features.

Shape, connector, table, and chart designs may remain design-only in `0.2.0`.
