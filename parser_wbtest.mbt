// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
      match theme.text_styles["title"].extends {
        Some(value) => assert_eq(value, "$base")
        None => abort("expected title extends")
      }
      match theme.text_styles["link"].extends {
        Some(value) => assert_eq(value, "$body")
        None => abort("expected link extends")
      }
      match theme.table_styles["compact"].extends {
        Some(value) => assert_eq(value, "$table_base")
        None => abort("expected table extends")
      }
      match theme.table_styles["compact"].header_text_color {
        Some(color) => assert_eq(color, "$text")
        None => abort("expected header text color")
      }
      match theme.table_styles["compact"].body_text_color {
        Some(color) => assert_eq(color, "$text")
        None => abort("expected body text color")
      }
      match theme.chart_styles["report_bar"].kind {
        Some(kind) => assert_eq(kind, "bar")
        None => abort("expected chart style kind")
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
    Some(GradientBackground(gradient)) => {
      assert_eq(gradient.stops.length(), 2)
      match gradient.direction {
        Some(direction) => assert_eq(direction, 90.0)
        None => abort("expected gradient direction")
      }
    }
    _ => abort("expected gradient background")
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
test "parser rejects mixed table text color aliases" {
  let message = deck_parse_error(
    (
      #|size = [1280, 720]
      #|pages = [{ path = "pages/cover.page.toml" }]
      #|
      #|[theme.colors]
      #|text = "#111827"
      #|
      #|[theme.text_styles.body]
      #|color = "$text"
      #|
      #|[theme.table_styles.compact]
      #|header_text_color = "$text"
      #|header_color = "$text"
    ),
  )
  assert_true(message.contains("use either header_text_color or header_color"))
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
  match page.layout {
    Some(layout) => assert_eq(layout, "$content")
    None => abort("expected layout")
  }
  assert_eq(page.slots["heading"], "Agenda")
  assert_eq(page.elements.length(), 4)
  match page.elements[0] {
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
    TableElement(base, spec) => {
      assert_eq(base.id, "summary_table")
      assert_eq(spec.rows[0].cells[0].text, "Metrics")
    }
    _ => abort("expected table element")
  }
  match page.elements[1] {
    ImageElement(base, spec) => {
      assert_eq(base.id, "diagram")
      assert_eq(spec.path, "images/diagram.png")
    }
    _ => abort("expected image element")
  }
  match page.elements[3] {
    ChartElement(base, spec) => {
      assert_eq(base.id, "revenue_chart")
      assert_eq(spec.kind, "")
      match spec.chart_style {
        Some(style) => assert_eq(style, "$report_bar")
        None => abort("expected chart style")
      }
      match spec.title {
        Some(title) => assert_eq(title, "Revenue")
        None => abort("expected chart title")
      }
      assert_eq(spec.series[0].values[1], 150.0)
    }
    _ => abort("expected chart element")
  }
}

///|
test "parse rich text paragraphs and body options" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "copy"
      #|type = "text"
      #|bounds = [80, 120, 640, 240]
      #|
      #|[elements.content]
      #|style = "$body"
      #|align = ["left", "top"]
      #|wrap = true
      #|
      #|[elements.content.body]
      #|auto_fit = "shape"
      #|
      #|[elements.content.body.inset]
      #|left = 12
      #|right = 12
      #|top = 8
      #|bottom = 8
      #|
      #|[[elements.content.paragraphs]]
      #|text = "Overview"
      #|style = "$title"
      #|line_height = 1.15
      #|space_after = 6
      #|
      #|[elements.content.paragraphs.bullet]
      #|kind = "char"
      #|char = "-"
      #|
      #|[[elements.content.paragraphs]]
      #|space_before = 4
      #|
      #|[[elements.content.paragraphs.runs]]
      #|text = "Read "
      #|
      #|[[elements.content.paragraphs.runs]]
      #|text = "docs"
      #|color = "$accent"
      #|hyperlink = "https://example.com"
      #|tooltip = "Documentation"
    ),
  ) catch {
    err => abort("parse rich text failed: \{err}")
  }
  match page.elements[0] {
    TextElement(_, content) => {
      assert_eq(content.text, "Overview\nRead docs")
      match content.body {
        Some(body) =>
          match body.auto_fit {
            Some(value) => assert_eq(value, "shape")
            None => abort("expected auto_fit")
          }
        None => abort("expected body options")
      }
      match content.paragraphs {
        Some(paragraphs) => {
          assert_eq(paragraphs.length(), 2)
          match paragraphs[0].bullet {
            Some(bullet) => assert_eq(bullet.kind, "char")
            None => abort("expected bullet")
          }
          match paragraphs[1].runs {
            Some(runs) => {
              assert_eq(runs.length(), 2)
              match runs[1].hyperlink {
                Some(url) => assert_eq(url, "https://example.com")
                None => abort("expected hyperlink")
              }
            }
            None => abort("expected runs")
          }
        }
        None => abort("expected paragraphs")
      }
    }
    _ => abort("expected text element")
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
  assert_eq(page.elements.length(), 9)
  match page.elements[1] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "panel")
      assert_eq(spec.shape, "round_rect")
      match spec.shadow {
        Some(shadow) => assert_eq(shadow.blur, 14.0)
        None => abort("expected panel shadow")
      }
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
  match page.elements[4] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "diamond")
      assert_eq(spec.shape, "diamond")
    }
    _ => abort("expected diamond element")
  }
  match page.elements[5] {
    ConnectorElement(id, spec) => {
      assert_eq(id, "flow")
      assert_eq(spec.kind, "straight")
      match spec.start {
        ElementEndpoint(target) => assert_eq(target, "panel")
        _ => abort("expected element start endpoint")
      }
      match spec.end_arrow {
        Some(arrow) => assert_eq(arrow, "triangle")
        None => abort("expected end arrow")
      }
      match spec.shadow {
        Some(shadow) => assert_eq(shadow.distance, 3.0)
        None => abort("expected connector shadow")
      }
    }
    _ => abort("expected connector element")
  }
  match page.elements[6] {
    IconElement(base, spec) => {
      assert_eq(base.id, "cube_icon")
      assert_eq(spec.name, "fas:cube")
    }
    _ => abort("expected icon element")
  }
}

