---
name: portable-pptz-skill
description: Creates PPTX decks from TOML pptz/page sources using the portable MoonBit wasm tool `Milky2018/pptz`. Use when an agent needs to design slides, write a pptz project, compile it to `.pptx`, and deliver both sources and output.
---

# Portable PPTX Skill

## Quick Start

Use `moon runwasm Milky2018/pptz` as the published presentation compiler. While
developing this repository, use the top-level package with `moon runwasm .`.

Expected project layout:

```text
deck-topic/
├── deck.pptz.toml
├── pages/
│   ├── cover.page.toml
│   └── agenda.page.toml
├── images/
│   └── background.svg
└── dist/
    └── deck.pptx
```

## Workflow

1. Clarify the deck goal, audience, language, duration, required slide count,
   and delivery constraints.
2. Design one reusable background image that fits the subject and can support
   text legibility across all slides.
3. Write `deck.pptz.toml` with title, canvas size, theme tokens, shared text
   styles, image paths, output path, and ordered page list.
4. Write every `pages/*.page.toml` file. Keep coordinates explicit and reuse
   theme tokens instead of hard-coded styles where possible.
5. Find or create required `images/` assets. Do not use low-quality,
   watermarked, license-unknown, or unreadable images.
6. Compile the project with `pptz`:

   ```bash
   moon runwasm Milky2018/pptz deck-topic --out deck-topic/dist/deck.pptx
   ```

7. Fix any `pptz` errors. Inspect every warning and either fix it or record why
   it is an intentional design choice.
8. Deliver both the `pptz` source directory and the generated `.pptx`.

## Quality Gate

- `pptz` exits successfully and writes the expected PPTX.
- Every warning is intentional and documented in the handoff.
- All page/image paths are relative to the deck directory.
- Text fits within its bounds and does not overlap important imagery.
- The common background works on cover, section, dense content, and closing
  slides.

## Important Notes

- The reference `selene-engine` layout uses a similar directory organization,
  but its sample files are YAML-like. This skill uses real TOML.
- `pptz` and page sources must be parseable by `bobzhang/toml@0.4.1`.
- File IO for the MoonBit tool should use `moonbit-community/miniio`.
- See [REFERENCE.md](REFERENCE.md) for the source schema and CLI contract.
- See [examples/minimal](examples/minimal) for a small TOML deck.
