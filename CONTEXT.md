# Glossary

## Portable Agent skill

A reusable instruction package for any capable coding agent, not a Codex-only
workflow. It may include reference files and examples around a portable wasm
command interface.
It uses `pptz` but does not define `pptz` semantics.

## pptz

PowerPoint Zero: the MoonBit-based presentation tool and document format used
by this skill. Agents consume it through `moon runwasm Milky2018/pptz` after the
package is published, or through the local top-level package during
development.
It converts a `pptz` project into a PPTX file and should not encode agent
workflow policy.

## Deck definition

The top-level `.pptz.toml` file that declares presentation metadata, theme
tokens, page order, and output settings.

## Deck bundle

A deck definition together with its resolved page files and deck directory,
used as the unit that can be checked or generated.

## Page file

A `.page.toml` file that describes one slide using positioned elements,
backgrounds, text, shapes, images, icons, charts, or tables.
The page background is optional.

## Page identity

The path used by a deck's page reference. Pages do not have a separate semantic
id.

## Checker

The validation stage that inspects a `pptz` AST and reports whether it is ready
for PPTX generation. It does not parse TOML, modify the AST, or write PPTX
output.

## Checker error

A checker diagnostic that means PPTX generation must not continue.

## Checker warning

A checker diagnostic that means PPTX generation may continue, but the agent must
inspect and explain the design choice or fix it.

## Intentional warning

A warning emitted by `pptz` that the agent has inspected and can justify as a
deliberate design choice, rather than a format mistake or asset problem.
