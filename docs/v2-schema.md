# pptz v2 Schema Architecture

`pptz v2` expands the YAML-to-PPTX capability surface while keeping a thin
semantic layer over `moon-pptx`. The schema should stay close to what
`moon-pptx` can generate, but it must remain validated `pptz` source rather than
raw OpenXML or serialized MoonBit backend types.

This document is the v2 design milestone. A published `pptz` release is still
bounded by capabilities that compile from YAML to PPTX.

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

```yaml
bounds: [x, y, width, height]
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
`font_family` names one PowerPoint typeface. It does not accept CSS-style
fallback lists.
Text styles and table styles may use `extends: "$name"` to inherit fields from
another style of the same kind. The loader expands inheritance before writing;
cycles and unresolved parents are validation errors.

Plain text remains valid:

```yaml
content:
  style: "$body"
  text: "Hello"
```

Rich text uses explicit paragraphs and runs. Do not mix `text` and
`paragraphs` in the same text element.
Text must fit its declared text area, after `body.inset` is subtracted from the
element bounds. Loader validation treats obvious overflow as an error by
default. Set `body.overflow: "warn"` to keep generating with a diagnostic, or
`"allow"` only after inspecting the rendered PPTX. `auto_fit` still controls
the PowerPoint text body behavior: set `auto_fit: "none"` to disable shrink
behavior, or `auto_fit: "shape"` when the text box may resize to fit its text.

```yaml
content:
  style: "$body"
  align: ["left", "top"]
  wrap: true
  body:
    inset: { left: 8, right: 8, top: 4, bottom: 4 }
    overflow: "error"
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

### Crop Rectangle

Image crop uses normalized edge insets:

```yaml
content:
  crop:
    left: 0.1
    top: 0.0
    right: 0.1
    bottom: 0.0
```

Each value is a `Double` in `0.0..1.0` and means "crop this fraction from that
source edge". Crop values are not pixel rectangles.

### Effects

The current writer supports outer shadows on shape and connector elements. Do
not expose the full `moon-pptx` `EffectList` surface in the first v2 slice.

## Image Element

The first `0.2.0` capability release implemented the image slice.

```yaml
elements:
  - id: "hero"
    type: "image"
    bounds: [80, 120, 520, 320]
    content:
      path: "images/hero.png"
      fit: "cover"
      crop:
        left: 0.05
        top: 0.0
        right: 0.05
        bottom: 0.0
```

Supported `fit` values:

- `stretch`: map the source to element bounds exactly.
- `cover`: preserve source aspect ratio and fill the bounds, cropping overflow.
- `contain`: preserve source aspect ratio and fit inside bounds.

`cover` and `contain` use intrinsic image size. For explicit crop plus
`cover` or `contain`, `pptz` first crops the source region and then fits that
cropped region into the element bounds.

SVG images are allowed directly:

```yaml
content:
  path: "images/logo.svg"
  fit: "contain"
```

The schema does not accept a user-provided raster fallback for SVG.

## Icon Element

The current writer supports a small built-in icon set by mapping icon names to
PowerPoint preset shapes. Supported names are `cube`, `circle`, `square`,
`star`, `heart`, and `plus`; names may also use a prefix such as `fas:cube`.

```yaml
elements:
  - id: "cube_icon"
    type: "icon"
    bounds: [80, 80, 80, 80]
    content:
      name: "fas:cube"
      fill: { type: "solid", color: "$accent" }
```

Unknown icon names are writer capability errors.

## Shape Element

Shape subtypes expand toward the `moon-pptx` preset-shape surface. User-facing
shape names use `pptz` snake_case names, not OpenXML camelCase names. `pptz`
maintains one mapping from snake_case names to `moon-pptx` preset shape values.

```yaml
elements:
  - id: "badge"
    type: "shape"
    bounds: [80, 80, 220, 80]
    content:
      shape: "round_rect"
      fill: { type: "solid", color: "$accent" }
      stroke: { color: "$ink", width: 2.0, dash: "solid" }
      text:
        style: "$body"
        align: ["center", "center"]
        body:
          inset: { left: 12, right: 12, top: 8, bottom: 8 }
        text: "Badge"
```

Lines and connectors are not shape subtypes.

## Connector Element

Connectors are a separate element family. The connector schema supports
coordinate endpoints and element endpoints. Element endpoints default to
automatic edge anchors: `pptz` chooses the facing edge from the endpoint element
toward the other endpoint, so ordinary node-to-node connectors do not run from
center to center.

