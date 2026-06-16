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
      assert_eq(deck.layouts["content"].slots.length(), 3)
      assert_eq(deck.components["stat_card"].elements.length(), 3)
    }
    None => abort("expected theme")
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
