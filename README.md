# Milky2018/pptz

`pptz` is PowerPoint Zero, a portable MoonBit presentation compiler. It reads a
YAML deck file, validates the deck and referenced page files, and writes a PPTX
through a wasm CLI.

## Usage

Use the published package:

```bash
moon runwasm Milky2018/pptz <deck.pptz.yaml> [--out <output.pptx>]
```

For reproducible runs, pin the published version:

```bash
moon runwasm Milky2018/pptz@0.5.0 <deck.pptz.yaml> [--out <output.pptx>]
```

Run the command from the deck project directory and use relative paths. The
published wasm runs with WASI-style file access, so absolute paths outside the
current working tree may not be visible.

While developing this repository, run the top-level package:

```bash
moon runwasm . examples/minimal/deck.pptz.yaml --out examples/minimal/dist/demo.pptx
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
PPTX deck generated from YAML sources. The skill will guide the agent to:

- design a deck directory with `deck.pptz.yaml`, `pages/`, optional `images/`,
  and `dist/`;
- keep sources within the writer's supported feature set;
- compile the deck with `moon runwasm Milky2018/pptz`;
- deliver both the editable sources and generated `.pptx`.

## Current Writer Scope

The current writer supports:

- explicit deck size and ordered page files;
- optional solid, gradient, or image page backgrounds;
- text elements with theme text styles, local overrides, text wrapping,
  line breaks, rich paragraphs, styled runs, bullets, external hyperlinks,
  body insets, shrink autofit enabled by default, and strict overflow
  validation unless `body.overflow` explicitly downgrades it;
- PowerPoint preset auto-shapes with optional embedded text, excluding line and
  connector presets;
- straight, bent, and curved connectors with coordinate or auto-anchored element
  endpoints, stroke, dash, and arrowheads;
- solid fills, gradient fills, no-fill shapes, and solid or dashed borders;
- outer shadows for shape and connector elements;
- built-in icon elements for `cube`, `circle`, `square`, `star`, `heart`,
  `plus`, `home`, `info`, `help`, `return`, `blank`, `smiley`, `sun`, `moon`,
  `cloud`, `lightning`, `gear6`, `gear9`, `funnel`, `chart_plus`,
  `chart_star`, `chart_x`, and `no_smoking`, with optional `fas:`-style
  prefixes;
- table elements with explicit or evenly distributed column widths and row
  heights, including cell merge spans, cell styling, and theme table styles;
- inline chart elements for `bar`, `line`, `pie`, `doughnut`, `area`,
  `scatter`, `bubble`, and `radar`, with title, legend, style, data labels,
  data table, rounded-corner options, and a category chart data shorthand;
- raster image elements with `fit: "stretch"`, `fit: "cover"`, or
  `fit: "contain"`;
- image crop rectangles;
- SVG image elements, using an internal transparent PNG fallback required by
  `moon-pptx`.

Schema-valid features outside this scope fail with a writer capability error
instead of being silently ignored. This includes `letter_spacing`, unsupported
icon names, unsupported connector kinds, line/connector shape presets, and
unsupported shape names.

## Example

The maintained example deck is in `examples/minimal`. It is intentionally small
but covers the features the writer can render today.

```bash
cd examples/minimal
moon runwasm Milky2018/pptz deck.pptz.yaml --out dist/demo.pptx
```

The YAML smoke fixture is in `examples/testdata`:

```bash
moon runwasm Milky2018/pptz examples/testdata/yaml-deck.pptz.yaml --out examples/testdata/out/yaml-demo.pptx
```

For local development against the checkout instead of the published wasm:

```bash
moon runwasm . examples/minimal/deck.pptz.yaml --out examples/minimal/dist/demo.pptx
```

## Validation

Run the wasm target checks before relying on a change:

```bash
moon check --target wasm
moon test --target wasm
```

See `REFERENCE.md` for the source schema, diagnostics, and CLI contract.
