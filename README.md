# Milky2018/pptz

`pptz` is PowerPoint Zero, a portable MoonBit presentation compiler. It reads a
pptz project, validates it as part of compilation, and generates PPTX output
through a wasm CLI.

```mbt
test "usage mentions commands" {
  assert_true(@pptz.usage().contains("pptz <project-dir>"))
  assert_true(@pptz.usage().contains("--out <output.pptx>"))
}
```
