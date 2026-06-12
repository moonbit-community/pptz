# pptz Reference

## CLI Contract

The stable command shape for agents exposes one public operation: compile a TOML
deck file into a PPTX file. `pptz` should not expose public `check` or
`format` commands; validation is part of loading/compilation.

```bash
moon runwasm Milky2018/pptz <deck.toml> [--out <output.pptx>]
```

The CLI must be implemented with MoonBit's standard `moonbitlang/core/argparse`
package, not a hand-written argument dispatcher.
The CLI accepts exactly one input TOML deck file per invocation. Generate
multiple decks with multiple invocations. The `.pptz.toml` extension is
recommended but not required.
The CLI must check that the input path exists and is a file before parsing it.
It must not validate the input by extension.

If `Milky2018/pptz` is not published yet, use the local top-level package:

```bash
moon runwasm . examples/minimal/deck.pptz.toml --out examples/minimal/dist/demo.pptx
```

This repository implements `Milky2018/pptz`. The compile output is the source of
truth. Do not infer success from a created file alone.

Relative paths inside the deck file are resolved from the input TOML deck file's
directory. If `--out` is omitted, output defaults to `output.pptx`.
Relative output paths are resolved from the current working directory.
When the output path has a parent directory that does not exist, `pptz` should
create it. If the output path is empty, points to a directory, or cannot be
written, compilation fails.
The output path is a CLI output path, not a deck-relative source path. It does
not need to stay inside the deck directory.
The writer must not leave a partial PPTX at the final output path. Write to a
temporary file first, then replace or move it to `--out` only after successful
generation. On failure, delete the temporary file where possible.
If the final output file already exists, successful generation overwrites it.
Place the temporary file in the final output file's parent directory, not in the
deck directory or a global temporary directory.
Temporary output filenames should be hidden files based on the final output
basename, such as `.deck.pptx.tmp-1`. The suffix only needs to be unique within
the current process. A failed invocation should delete the temporary file it
created when possible. `pptz` is not responsible for cleaning up temporary files
from earlier crashed invocations.

CLI diagnostics are written to stderr with `miniio.stderr.write_text`, not
`println`. Use one diagnostic per line in this fixed shape:

```text
<severity> <code> <path> <element_id> <field>: <message>
```

Use `-` for missing `path`, `element_id`, or `field` values. Examples:

```text
warning PZ100 pages/cover.page.toml title elements.bounds: bounds extend outside canvas
error PZ020 pages/cover.page.toml title elements.id: duplicate element id
```

On success, stdout contains one line with the generated PPTX path:

```text
wrote path/to/output.pptx
```

When generation succeeds without warnings, stderr is empty. When generation
succeeds with warnings, the CLI still exits with code `0` and writes warning
diagnostics to stderr. Blocking errors are written to stderr and exit non-zero.

Argument parsing errors are CLI usage errors, not loader diagnostics. They do
not use `PZxxx` diagnostic codes. Let the `argparse`-based CLI report usage or
argument errors to stderr and exit non-zero. Only errors found after entering
`load_deck` use structured `Diagnostic` values.

During local development, validate the MoonBit packages with the portable wasm
target:

```bash
moon check --target wasm
moon test --target wasm
moon runwasm . -- --version
```

Current `moon runwasm` local execution may not propagate non-zero WASI exits to
the shell. Treat visible `Error:`, `RuntimeError`, and explicit `pptz` failure
text as failures during local development.

## Source Format

The input TOML deck file contains optional document metadata, canvas size,
optional theme values, and page order. Its filename is not fixed. Output
settings do not belong in the deck file.
Before 1.0, the source schema is strict: unknown fields are errors. Do not keep
unknown fields for forward compatibility.
TOML keys use snake_case. camelCase aliases are not accepted.
Do not introduce schema-version negotiation for `pptz v2`; compatibility across
pre-1.0 schema revisions is outside the current planning scope.
For `pptz v2`, design the overall AST and TOML schema architecture upfront so
image, shape, connector, table, and chart features share consistent primitives.
Implementation can still land incrementally by capability slice.
Do not provide raw OpenXML, arbitrary XML extension, or backend-passthrough
fields in the TOML schema. Capabilities must be expressed through `pptz`
semantic fields that the loader can validate.
Treat the v2 schema design as a design milestone, not a release by itself. A
published `pptz` release should be bounded by capabilities that compile from
TOML to PPTX.
The minimum `0.2.0` release boundary was: the v2 AST/TOML schema architecture
is documented, and the image capability slice compiles end-to-end from TOML to
PPTX. Later 0.2.x releases have added implemented shape, connector, table, and
chart writer slices; this reference tracks the current accepted schema.

