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
It converts an input TOML deck file into a PPTX file and should not encode
agent workflow policy.

## Compiler Reliability Slice

A development stage for making `pptz`'s documented compile contract dependable
before expanding the presentation features it can render.

## Deck definition

A TOML file, at any path, that declares presentation metadata, theme tokens,
and page order. Theme tokens are optional. The `.pptz.toml` extension is
recommended but not required.

## Deck bundle

A deck definition together with its resolved page files and the deck file's
directory, produced by the loader after validation and ready for PPTX
generation.

## Loaded deck

The successful loader result: a validated deck bundle plus any non-blocking
warnings that the caller should surface before or after PPTX generation.

## Loader diagnostic

A structured loader finding with a stable code and human-readable message.
Error diagnostics block PPTX generation; warning diagnostics do not.
Diagnostics include path, element id, and field context when available, but do
not include source locations.

## Resolved page

A page reference after the loader has associated it with the page file path and
parsed page AST. Repeated page references remain repeated resolved pages.

## Output path

The PPTX path chosen by the CLI. It defaults to `output.pptx`; relative output
paths are resolved from the current working directory, not from the deck file
directory.

## Atomic output

The `pptz` guarantee that a failed compilation does not replace an existing
PPTX at the output path with a partial or invalid file.

## CLI contract

The command-line behavior that agents depend on when invoking `pptz`, including
argument shape, output path reporting, diagnostic streams, and failure
categories.

## Documentation synchronization

The practice of keeping `pptz`'s Agent-facing documents aligned with the
features and guarantees that the current implementation actually provides.

## Current-capabilities example deck

The repository's single maintained example deck that exercises the presentation
features `pptz` can render today, used as a regression sample rather than as a
full showcase.

## Deck-relative source path

A path declared inside deck or page TOML and resolved relative to the deck
definition's directory. Page and asset references share this path model.

## Page file

A `.page.toml` file that describes one slide using positioned elements,
backgrounds, text, shapes, images, icons, charts, or tables.
The page background is optional.

## Page identity

The path used by a deck's page reference. Pages do not have a separate semantic
id.
