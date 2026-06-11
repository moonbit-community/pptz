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
moon runwasm Milky2018/pptz@0.1.0 <deck.toml> [--out <output.pptx>]
```

Run the command from the deck project directory and use relative paths. The
published wasm runs with WASI-style file access, so absolute paths outside the
current working tree may not be visible.

While developing this repository, run the top-level package:

```bash
moon runwasm . examples/minimal/deck.pptz.toml --out examples/minimal/dist/demo.pptx
```

If `--out` is omitted, the output path defaults to `output.pptx`.

## Current Writer Scope

The current writer supports:

- explicit deck size and ordered page files;
- optional solid page backgrounds;
- text elements with theme text styles and local overrides;
- rectangle and ellipse shapes;
- solid fills, no-fill shapes, and solid borders;
- raster image elements with `fit = "stretch"`.

Schema-valid features outside this scope fail with a writer capability error
instead of being silently ignored. This includes gradient backgrounds/fills,
image backgrounds, icon/table/chart elements, image `cover`/`contain`, alpha
colors, `line_height`, `letter_spacing`, and shape names other than `rect` or
`ellipse`.

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