The v2 schema architecture is documented in `docs/v2-schema.md`. It is the
planning-level source for shared primitives and future capability slices; this
reference remains the implementation contract for fields accepted by the current
parser.

Parser responsibilities:

- Required fields.
- Field types.
- Unknown fields.
- Constructing the semantic AST.

Parser failures, including TOML syntax errors, field type errors, missing
required fields, and unknown fields, are parse failures. When they occur through
`load_deck`, report them as `LoadError::Fatal(String)` in the first
implementation rather than as aggregated loader diagnostics.

Loader responsibilities:

- Read the input TOML deck file.
- Parse the deck definition.
- Resolve page paths relative to the deck file directory.
- Reject absolute page paths and page paths that normalize outside the deck file
  directory before reading them.
- Read and parse referenced page files.
- Reuse parsed page ASTs for repeated page references while preserving the
  deck's page reference order.
- Validate AST semantics and PPTX generation preconditions.
- Resolve theme tokens.
- Validate asset paths.
- Validate bounds and duplicate element ids.
- Return a loaded deck for PPTX generation, including the validated bundle and
  any non-blocking warnings.

Initial loader API:

```moonbit
pub fn load_deck(input_path : String) -> LoadedDeck raise
```

Initial loaded deck and bundle shape:

```moonbit
pub(all) struct LoadedDeck {
  bundle : DeckBundle
  warnings : Array[Diagnostic]
}

pub(all) struct DeckBundle {
  deck_path : String
  deck_dir : String
  deck : Deck
  pages : Array[ResolvedPage]
}

pub(all) struct ResolvedPage {
  path : String
  full_path : String
  page : Page
}
```

`ResolvedPage.path` preserves the original string from `PageRef.path`.
`ResolvedPage.full_path` stores the deck-directory-joined normalized path used
for WASI-accessible file reads. It should not force the source path through a
host absolute `Path::resolve()` call; portable `moon runwasm` executions may
only have relative preopened paths available.

`*.page.toml` files contain exactly one slide each. Pages should not redefine
global theme tokens unless a slide intentionally deviates.
Page files may reference theme tokens declared by the deck file. Token checking
therefore happens during deck bundle loading, not on isolated pages.
Page files must not declare local theme tokens. Local visual deviations should
use direct values on elements.
Slide order is exactly the order of the deck file's `pages` array. `pptz` must
not scan directories, expand globs, or auto-sort page files.
The `pages` array may reference the same page file more than once; each
reference produces one slide.
Repeated page files should be read and parsed once, then reused according to
the reference order.
Use the normalized `full_path` as the cache key for repeated page file reads
and parses. `ResolvedPage.path` still preserves the original
`PageRef.path` string for context and ordering.
Path handling should use `moonbitlang/x/path` rather than custom string
rewriting. Reject paths that the path package resolves outside the deck
directory. Do not resolve symlinks or require filesystem
canonicalization.
Page paths and asset paths share the same deck-relative source path rules.
They differ only in what the loader does after resolution: page paths are read
and parsed as TOML, while asset paths are checked for existence and file kind
without parsing asset contents.

Image elements use a required deck-relative `path`, optional `fit`, and optional
`crop` table:

```toml
[[elements]]
id = "hero"
type = "image"
bounds = [80, 120, 640, 360]

[elements.content]
path = "images/hero.svg"
fit = "cover"

[elements.content.crop]
left = 0.1
top = 0
right = 0.1
bottom = 0
```

`fit` defaults to `stretch`. `cover` fills the element bounds and crops overflow
from the source image. `contain` preserves the source aspect ratio and centers
the image inside the element bounds. Explicit crop values are normalized
fractions of the source rectangle, each between `0.0` and `1.0`; `left + right`
and `top + bottom` must each leave a non-empty source rectangle. Explicit crop
is applied before `cover` or `contain` fit math.

Raster image dimensions are read through `moon-pptx`. SVG dimensions are read
from numeric `width`/`height` attributes or `viewBox`. SVG TOML does not expose
a fallback image field; the writer provides the backend-required fallback
internally.

