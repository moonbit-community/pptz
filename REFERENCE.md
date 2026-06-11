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
   MVP writer scope:
   deck size, ordered pages, optional solid background, text elements,
   rectangle/ellipse shape elements, raster image elements stretched to their
   bounds, and basic theme
   color/text-style resolution with element-local overrides. Valid AST features
   outside this MVP subset may fail as writer capability errors.
   MVP text styling follows the `moon-pptx@0.4.0` `RunProperties` builder
   surface: `font_size`, `font_family`, `color`, `bold`, and `italic`.
   `letter_spacing` and `line_height` may remain schema/AST concepts but are
   outside the MVP writer scope.
   The MVP writer must not silently ignore declared fields that it cannot map
   to `moon-pptx`. Fail with a writer capability error instead.

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
- Image, background, and icon asset paths must not be empty.
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

The first loader warning set is limited to `PZ100`, `PZ101`, and `PZ102`. Do not
add authoring-quality or design-taste warnings.
`PZ100` is emitted when
`x < 0 || y < 0 || x + width > deck.width || y + height > deck.height`.
An element may produce multiple warnings.
`PZ102` uses MoonBit's library-provided trim behavior or equivalent standard
string trimming. Do not define a custom whitespace character set.

Negative `x` or `y` bounds are allowed and may produce an outside-canvas
warning. Negative `width` or `height` bounds are errors.
Zero `width` or `height` produces a warning for every element type. The first
implementation does not define element-type-specific zero-size exceptions.

The loader should not warn on element overlap. Overlap is often an intentional
presentation technique and would create noisy warnings without a separate
element role or layer model.

The loader should not inspect image dimensions or parse image file contents.
It should not download remote assets.
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

Loader diagnostics must include a stable code in addition to human-readable
text. Messages may change; codes should not. Initial code ranges:

- `PZ001`: invalid deck size.
- `PZ010`: unresolved page reference.
- `PZ020`: duplicate element id.
- `PZ021`: invalid element id.
- `PZ030`: unresolved theme token.
- `PZ032`: invalid color value.
- `PZ040`: invalid or empty asset path.
- `PZ100`: element bounds outside canvas.
- `PZ101`: invalid or zero-size element bounds. Negative width or height is an
  error; zero width or height is a warning.
- `PZ102`: empty or whitespace-only text content.

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
`icon`, `table`, `chart`, image backgrounds, and `gradient` backgrounds are
allowed schema/AST concepts but are outside the MVP writer scope unless later
implementation work explicitly adds them.
MVP shape content supports only `rect` and `ellipse` shape subtypes:

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

Image `fit` values are `stretch`, `cover`, or `contain`. Omitted `fit` defaults
to `stretch`. The MVP writer maps raster image elements with `stretch` directly
to `moon-pptx` picture bounds; `cover` and `contain` may fail as writer
capability errors until implemented.
MVP image element content uses a deck-relative raster image path:

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
