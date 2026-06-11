# Milky2018/pptz

`pptz` is PowerPoint Zero, a portable MoonBit presentation compiler. It reads a
TOML deck file, validates it as part of compilation, and generates PPTX output
through a wasm CLI.

```mbt
test "usage mentions commands" {
  assert_true(@pptz.usage().contains("pptz <deck.pptz.toml>"))
  assert_true(@pptz.usage().contains("--out <output.pptx>"))
}
```
