# Milky2018/pptz

`pptz` is PowerPoint Zero, a portable MoonBit presentation compiler. It reads a
TOML deck file, validates the deck and referenced page files, and writes a PPTX
through a wasm CLI.

## Usage

Use the published package:

```bash
moon runwasm Milky2018/pptz <deck.toml> [--out <output.pptx>]
```

For reproducible runs, pin the published version:

```bash
moon runwasm Milky2018/pptz@0.2.3 <deck.toml> [--out <output.pptx>]
```

Run the command from the deck project directory and use relative paths. The
published wasm runs with WASI-style file access, so absolute paths outside the
current working tree may not be visible.

While developing this repository, run the top-level package:

```bash
moon runwasm . examples/minimal/deck.pptz.toml --out examples/minimal/dist/demo.pptx
```

If `--out` is omitted, the output path defaults to `output.pptx`.

## Agent Skill

This repository can also be installed as an agent skill with the Skills CLI.
Keep the `SKILL.md` frontmatter name as `pptz`.

```bash
npx skills add https://github.com/moonbit-community/pptz.git
```

If you are installing from a repository that contains multiple skills, select
this skill explicitly:

```bash
npx skills add https://github.com/moonbit-community/pptz.git --skill pptz
```

You can also target a specific agent or install globally:

```bash
npx skills add https://github.com/moonbit-community/pptz.git --agent codex
npx skills add https://github.com/moonbit-community/pptz.git --global
```

After installation, ask your agent to use `pptz` when you need a
PPTX deck generated from TOML sources. The skill will guide the agent to:

- design a deck directory with `deck.pptz.toml`, `pages/`, optional `images/`,
  and `dist/`;
- keep sources within the writer's supported feature set;
- compile the deck with `moon runwasm Milky2018/pptz`;
- deliver both the TOML sources and generated `.pptx`.

## Current Writer Scope

The current writer supports:

- explicit deck size and ordered page files;
- optional solid, gradient, or image page backgrounds;
- text elements with theme text styles, local overrides, text wrapping, and
  line breaks;
- PowerPoint preset auto-shapes, excluding line and connector presets;
- straight connectors with coordinate or element endpoints, stroke, dash, and
  arrowheads;
- solid fills, gradient fills, no-fill shapes, and solid or dashed borders;
- outer shadows for shape and connector elements;
- built-in icon elements for `cube`, `circle`, `square`, `star`, `heart`, and
  `plus`, with optional `fas:`-style prefixes;
- table elements with explicit or evenly distributed column widths and row
  heights;
- inline chart elements for `bar`, `line`, `pie`, `doughnut`, `area`,
  `scatter`, `bubble`, and `radar`;
- raster image elements with `fit = "stretch"`, `fit = "cover"`, or
  `fit = "contain"`;
- image crop rectangles;
- SVG image elements, using an internal transparent PNG fallback required by
  `moon-pptx`.

Schema-valid features outside this scope fail with a writer capability error
instead of being silently ignored. This includes `letter_spacing`, table merge
spans, unsupported icon names, unsupported connector kinds, line/connector
shape presets, and unsupported shape names.

## Example

The maintained example deck is in `examples/minimal`. It is intentionally small
but covers the features the writer can render today.

```bash
cd examples/minimal
moon runwasm Milky2018/pptz deck.pptz.toml --out dist/demo.pptx
```

For local development against the checkout instead of the published wasm:

```bash
moon runwasm . examples/minimal/deck.pptz.toml --out examples/minimal/dist/demo.pptx
```

## Validation

Run the wasm target checks before relying on a change:

```bash
moon check --target wasm
moon test --target wasm
```

See `REFERENCE.md` for the source schema, diagnostics, and CLI contract.
