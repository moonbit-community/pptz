# Align pptz schema with moon-pptx capabilities

`pptz v2` will use a thin semantic layer: YAML concepts remain `pptz` concepts,
but their capability boundaries intentionally track what `moon-pptx` can
generate. This keeps `pptz` expressive enough to expose the backend's PPTX
surface quickly while avoiding raw XML escape hatches or a mechanical
serialization of MoonBit backend types into YAML.
