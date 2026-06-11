///|
test "render minimal deck as pptx bytes" {
  let loaded = load_deck("examples/minimal/deck.pptz.toml") catch {
    err => abort("load failed: \{err}")
  }
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  let slides = prs.slides() catch {
    err => abort("read generated slides failed: \{err}")
  }
  assert_eq(slides.length(), 2)
  assert_true(slides[0].shapes.length() >= 2)
}
