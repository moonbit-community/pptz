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
  assert_eq(page.components.length(), 1)
  assert_eq(page.components[0].id, "revenue_card")
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
