# Do not expose raw OpenXML passthrough

`pptz v2` will not provide raw OpenXML or backend-passthrough escape hatches in
the TOML schema. Even though `moon-pptx` can preserve and model low-level OOXML,
`pptz` remains a validated TOML-to-PPTX semantic layer; exposing raw XML would
undermine loader validation, diagnostics, portability, and agent readability.
