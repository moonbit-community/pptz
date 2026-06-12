---
name: pptz
description: Creates PPTX decks from TOML pptz/page sources using the portable MoonBit wasm tool `Milky2018/pptz`. Use when an agent needs to design slides, write pptz TOML sources, compile them to `.pptx`, and deliver both sources and output.
---

# pptz Skill

## Quick Start

Use `moon runwasm Milky2018/pptz` as the published presentation compiler. Run
it from the deck project directory and pass relative paths for the deck, page,
image, and output files. While developing this repository, use the top-level
package with `moon runwasm .`.

Expected project layout:

```text
deck-topic/
├── deck.pptz.toml
├── pages/
│   ├── cover.page.toml
│   └── agenda.page.toml
├── images/
│   └── diagram.png
└── dist/
    └── deck.pptx
```

## Workflow

1. Clarify the deck goal, audience, language, duration, required slide count,
   and delivery constraints.
2. Design a reusable visual system that fits the subject and supports text
   legibility across all slides. Use a solid theme background when the current
   `pptz` writer does not support the desired image background behavior.
3. Write a `.pptz.toml` file with title, canvas size, theme tokens, shared text
   styles, image paths, and ordered page list.
4. Write every `pages/*.page.toml` file. Keep coordinates explicit and reuse
   theme tokens instead of hard-coded styles where possible. For decks that
   must compile with the current writer, use only the supported feature set
   below.
5. Find or create required `images/` assets. Do not use low-quality,
   watermarked, license-unknown, or unreadable images.
6. Compile the project with `pptz` from the deck directory:

   ```bash
   cd deck-topic
   moon runwasm Milky2018/pptz deck.pptz.toml --out dist/deck.pptx
   ```

7. Fix any `pptz` errors. Inspect every warning and either fix it or record why
   it is an intentional design choice.
8. Deliver both the `pptz` source directory and the generated `.pptx`.

## Quality Gate

- `pptz` exits successfully and writes the expected PPTX.
- Every warning is intentional and documented in the handoff.
- All page/image paths are relative to the deck directory.
- Text fits within its bounds and does not overlap important imagery.
- The common visual system works on cover, section, dense content, and closing
  slides.

## Current Supported Feature Set

Use these features for deliverable decks:

- explicit deck size and ordered page files;
- optional solid page backgrounds;
- text elements with theme text styles and local overrides;
- rectangle and ellipse shapes;
- solid fills, no-fill shapes, and solid borders;
- raster image elements with `fit = "stretch"`.

Do not use these in deliverable decks until `pptz` implements them in the
writer: gradient backgrounds or fills, image backgrounds, icon/table/chart
elements, image `cover` or `contain`, alpha colors, `line_height`,
`letter_spacing`, or shape names other than `rect` and `ellipse`.

## Important Notes

- The reference `selene-engine` layout uses a similar directory organization,
  but its sample files are YAML-like. This skill uses real TOML.
- `pptz` and page sources must be parseable by `bobzhang/toml@0.4.1`.
- File IO for the MoonBit tool should use `moonbit-community/miniio`.
- Published `moon runwasm` executes inside a WASI-style file sandbox. Prefer
  running from the deck directory with relative paths; absolute paths outside
  the current working tree may not be visible to the tool.
- See [REFERENCE.md](REFERENCE.md) for the source schema and CLI contract.
- See [examples/minimal](examples/minimal) for the maintained TOML deck that
  covers the currently supported writer features.