```yaml
elements:
  - id: "flow"
    type: "connector"
    content:
      kind: "straight"
      start: { element: "source" }
      end: { element: "target" }
      end_arrow: "triangle"
      stroke: { color: "$accent", width: 2.0, dash: "solid" }
```

Element endpoints refer to another element by id. Use `anchor` only when the
automatic facing edge is not the intended connection point:

```yaml
start: { element: "source", anchor: "bottom" }
end: { element: "target", anchor: "top" }
```

Supported anchor values are `auto`, `center`, `left`, `right`, `top`, and
`bottom`. The schema does not expose raw PowerPoint connection site indices;
`pptz` chooses the backend connection site.

The loader emits a warning when a connector's straight segment crosses a
non-endpoint element, such as three nodes in a row with the first node connected
directly to the third.

## Table Element

Tables have a canonical PowerPoint table form and an optional shorthand. The
current writer renders rectangular tables, including cells that declare
`col_span` or `row_span`.

Canonical form:

```yaml
elements:
  - id: "summary"
    type: "table"
    bounds: [80, 120, 720, 300]
    content:
      style: "$compact"
      col_widths: [240, 240, 240]
      row_heights: [48, 48]
      rows:
        - cells:
            - text: "Metric"
              col_span: 3
              fill: { type: "solid", color: "$surface" }
```

The canonical model covers rows, cells, merge spans, fills, borders, margins,
anchors, and a table-level theme style token. A table style may define
`font_size`, `font_family`, `header_fill`, `header_text_color`,
`body_text_color`, and `border`; explicit cell fill or border values override
the table style. Legacy `header_color` and `body_color` are accepted as aliases
for the corresponding text color fields, but a style must not mix old and new
names.

Shorthand form:

```yaml
content:
  data:
    - ["Metric", "Q1", "Q2"]
    - ["Revenue", "100", "150"]
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

Chart data is inline in page YAML for the first slice. Category charts may use
either explicit `categories` plus `series` tables or the compact `data`
matrix shorthand.

```yaml
elements:
  - id: "revenue_chart"
    type: "chart"
    bounds: [80, 120, 720, 360]
    content:
      kind: "bar"
      title: "Quarterly revenue"
      legend: "bottom"
      style: 4
      data_labels: "outside_end"
      rounded_corners: false
      categories: ["Q1", "Q2", "Q3", "Q4"]
      series:
        - name: "Revenue"
          values: [100.0, 200.0, 300.0, 250.0]
```

Equivalent category chart shorthand:

```yaml
content:
  kind: "bar"
  data:
    - ["", "Q1", "Q2", "Q3", "Q4"]
    - ["Revenue", 100.0, 200.0, 300.0, 250.0]
```

Supported `legend` values are `hidden`, `bottom`, `top_right`, `left`,
`right`, and `top`. Supported `data_labels` values are `hidden`, `best_fit`,
`bottom`, `center`, `inside_base`, `inside_end`, `left`, `outside_end`,
`right`, and `top`.

Scatter series use `x_values` plus `values` for Y values. Bubble series add
`bubble_sizes`.

3D charts, stock charts, surface charts, of-pie charts, chartEx families, and
external CSV or spreadsheet-backed data are outside the current chart slice.
Scatter and bubble charts still use explicit series with `x_values` and cannot
use the category `data` shorthand.

## 0.3.0 Release Boundary

`0.3.0` promotes authoring ergonomics for real content decks:

- rich text paragraphs, styled runs, bullets, external hyperlinks, body insets,
  and shrink autofit enabled by default;
- table-level theme styles for header/body text, header fill, and borders;
- chart style templates for reusable chart options;
- layout templates with text slots and default elements;
- component templates with local coordinates and text props;
- category chart `data` shorthand normalized into the existing chart AST.

## 0.2.x Release Boundary

`0.2.0` shipped after:

- this v2 schema architecture is documented;
- the image slice compiles end-to-end from source to PPTX;
- `stretch`, `cover`, `contain`, explicit crop, and SVG pictures are covered by
  the maintained example deck and tests;
- writer capability errors are removed for implemented image slice features.

Later 0.2.x releases promote documented shape, connector, table, and chart
schema from design-only concepts into implemented writer slices. The current
writer state is documented in `README.md` and `REFERENCE.md`.