Keep the boundary clear: `pptz` defines the TOML-to-AST-to-PPTX conversion
semantics. The portable Agent skill defines a recommended slide-making
workflow. Workflow preferences, such as creating a common background image, must
not become `pptz` loader requirements unless they are required for PPTX
generation.

The MoonBit implementation depends on:

```moonbit
import {
  "bobzhang/toml@0.4.1",
  "moonbit-community/miniio@0.2.0",
  "moonbitlang/x",
}
```

Do not pin `moonbitlang/x` in the design contract. Add it as a direct
dependency when importing `moonbitlang/x/path`, and let `moon` resolve the
version.

All relative paths are resolved from the input TOML deck file's directory.
Prefer these folders next to the deck file:

```text
pages/
images/
dist/
```

## Implementation Order

Build `pptz` in this order:

1. Define the semantic AST for decks, pages, backgrounds, elements, styles, and
   asset references. Current status: implemented in `ast.mbt`.
2. Parse TOML sources into the AST without validation side effects. Current
   status: `parse_deck_toml(String) -> Deck raise` and
   `parse_page_toml(String) -> Page raise` are implemented in `parser.mbt`.
3. Add a loader that reads the input deck file, resolves pages, validates the
   resulting bundle, and reports diagnostics with file and element context.
   Current status: implemented in `loader.mbt`.
4. Add the PPTX writer after loader validation is reliable.
   A successful writer result must be a valid PPTX that PowerPoint-compatible
   tools can open. Do not report success with a placeholder file.
   Writer tests must at least verify that the generated file is a ZIP with core
   OpenXML entries:
   `[Content_Types].xml`, `_rels/.rels`, `ppt/presentation.xml`,
   `ppt/slides/slide1.xml`, and `ppt/slides/_rels/slide1.xml.rels`.
   Use `t-ujiie-g/moon-pptx` as the PPTX backend. Do not pin its version in the
   design contract. Map the MVP `pptz` AST subset to the `moon-pptx` builder
   API and use `Presentation::save()` to obtain PPTX bytes. Do not implement a
   separate ZIP or OpenXML writer as the primary path.
   The MVP capability baseline is the observed `t-ujiie-g/moon-pptx@0.4.0`
   builder API. Keep MVP source features close to what that API can express
   directly.
   Current writer scope:
   deck size, ordered pages, optional solid/gradient/image background, text
   elements with wrapping and line breaks, preset auto-shape elements excluding
   line and connector presets, straight connector elements, solid/no-fill/
   gradient shape fills, alpha colors, solid and dashed shape borders, outer
   shadows for shape and connector elements, built-in icon elements, raster
   image elements with `stretch`, `cover`, or `contain`, SVG image elements,
   image crop rectangles, and basic theme color/text-style resolution with
   element-local overrides. Valid AST features outside this subset may fail as
   writer capability errors.
   MVP text styling follows the `moon-pptx@0.4.0` text builder surface:
   `font_size`, `font_family`, `color`, `bold`, `italic`, `line_height`, and
   `wrap`. `letter_spacing` remains a schema/AST concept but is outside the
   current `moon-pptx@0.4.0` writer surface.
   The MVP writer must not silently ignore declared fields that it cannot map
   to `moon-pptx`. Fail with a writer capability error instead.
   Current status: `writer.mbt` generates valid PPTX bytes for deck size,
   ordered pages, optional solid/gradient/image backgrounds, text elements
   with wrapping and line breaks, preset auto-shape elements excluding line and
   connector presets, straight, bent, and curved connectors with coordinate or
   element endpoints, solid/no-fill/gradient shape fills, alpha colors, solid
   and dashed shape borders, outer shadows for shape and connector elements,
   built-in icon elements, table elements with explicit or evenly distributed
   column widths and row heights including merge spans, inline chart elements
   with title, legend, style, data-label, data-table, and rounded-corner
   options, image elements with `stretch`, `cover`, `contain`, explicit crop,
   SVG pictures, and basic theme color/text-style resolution including
   `line_height`. It returns capability errors for schema-valid features that
   are still outside the implemented writer subset.

Compiler Reliability status:

- Implemented temp-first output so render failures do not replace an existing
  PPTX at the final output path.
- CLI contract coverage includes success, argument failures, and a
  representative writer capability failure.
- Unsupported schema-valid writer features remain capability errors.
- Writer tests cover representative capability errors for unsupported features.
- OpenXML package smoke checks are part of the writer test gate.
- `examples/minimal` is the single maintained current-capabilities regression
  example.
