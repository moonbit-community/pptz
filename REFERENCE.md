# pptz Reference

## CLI Contract

The stable command shape for agents is:

```bash
moon runwasm Milky2018/pptz check <deck.pptz.toml>
moon runwasm Milky2018/pptz build <deck.pptz.toml> --out <output.pptx>
moon runwasm Milky2018/pptz format <deck.pptz.toml> --write
```

If `Milky2018/pptz` is not published yet, use the local top-level package:

```bash
moon runwasm . check deck.pptz.toml
```

This repository implements `Milky2018/pptz`. The checked source of truth is the
checker output. Do not infer success from a created file alone.

During local development, validate the MoonBit packages with the portable wasm
target:

```bash
moon check --target wasm
moon test --target wasm
moon runwasm . -- --version
```

Current `moon runwasm` local execution may not propagate non-zero WASI exits to
the shell. Wrapper scripts must also inspect output for `Error:`,
`RuntimeError`, and explicit `pptz` failure text.

## Source Format

`deck.pptz.toml` is the root file. It contains document metadata, canvas size,
theme values, page order, and output settings.

`*.page.toml` files contain exactly one slide each. Pages should not redefine
global theme tokens unless a slide intentionally deviates.

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
4. Add a formatter for TOML sources once the AST shape is stable.
5. Add the PPTX writer after checker output is reliable.

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
