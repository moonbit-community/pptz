# Technical Deck

Use for compiler, library, API, architecture, migration, and engineering plan
presentations.

## Slide Shapes

- Title: project name, one concrete claim, one visual motif from the domain.
- Problem: current limitation, failure mode, or workflow cost.
- Architecture: boxes and connectors; keep labels short and use theme tokens.
- API or schema: code-like text box plus adjacent callouts.
- Capability matrix: table with compact style; avoid dense prose.
- Flow: numbered process or pipeline with connectors.
- Tradeoffs: two-column comparison or decision table.
- Status/roadmap: current slice, next slice, explicit non-goals.

## pptz Patterns

- Use `shape` + `connector` for architecture diagrams instead of embedding
  screenshots of diagrams. Give each node its label through the shape's
  `content.text`.
- Use rich text runs only where emphasis or hyperlinks matter; keep code blocks
  as plain text boxes with monospaced `font_family`.
- Use tables for capability matrices and compatibility grids.
- Keep diagram and card labels short enough to render without splitting words;
  widen the shape bounds when the label is part of the concept name.
- Use chart shorthand only for real numeric evidence, not decorative charts.

## Avoid

- Raw backend or OpenXML names in slide copy.
- Full source files on a slide; show the relevant excerpt and label the point.
- More than one primary diagram per slide.