- Agent-facing documentation is synchronized with the current writer scope.

Do not add a `format` command. Formatting TOML is outside `pptz`; `pptz`
converts a TOML deck file into a PPTX.
Do not add a public `check` command. Validation is part of loading/compilation.

## Loader Validation Scope

Loader validation is part of `pptz`. It must only validate `pptz` semantics and
PPTX generation preconditions. It must not validate Agent workflow preferences,
visual taste, design quality, or slide-making process rules.
Beyond generation preconditions and explicit visibility warnings, the loader
should avoid content-level semantic judgment. If a valid source value can be
carried to PPTX, preserve the user's value instead of normalizing, sorting, or
rejecting it.

The loader validates the deck definition, resolved page files, and the input
deck file's directory while producing a generation-ready deck bundle.
Page identity is the `PageRef.path` string. Do not add a separate page id to the
AST for the first implementation.
Element ids are required. Missing element ids are parser/schema failures.
Duplicate element ids within a page are loader validation errors.
Element ids must match `[A-Za-z][A-Za-z0-9_-]*`. Invalid element id syntax is a
loader validation error.

Errors block PPTX generation:

- Deck width and height must be greater than zero.
- A deck must reference at least one page.
- Every page reference must resolve to a page.
- Element ids must be unique within a page.
- Bounds width and height must not be negative.
- Image and background asset paths must not be empty.
- Icon names must not be empty.
- Referenced local image assets must exist and must be files, not directories.
- Remote asset URLs are not allowed. Agents must download or generate assets
  into the deck directory before referencing them.
- Asset paths must be portable relative paths inside the deck directory.
  Absolute paths and paths that normalize outside the deck directory are errors.
- Theme token references such as `$text` must resolve to declared theme values.

Warnings allow generation but indicate potentially surprising `pptz` semantics:

- Element bounds extend outside the canvas.
- Element bounds width or height is zero.
- Text element content is empty or whitespace-only.

`PZ100` is emitted when
`x < 0 || y < 0 || x + width > deck.width || y + height > deck.height`.
An element may produce multiple warnings.
`PZ102` uses MoonBit's library-provided trim behavior or equivalent standard
string trimming. Do not define a custom whitespace character set.
`PZ103` is an estimated visibility warning, not a full PowerPoint layout engine.
It should catch obvious text overflow without judging slide content quality.

Negative `x` or `y` bounds are allowed and may produce an outside-canvas
warning. Negative `width` or `height` bounds are errors.
Zero `width` or `height` produces a warning for every element type. The first
implementation does not define element-type-specific zero-size exceptions.

The loader should not warn on element overlap. Overlap is often an intentional
presentation technique and would create noisy warnings without a separate
element role or layer model.

The loader inspects image dimensions only when needed for PPTX generation
preconditions such as `cover` or `contain` fit. It should not download remote
assets.
The loader should not judge table layout quality, chart data reasonableness,
color contrast, gradient stop order, or other authoring choices that are not
required to construct the PPTX.

Theme token handling is deliberately simple:

- Only whole-string references such as `$text` or `$title` are token references.
- Token names must match `[A-Za-z][A-Za-z0-9_-]*`.
- Theme definition keys under `theme.colors` and `theme.text_styles` must match
  the same token name rule.
- Color-like fields resolve against `theme.colors`.
- Style fields resolve against `theme.text_styles`.
- Text style definitions do not inherit from or reference other text styles in
  the first schema.
- When an element references a theme text style, direct style fields on that
  element override the referenced style. This style resolution does not mutate
  the parsed AST.
- Text style fields may include `font_size`, `font_family`, `color`, `bold`,
  and `italic` in both `theme.text_styles.<name>` and element-local text
  content.
- Text content is plain text. Do not parse HTML, XML, Markdown, or rich-text
  markup inside `text`, and do not scan `$name` inside text content.
  Newline characters in `text`, including TOML multiline string newlines, map
  to PPTX text line breaks.
  Bullets and rich paragraph structure are outside the MVP. Do not infer bullets
  from Markdown-like text.
- Embedded expressions such as `linear($a, $b)` are not interpreted as token
  references in the first slice.

Color values support only CSS-style hex strings and theme token references:

- `#RRGGBB`
- `#RRGGBBAA`
- `$token`

