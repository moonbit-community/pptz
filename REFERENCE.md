# pptz Reference

## CLI Contract

The stable command shape for agents exposes one public operation: compile a
`pptz` project into a PPTX file. `pptz` should not expose public `check` or
`format` commands; checking is an internal stage of compilation.

```bash
moon runwasm Milky2018/pptz <project-dir> --out <output.pptx>
```

If `Milky2018/pptz` is not published yet, use the local top-level package:

```bash
moon runwasm . examples/minimal --out examples/minimal/dist/demo.pptx
```

This repository implements `Milky2018/pptz`. The compile output is the source of
truth. Do not infer success from a created file alone.

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

`deck.pptz.toml` is the root file. It contains document metadata, canvas size,
theme values, page order, and output settings.

`*.page.toml` files contain exactly one slide each. Pages should not redefine
global theme tokens unless a slide intentionally deviates.

Keep the boundary clear: `pptz` defines the TOML-to-AST-to-PPTX conversion
semantics. The portable Agent skill defines a recommended slide-making
workflow. Workflow preferences, such as creating a common background image, must
not become `pptz` checker requirements unless they are required for PPTX
generation.

The MoonBit implementation depends on:

```moonbit
import {
  "bobzhang/toml@0.4.1",
  "moonbit-community/miniio@0.2.0",
}
```

All paths are relative to the deck file directory. Prefer these folders:

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
3. Add a checker that validates AST invariants and reports errors/warnings with
   file and element context.
4. Add the PPTX writer after checker output is reliable.

Do not add a `format` command. Formatting TOML is outside `pptz`; `pptz`
converts a project into a PPTX.
Do not add a public `check` command. Checking is part of compilation.

## Checker Scope

The checker is part of `pptz`. It must only validate `pptz` semantics and PPTX
generation preconditions. It must not validate Agent workflow preferences,
visual taste, design quality, or slide-making process rules.

The checker should validate a deck bundle, not isolated AST nodes. It should
receive the deck definition, resolved page files, and deck directory.
Page identity is the `PageRef.path` string. Do not add a separate page id to the
AST for the first implementation.

Errors block PPTX generation:

- Deck width and height must be greater than zero.
- A deck must reference at least one page.
- Every page reference must resolve to a page.
- Extra resolved page files that are not referenced by the deck may be reported
  as warnings.
- Element ids must be unique within a page.
- Bounds width and height must not be negative.
- Image, background, and icon asset paths must not be empty.
- Referenced local image assets must exist and must be files, not directories.
- Remote asset URLs are not allowed. Agents must download or generate assets
  into the deck directory before referencing them.
- Asset paths must be portable relative paths inside the deck directory.
  Absolute paths and paths that normalize outside the deck directory are errors.
- Theme token references such as `$text` must resolve to declared theme values.
- Text elements must contain non-empty text.
- Output path must not be empty.

Warnings allow generation but indicate potentially surprising `pptz` semantics:

- Element bounds extend outside the canvas.
- Element bounds width or height is zero.

The checker should not warn on element overlap. Overlap is often an intentional
presentation technique and would create noisy warnings without a separate
element role or layer model.

The checker should not inspect image dimensions or parse image file contents.
It should not download remote assets.

Theme token handling is deliberately simple:

- Only whole-string references such as `$text` or `$title` are token references.
- Color-like fields resolve against `theme.colors`.
- Style fields resolve against `theme.text_styles`.
- Text content is plain text; do not scan `$name` inside HTML/text content.
- Embedded expressions such as `linear($a, $b)` are not interpreted as token
  references in the first slice.

Checker diagnostics must include a stable code in addition to human-readable
text. Messages may change; codes should not. Initial code ranges:

- `PZ001`: invalid deck size.
- `PZ010`: unresolved page reference.
- `PZ020`: duplicate element id.
- `PZ030`: unresolved theme token.
- `PZ040`: invalid or empty asset path.
- `PZ050`: invalid output path.
- `PZ100`: element bounds outside canvas.
- `PZ101`: zero-size element bounds.

## Deck Fields

Use this shape unless the current `pptz` checker documents a newer schema:

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
line_height = 1.1

[[pages]]
path = "pages/cover.page.toml"

[output]
path = "dist/example.pptx"
```

## Page Fields

Use tables for elements so every element is independently addressable:

```toml
page_type = "cover"

[background]
type = "image"
path = "../images/background.svg"
fit = "cover"

[[elements]]
id = "title"
type = "text"
bounds = [80, 220, 1120, 100]

[elements.content]
style = "$title"
align = ["center", "middle"]
text = "<p>Example Deck</p>"
```

Recommended element types: `text`, `shape`, `image`, `icon`, `table`, `chart`.
Recommended background types: `solid`, `gradient`, `image`.

## Design Rules

Start from the deck's communication goal, not from decoration. The common
background should support multiple page densities: title, section divider,
diagram, image-heavy, and text-heavy pages.

Prefer stable coordinates and explicit sizes. Do not rely on automatic layout
unless the checker and renderer support it.

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