///|
test "parse table content rows and data shorthand" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "summary"
      #|type = "table"
      #|bounds = [80, 120, 720, 300]
      #|
      #|[elements.content]
      #|style = "$compact"
      #|col_widths = [240, 240]
      #|row_heights = [48, 48]
      #|rows = [
      #|  { cells = [
      #|    { text = "Metric", fill = { type = "solid", color = "$surface" }, border = { style = "solid", width = 1, color = "$text" }, align = ["center", "center"], margin = { left = 4, right = 4 } },
      #|    "Q1",
      #|  ] },
      #|  { cells = ["Revenue", "100"] },
      #|]
    ),
  ) catch {
    err => abort("parse table page failed: \{err}")
  }
  match page.elements[0] {
    TableElement(base, spec) => {
      assert_eq(base.id, "summary")
      match spec.style {
        Some(style) => assert_eq(style, "$compact")
        None => abort("expected table style")
      }
      assert_eq(spec.rows.length(), 2)
      assert_eq(spec.rows[0].cells[0].text, "Metric")
      match spec.rows[0].cells[0].fill {
        Some(SolidFill(color)) => assert_eq(color, "$surface")
        _ => abort("expected cell fill")
      }
      match spec.rows[0].cells[0].margin {
        Some(margin) =>
          match margin.left {
            Some(left) => assert_eq(left, 4.0)
            None => abort("expected left margin")
          }
        None => abort("expected margin")
      }
    }
    _ => abort("expected table element")
  }
  let shorthand = parse_page_toml(
    (
      #|[[elements]]
      #|id = "shorthand"
      #|type = "table"
      #|bounds = [0, 0, 300, 120]
      #|
      #|[elements.content]
      #|data = [
      #|  ["Metric", "Q1"],
      #|  ["Revenue", "100"],
      #|]
    ),
  ) catch {
    err => abort("parse shorthand table failed: \{err}")
  }
  match shorthand.elements[0] {
    TableElement(_, spec) => assert_eq(spec.rows[1].cells[0].text, "Revenue")
    _ => abort("expected shorthand table element")
  }
}

///|
test "parse chart data shorthand" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "chart"
      #|type = "chart"
      #|bounds = [80, 120, 720, 360]
      #|
      #|[elements.content]
      #|kind = "line"
      #|data = [
      #|  ["", "Q1", "Q2", "Q3"],
      #|  ["Revenue", 100, 200, 150],
      #|  ["Users", 10.0, 24.0, 32.0],
      #|]
    ),
  ) catch {
    err => abort("parse chart shorthand failed: \{err}")
  }
  match page.elements[0] {
    ChartElement(_, spec) => {
      match spec.categories {
        Some(categories) => assert_eq(categories[2], "Q3")
        None => abort("expected categories")
      }
      assert_eq(spec.series.length(), 2)
      assert_eq(spec.series[1].name, "Users")
      assert_eq(spec.series[0].values[1], 200.0)
    }
    _ => abort("expected chart element")
  }
}

///|
test "parse chart content" {
  let page = parse_page_toml(
    (
      #|[[elements]]
      #|id = "revenue_chart"
      #|type = "chart"
      #|bounds = [80, 120, 720, 360]
      #|
      #|[elements.content]
      #|kind = "bar"
      #|title = "Quarterly revenue"
      #|legend = "bottom"
      #|style = 5
      #|data_labels = "outside_end"
      #|data_table = true
      #|rounded_corners = false
      #|categories = ["Q1", "Q2", "Q3"]
      #|
      #|[[elements.content.series]]
      #|name = "Revenue"
      #|values = [100.0, 200.0, 150.0]
    ),
  ) catch {
    err => abort("parse chart page failed: \{err}")
  }
  match page.elements[0] {
    ChartElement(base, spec) => {
      assert_eq(base.id, "revenue_chart")
      assert_eq(spec.kind, "bar")
      match spec.categories {
        Some(categories) => assert_eq(categories[1], "Q2")
        None => abort("expected categories")
      }
      match spec.title {
        Some(title) => assert_eq(title, "Quarterly revenue")
        None => abort("expected title")
      }
      match spec.legend {
        Some(legend) => assert_eq(legend, "bottom")
        None => abort("expected legend")
      }
      match spec.style {
        Some(style) => assert_eq(style, 5)
        None => abort("expected style")
      }
      match spec.data_labels {
        Some(pos) => assert_eq(pos, "outside_end")
        None => abort("expected data labels")
      }
      match spec.data_table {
        Some(show) => assert_true(show)
        None => abort("expected data table")
      }
      match spec.rounded_corners {
        Some(value) => assert_false(value)
        None => abort("expected rounded corners")
      }
      assert_eq(spec.series[0].name, "Revenue")
      assert_eq(spec.series[0].values[2], 150.0)
    }
    _ => abort("expected chart element")
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
