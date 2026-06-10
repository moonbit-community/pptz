# Glossary

## Portable Agent skill

A reusable instruction package for any capable coding agent, not a Codex-only
workflow. It may include reference files, examples, scripts, and a portable
wasm command interface.

## pptz

PowerPoint Zero: the MoonBit-based presentation tool and document format used
by this skill. Agents consume it through `moon runwasm Milky2018/pptz` after the
package is published, or through the local top-level package during
development.

## Deck definition

The top-level `.pptz.toml` file that declares presentation metadata, theme
tokens, page order, and output settings.

## Page file

A `.page.toml` file that describes one slide using positioned elements,
backgrounds, text, shapes, images, icons, charts, or tables.

## Intentional warning

A warning emitted by `pptz` that the agent has inspected and can justify as a
deliberate design choice, rather than a format mistake or asset problem.