Named colors, `rgb(...)`, `rgba(...)`, `transparent`, and other CSS color
syntaxes are not part of `pptz`.
Eight-digit hex uses CSS order: `#RRGGBBAA`, where the final `AA` is alpha.
`#AARRGGBB` is not supported.
Hex digits may be uppercase or lowercase.
The parser only requires color-bearing fields to be strings. The loader checks
whether each color value is a supported hex color or a valid theme token
reference. Invalid color syntax is a loader validation error; unresolved token
references use the theme-token diagnostic.

Gradient backgrounds use a minimal linear-gradient schema:

```toml
[background]
type = "gradient"
direction = 90
stops = [
  { at = 0.0, color = "$background" },
  { at = 1.0, color = "$surface" },
]
```

`direction` is a `Double` in degrees. Each stop has `at : Double` and `color`
using the normal color/token rules. The loader does not validate gradient stop
count, stop ordering, or `at` ranges in the first schema; the writer should emit
the user-provided gradient data into PPTX as directly as its backend allows.
Radial gradients, conic gradients, CSS gradient strings, and unit-bearing
directions are not part of the first schema.
Shape gradient fills use the same `direction` and `stops` fields under
`[elements.content.fill]` when `type = "gradient"`. The current writer supports
both page background gradients and shape gradient fills.

Image backgrounds use the same deck-relative image path and `fit` values as
image elements, without explicit crop:

```toml
[background]
type = "image"
path = "images/background.png"
fit = "cover"
```

The writer renders an image background as the first full-slide picture shape so
subsequent text, shapes, and image elements appear above it.

Loader diagnostics must include a stable code in addition to human-readable
text. Messages may change; codes should not. Initial code ranges:

- `PZ001`: invalid deck size.
- `PZ010`: unresolved page reference.
- `PZ020`: duplicate element id.
- `PZ021`: invalid element id.
- `PZ030`: unresolved theme token.
- `PZ032`: invalid color value.
- `PZ040`: invalid or empty asset path.
- `PZ060`: invalid table structure.
- `PZ070`: invalid chart data or unsupported chart kind.
- `PZ100`: element bounds outside canvas.
- `PZ101`: invalid or zero-size element bounds. Negative width or height is an
  error; zero width or height is a warning.
- `PZ102`: empty or whitespace-only text content.
- `PZ103`: text may overflow its element bounds. This is an estimate because
  PowerPoint text layout depends on viewer fonts and rendering behavior.

Loader validation should collect all diagnostics it can collect before failing,
so agents can fix multiple issues in one pass. Blocking input errors, such as
the input deck file being unreadable or TOML parsing failing, may fail
immediately.
Blocking validation diagnostics are reported through the loader error. Warning
diagnostics are returned on `LoadedDeck.warnings` and do not block PPTX
generation.

Diagnostic shape:

```moonbit
pub(all) suberror LoadError {
  Fatal(String)
  Diagnostics(Array[Diagnostic])
}

pub(all) enum Severity {
  Error
  Warning
}

pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  path : String?
  element_id : String?
  field : String?
}
```

Diagnostics do not include line or column source locations. Use `path` for the
deck, page, or asset path involved; use `element_id` only for element-scoped
findings; use `field` for stable field paths such as `size.width`,
`background.path`, or `elements.bounds`.
Use `LoadError::Fatal` for failures that prevent further collection, such as an
unreadable input file or TOML parse failure. Use `LoadError::Diagnostics` when
the loader has enough context to report one or more blocking validation
diagnostics. Warnings are not raised; they are returned on
`LoadedDeck.warnings`.

## Deck Fields

Use this shape unless the current `pptz` loader documents a newer schema:

```toml
title = "Example Deck"
size = [1280, 720]

[theme.colors]
background = "#10131A"
surface = "#1C2230"
text = "#F4F6FB"
muted = "#A8B0C2"
primary = "#3B82F6"
accent = "#F59E0B"

[theme.text_styles.title]
font_size = 56
font_family = "Liter, MiSans"
color = "$text"
bold = true

[[pages]]
path = "pages/cover.page.toml"
```

