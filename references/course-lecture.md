# Course Lecture

Use for tutorials, lectures, workshops, and teaching decks.

## Slide Shapes

- Objective: what learners can do after this section.
- Concept: definition plus one diagram or example.
- Worked example: input, transformation, output.
- Contrast: similar concepts side by side.
- Step-by-step: numbered process with one action per step.
- Exercise: task, constraints, expected outcome.
- Recap: key takeaways and next concept.

## pptz Patterns

- Use rich text bullets for teaching sequences; do not encode bullets inside a
  multiline plain `text` string.
- Use tables for syntax or concept comparisons.
- Use connectors for data flow or evaluation flow.
- Use components for repeated labeled chips/cards. Put each node's background
  shape and label in the same component or in matching bounds.
- Use images only when they clarify the concept being taught.

### Safe Diagram Nodes

For learning maps, pipelines, and contrast diagrams, avoid a row of empty shapes
plus one shared text box. Make each node independently labeled:

```yaml
components:
  lesson_chip:
    bounds: [0, 0, 210, 78]
    elements:
      - id: "bg"
        type: "shape"
        bounds: [0, 0, 210, 78]
        content:
          shape: "round_rect"
      - id: "label"
        type: "text"
        bounds: [12, 16, 186, 42]
        content:
          style: "$body"
          align: ["center", "center"]
          text: "$label"
```

```yaml
components:
  - id: "syntax_chip"
    use: "$lesson_chip"
    bounds: [115, 170, 210, 78]
    props:
      label: "语言核心"
```

## Avoid

- Dense paragraphs that should be speaker notes or handout text.
- Too many new terms on one slide.
- Exercises without an explicit expected outcome.
- Text that uses repeated spaces to line up labels over cards or columns.
- Empty colored shapes that are meant to represent concepts, steps, or states.
