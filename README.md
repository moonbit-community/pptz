# Milky2018/pptz

`pptz` is PowerPoint Zero, a portable MoonBit presentation compiler. It reads
TOML deck and page sources, validates them, and generates PPTX output through a
wasm CLI.

```mbt
test "usage mentions commands" {
  assert_true(@pptz.usage().contains("check"))
  assert_true(@pptz.usage().contains("build"))
}
```