The whole `theme` table is optional. A deck without theme values may still
generate PPTX if pages use direct values. If a page or style references a theme
token, the corresponding theme table and token must exist.
The `title` field is optional metadata. `size` and non-empty `pages` are the
core required deck fields.
The `size` field is always explicit `[width, height]`; named presets such as
`"wide"` are not part of `pptz`.
Deck size and element bounds use `Double` logical pixel units. TOML integers and
floats are accepted and normalized into the AST as `Double`. The PPTX writer
maps those logical units to PPTX EMUs. Unit strings, percentages, and layout
expressions are not part of `pptz`.
Use a fixed conversion of 1 logical pixel = 1 CSS pixel = 1/96 inch. Since one
inch is 914400 EMUs, `emu = logical_px / 96 * 914400`.
Round converted EMU values to the nearest integer.
Typography measurements are `Double` values in the AST. `font_size` is a point
size and maps to `moon-pptx` `@units.Pt`. Geometry remains in logical pixel
units and maps to PPTX EMUs.

## Page Fields

Use tables for elements so every element is independently addressable:

```toml
page_type = "cover"

[background]
type = "solid"
color = "$background"

[[elements]]
id = "title"
type = "text"
bounds = [80, 220, 1120, 100]

[elements.content]
style = "$title"
align = ["center", "center"]
text = "Example Deck"
```

Element tables use top-level `id`, `type`, and `bounds` for shared placement
metadata. Type-specific fields live under `[elements.content]`.

Allowed element types: `text`, `shape`, `image`, `icon`, `table`, `chart`.
Allowed background types: `solid`, `gradient`, `image`.
The current writer implements all allowed element types. Schema-valid fields
outside the implemented writer subset fail with capability errors instead of
being silently ignored.
MVP shape content supports PowerPoint preset auto-shapes by canonical `pptz`
snake_case names. Examples include `rect`, `round_rect`, `ellipse`, `diamond`,
`right_arrow`, `flow_chart_process`, `action_button_home`, `round2_diag_rect`,
and `math_not_equal`.

Line and connector presets are intentionally excluded from shape content:
`line`, `line_inv`, `straight_connector1`, `bent_connector2` through
`bent_connector5`, and `curved_connector2` through `curved_connector5` remain
outside the writer scope. They belong in the planned connector element family.

```toml
[[elements]]
id = "panel"
type = "shape"
bounds = [80, 160, 420, 220]

[elements.content]
shape = "rect"

[elements.content.fill]
type = "solid"
color = "$surface"
```

Planned v2 shape semantics expand shape subtypes toward the `moon-pptx`
preset-shape capability surface. User-facing shape names use `pptz`
snake_case names, not OpenXML camelCase names. For example, a backend preset
such as `roundRect` should be exposed as `round_rect`. `pptz` should maintain a
single mapping from snake_case shape names to `moon-pptx` preset shape values;
it should not accept both naming styles for the same shape.
Lines and connectors are not shape subtypes in v2. They are represented by a
separate `connector` element family so connector-specific semantics can grow
without overloading preset auto shapes.
The current writer supports straight, bent, and curved connectors with both
coordinate endpoints and element endpoints. Supported connector kinds are
`straight`, `bent2`, `bent3`, `bent4`, `bent5`, `curved2`, `curved3`,
`curved4`, and `curved5`. Coordinate endpoints use explicit slide coordinates.
Element endpoints refer to another text or shape element by id and let `pptz`
choose the backend connection site; the connector schema does not expose raw
PowerPoint connection site indices.
Shape borders, connector lines, and later table cell borders share a basic
stroke primitive for color, width, and dash style. Connector arrowheads are
connector-specific fields such as `start_arrow` and `end_arrow`; they are not
part of the shared basic stroke model.
The current writer maps shape `border.style` values `solid`, `dot`, `dash`,
`long_dash`, `dash_dot`, `long_dash_dot`, and `long_dash_dot_dot` to
PowerPoint preset dash styles.
The current writer supports outer shadows for shape and connector elements.
Opacity/alpha is a shared color, fill, stroke, and text capability rather than
an effect. `pptz` should not expose the full `moon-pptx` `EffectList` surface
in the first v2 slice.

The current writer supports built-in icon elements by mapping `icon.name` to
PowerPoint preset shapes. Supported names are `cube`, `circle`, `square`,
`star`, `heart`, `plus`, `home`, `info`, `help`, `return`, `blank`, `smiley`,
`sun`, `moon`, `cloud`, `lightning`, `gear6`, `gear9`, `funnel`,
`chart_plus`, `chart_star`, `chart_x`, and `no_smoking`; names may also use a
prefix such as `fas:cube`. Unknown icon names are writer capability errors.

