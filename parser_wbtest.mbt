///|
test "parse minimal deck toml" {
  let source = @miniio.read_text_file("examples/minimal/deck.pptz.toml") catch {
    err => abort("read deck failed: \{err}")
  }
  let deck = parse_deck_toml(source) catch {
    err => abort("parse deck failed: \{err}")
  }
  assert_eq(deck.title, "MoonBit PPTX Demo")
  assert_eq(deck.size.width, 1280)
  assert_eq(deck.size.height, 720)
  assert_eq(deck.pages.length(), 2)
  assert_eq(deck.pages[0].path, "pages/cover.page.toml")
  assert_eq(deck.theme.colors["text"], "#F4F6FB")
  match deck.theme.text_styles["title"].font_size {
    Some(size) => assert_eq(size, 56)
    None => abort("expected title font size")
  }
  match deck.output {
    Some(output) => assert_eq(output.path, "dist/moonbit-pptz-demo.pptx")
    None => abort("expected output")
  }
}

///|
test "parse minimal cover page toml" {
  let source = @miniio.read_text_file("examples/minimal/pages/cover.page.toml") catch {
    err => abort("read page failed: \{err}")
  }
  let page = parse_page_toml(source) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.page_type {
    Cover => ()
    _ => abort("expected cover page")
  }
  match page.background {
    Some(ImageBackground(fill)) => {
      assert_eq(fill.path, "../images/background.svg")
      match fill.fit {
        CoverFit => ()
        _ => abort("expected cover fit")
      }
    }
    _ => abort("expected image background")
  }
  assert_eq(page.elements.length(), 2)
  match page.elements[0] {
    TextElement(base, content) => {
      assert_eq(base.id, "title")
      assert_eq(base.bounds.width, 1080)
      assert_true(content.text.contains("MoonBit PPTX Demo"))
      match content.style {
        Some(style) => assert_eq(style, "$title")
        None => abort("expected title style")
      }
    }
    _ => abort("expected text element")
  }
}

///|
test "parse minimal agenda page multiline text" {
  let source = @miniio.read_text_file("examples/minimal/pages/agenda.page.toml") catch {
    err => abort("read page failed: \{err}")
  }
  let page = parse_page_toml(source) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.page_type {
    Content => ()
    _ => abort("expected content page")
  }
  assert_eq(page.elements.length(), 2)
  match page.elements[1] {
    TextElement(base, content) => {
      assert_eq(base.id, "items")
      assert_true(content.text.contains("Theme and background"))
      match content.style {
        Some(style) => assert_eq(style, "$body")
        None => abort("expected body style")
      }
    }
    _ => abort("expected text element")
  }
}
