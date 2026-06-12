///|
test "parse minimal deck toml" {
  let source = @miniio.read_text_file("examples/minimal/deck.pptz.toml") catch {
    err => abort("read deck failed: \{err}")
  }
  let deck = parse_deck_toml(source) catch {
    err => abort("parse deck failed: \{err}")
  }
  match deck.title {
    Some(title) => assert_eq(title, "MoonBit PPTX Demo")
    None => abort("expected title")
  }
  assert_eq(deck.size.width, 1280.0)
  assert_eq(deck.size.height, 720.0)
  assert_eq(deck.pages.length(), 4)
  assert_eq(deck.pages[0].path, "pages/cover.page.toml")
  match deck.theme {
    Some(theme) => {
      assert_eq(theme.colors["text"], "#F4F6FB")
      match theme.text_styles["title"].font_size {
        Some(size) => assert_eq(size, 56.0)
        None => abort("expected title font size")
      }
      match theme.text_styles["title"].bold {
        Some(value) => assert_true(value)
        None => abort("expected title bold")
      }
    }
    None => abort("expected theme")
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
    Some(kind) => assert_eq(kind, "cover")
    None => abort("expected page_type")
  }
  match page.background {
    Some(SolidBackground(color)) => assert_eq(color, "$background")
    _ => abort("expected solid background")
  }
  assert_eq(page.elements.length(), 3)
  match page.elements[0] {
    TextElement(base, content) => {
      assert_eq(base.id, "title")
      assert_eq(base.bounds.width, 1080.0)
      assert_true(content.text.contains("MoonBit PPTX Demo"))
      match content.style {
        Some(style) => assert_eq(style, "$title")
        None => abort("expected title style")
      }
    }
    _ => abort("expected text element")
  }
  match page.elements[2] {
    ImageElement(base, spec) => {
      assert_eq(base.id, "hero")
      assert_eq(spec.path, "images/hero.png")
      match spec.fit {
        StretchFit => ()
        _ => abort("expected stretch fit")
      }
    }
    _ => abort("expected image element")
  }
}

///|
test "parse decimal geometry" {
  let deck = parse_deck_toml(
    (
      #|size = [1280.5, 720.25]
      #|pages = [{ path = "pages/cover.page.toml" }]
    ),
  ) catch {
    err => abort("parse deck failed: \{err}")
  }
  assert_eq(deck.size.width, 1280.5)
  assert_eq(deck.size.height, 720.25)
  let page = parse_page_toml(
    (
      #|page_type = "content"
      #|
      #|[[elements]]
      #|id = "title"
      #|type = "text"
      #|bounds = [10.5, 20.25, 300.75, 80.5]
      #|
      #|[elements.content]
      #|text = "Hello"
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    TextElement(base, _) => {
      assert_eq(base.bounds.x, 10.5)
      assert_eq(base.bounds.y, 20.25)
      assert_eq(base.bounds.width, 300.75)
      assert_eq(base.bounds.height, 80.5)
    }
    _ => abort("expected text element")
  }
}

///|
test "parser rejects unknown fields" {
  let message = deck_parse_error(
    (
      #|size = [1280, 720]
      #|pages = [{ path = "pages/cover.page.toml" }]
      #|camelCase = true
    ),
  )
  assert_true(message.contains("unknown field"))
}

///|
test "parser rejects unknown element type" {
  let message = page_parse_error(
    (
      #|[[elements]]
      #|id = "mystery"
      #|type = "video"
      #|bounds = [0, 0, 100, 100]
    ),
  )
  assert_true(message.contains("unsupported element type"))
}

///|
test "image fit defaults to stretch" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "hero"
      #|type = "image"
      #|bounds = [0, 0, 640, 360]
      #|
      #|[elements.content]
      #|path = "images/hero.png"
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    ImageElement(_, spec) =>
      match spec.fit {
        StretchFit =>
          match spec.crop {
            None => ()
            Some(_) => abort("expected no crop")
          }
        _ => abort("expected stretch fit")
      }
    _ => abort("expected image element")
  }
}

///|
test "parse image crop" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "hero"
      #|type = "image"
      #|bounds = [0, 0, 640, 360]
      #|
      #|[elements.content]
      #|path = "images/hero.png"
      #|fit = "cover"
      #|
      #|[elements.content.crop]
      #|left = 0.1
      #|top = 0.2
      #|right = 0.3
      #|bottom = 0.4
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    ImageElement(_, spec) => {
      match spec.fit {
        CoverFit => ()
        _ => abort("expected cover fit")
      }
      match spec.crop {
        Some(crop) => {
          assert_eq(crop.left, 0.1)
          assert_eq(crop.top, 0.2)
          assert_eq(crop.right, 0.3)
          assert_eq(crop.bottom, 0.4)
        }
        None => abort("expected crop")
      }
    }
    _ => abort("expected image element")
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
    Some(kind) => assert_eq(kind, "content")
    None => abort("expected page_type")
  }
  assert_eq(page.elements.length(), 3)
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
  match page.elements[2] {
    ImageElement(base, spec) => {
      assert_eq(base.id, "diagram")
      assert_eq(spec.path, "images/diagram.png")
    }
    _ => abort("expected image element")
  }
}

///|
test "parse minimal shapes page" {
  let source = @miniio.read_text_file("examples/minimal/pages/shapes.page.toml") catch {
    err => abort("read page failed: \{err}")
  }
  let page = parse_page_toml(source) catch {
    err => abort("parse page failed: \{err}")
  }
  assert_eq(page.elements.length(), 6)
  match page.elements[1] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "panel")
      assert_eq(spec.shape, "rect")
    }
    _ => abort("expected shape element")
  }
  match page.elements[3] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "outline")
      match spec.fill {
        Some(NoFill) => ()
        _ => abort("expected no fill")
      }
    }
    _ => abort("expected outline element")
  }
}

///|
fn deck_parse_error(source : String) -> String {
  ignore(parse_deck_toml(source) catch { err => return "\{err}" })
  abort("expected parse failure")
}

///|
fn page_parse_error(source : String) -> String {
  ignore(parse_page_toml(source) catch { err => return "\{err}" })
  abort("expected parse failure")
}