Current table schema has a canonical table form based on PowerPoint table
concepts: rows, cells, merge spans, cell fills, cell borders, cell margins, and
cell anchors. A compact `data` shorthand is accepted for simple tables and is
normalized into the canonical rows/cells model before validation. Table
shorthand may omit column widths and row heights; omitted sizes are evenly
distributed inside the table element bounds by the writer. Explicit
`col_widths` and `row_heights` may override the equal distribution.
Weight-based table sizing is outside the v2 shorthand scope. The current
writer renders rectangular tables, including cells that declare `col_span` or
`row_span`.

Current chart writer support covers bar, line, pie, doughnut, area, scatter,
bubble, and radar chart families, with chart title, legend, style,
data-labels, data-table, and rounded-corner options. 3D charts, stock charts,
surface charts, of-pie charts, and chartEx families are outside the first v2
chart slice. The first chart slice uses inline chart data in page TOML.
External CSV, TOML, or spreadsheet-backed chart data is outside the first v2
chart slice.

Image `fit` values are `stretch`, `cover`, or `contain`. Omitted `fit` defaults
to `stretch`. The writer maps `stretch` directly to the requested bounds, uses
intrinsic image size for `cover` and `contain`, and supports SVG pictures.

`cover` and `contain` use the image asset's intrinsic size to preserve aspect
ratio automatically. Explicit crop rectangles use edge insets, not pixel
rectangles:

```toml
[elements.content.crop]
left = 0.1
top = 0.0
right = 0.1
bottom = 0.0
```

Each crop value is a `Double` in `0.0..1.0` and means "crop this fraction from
that source edge". This matches the PowerPoint/OpenXML source-rectangle model
and works for both raster images and SVG pictures. Automatically computed
`cover` crops should resolve to the same edge-inset model; explicit crop values
are for user-controlled refinement.

When `fit = "cover"` or `fit = "contain"` is combined with an explicit crop,
`pptz` first applies the explicit crop to choose the source region, then
computes the aspect-ratio-preserving fit from that cropped region into the
element bounds. Explicit crop values therefore narrow the source image before
automatic fitting; they do not replace the fit mode.

SVG pictures use the SVG asset directly. `pptz` does not support or require a
user-provided raster fallback image for SVG; the writer supplies the
backend-required fallback internally.

Image element content uses a deck-relative image path:

```toml
[[elements]]
id = "hero"
type = "image"
bounds = [640, 120, 520, 360]

[elements.content]
path = "images/hero.png"
fit = "stretch"
```

MVP text alignment uses `align = [horizontal, vertical]` with values that map
directly to `moon-pptx` text alignment and body anchor enums:

- horizontal: `left`, `center`, `right`, `justify`, `justify_low`,
  `distributed`, `thai_distributed`
- vertical: `top`, `center`, `bottom`, `justify`, `distributed`

Text `wrap = true` maps to PowerPoint square wrapping, and `wrap = false` maps
to no wrapping.

`page_type` is optional non-semantic metadata for agents, templates, or humans.
If present, it must be a string, but `pptz` does not restrict or warn on its
value.
Element `type` is semantic and strictly enumerated. Unknown element types are
schema failures because the PPTX writer cannot safely infer how to render them.
The schema may allow element types before the first PPTX writer implements all
of them. If the writer encounters a valid but unsupported element type, it must
fail without generating an incomplete PPTX. This is a writer capability error,
not a loader diagnostic.
Background `type` is also semantic and strictly enumerated. Unknown background
types are schema failures. If the writer encounters a valid but unsupported
background type, it must fail without generating an incomplete PPTX.

## Design Rules

Start from the deck's communication goal, not from decoration. The common
background should support multiple page densities: title, section divider,
diagram, image-heavy, and text-heavy pages.

Prefer stable coordinates and explicit sizes. Do not rely on automatic layout
unless the loader and renderer support it.

Use one primary visual system across the whole deck. If a slide needs a
different treatment, document the reason near the page source or in the final
handoff.

## Warning Policy

A warning is acceptable only when the agent can state:

- the exact warning text,
- the affected file and element id,
- why the rendered result is intended,
- why changing it would make the slide worse.

All other warnings must be fixed.

For `PZ103`, prefer fixing the source instead of accepting the warning: enlarge
the bounds, reduce font size, shorten the copy, split content across multiple
text boxes or slides, or add intentional line breaks.
