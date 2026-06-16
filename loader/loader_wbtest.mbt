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
test "load minimal deck resolves ordered pages" {
  let loaded = load_deck("examples/minimal/deck.pptz.toml") catch {
    LoadError::Fatal(message) => {
      println("load fatal: \{message}")
      abort("load failed")
    }
    err => {
      println("load failed: \{err}")
      abort("load failed")
    }
  }
  assert_eq(loaded.bundle.deck.size.width, 1280.0)
  assert_eq(loaded.bundle.pages.length(), 4)
  assert_eq(loaded.bundle.pages[0].path, "pages/cover.page.toml")
  assert_true(
    loaded.bundle.pages[0].full_path.has_suffix(
      "examples/minimal/pages/cover.page.toml",
    ),
  )
  match loaded.bundle.deck.theme {
    Some(theme) => {
      match theme.text_styles["link"].extends {
        None => ()
        Some(_) => abort("expected expanded text style")
      }
      match theme.text_styles["link"].font_size {
        Some(size) => assert_eq(size, 24.0)
        None => abort("expected inherited link font size")
      }
      match theme.table_styles["compact"].extends {
        None => ()
        Some(_) => abort("expected expanded table style")
      }
      match theme.table_styles["compact"].border {
        Some(border) => assert_eq(border.color, "$muted")
        None => abort("expected inherited table border")
      }
    }
    None => abort("expected theme")
  }
  match loaded.bundle.pages[1].page.layout {
    None => ()
    Some(_) => abort("expected expanded page layout")
  }
  match find_text_content(loaded.bundle.pages[1].page, "layout_heading") {
    Some(content) => assert_eq(content.text, "Agenda")
    None => abort("expected layout heading")
  }
  match find_text_content(loaded.bundle.pages[1].page, "revenue_card_value") {
    Some(content) => assert_eq(content.text, "150")
    None => abort("expected component value")
  }
  match find_chart_spec(loaded.bundle.pages[1].page, "revenue_chart") {
    Some(spec) => {
      match spec.chart_style {
        None => ()
        Some(_) => abort("expected expanded chart style")
      }
      assert_eq(spec.kind, "bar")
      match spec.legend {
        Some(legend) => assert_eq(legend, "bottom")
        None => abort("expected inherited chart legend")
      }
      match spec.data_labels {
        Some(pos) => assert_eq(pos, "outside_end")
        None => abort("expected inherited chart labels")
      }
    }
    None => abort("expected chart element")
  }
  assert_eq(loaded.warnings.length(), 0)
}

///|
test "loader rejects page paths outside deck directory" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/outside-page.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ010"))
}

///|
test "loader rejects decks without pages" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/no-pages.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ010"))
}

///|
test "loader returns non-blocking warnings" {
  let loaded = load_deck("examples/testdata/warnings.pptz.toml") catch {
    LoadError::Fatal(message) => {
      println("load fatal: \{message}")
      abort("load failed")
    }
    err => {
      println("load failed: \{err}")
      abort("load failed")
    }
  }
  assert_eq(loaded.bundle.pages.length(), 1)
  assert_true(has_diagnostic_code(loaded.warnings, "PZ100"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ101"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ102"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ103"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ105"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ106"))
  assert_true(has_diagnostic_code(loaded.warnings, "PZ107"))
}

///|
test "loader warns on low contrast table text" {
  let loaded = load_deck("examples/testdata/low-contrast-table.pptz.toml") catch {
    LoadError::Fatal(message) => {
      println("load fatal: \{message}")
      abort("load failed")
    }
    err => {
      println("load failed: \{err}")
      abort("load failed")
    }
  }
  assert_true(has_diagnostic_code(loaded.warnings, "PZ104"))
}

///|
test "loader rejects invalid image crop" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/invalid-crop.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ041"))
}

///|
test "loader rejects invalid table structure" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/invalid-table.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ060"))
}

///|
test "loader rejects invalid chart data" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/invalid-chart.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ070"))
}

///|
test "loader rejects style inheritance cycles" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/style-cycle.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ030"))
}

///|
fn load_error_diagnostics(path : String) -> Array[Diagnostic] {
  ignore(
    load_deck(path) catch {
      LoadError::Diagnostics(diagnostics) => return diagnostics
      LoadError::Fatal(message) => {
        println("expected diagnostics, got fatal: \{message}")
        abort("expected diagnostics")
      }
      err => {
        println("expected diagnostics, got: \{err}")
        abort("expected diagnostics")
      }
    },
  )
  abort("expected diagnostics")
}

///|
fn has_diagnostic_code(diagnostics : Array[Diagnostic], code : String) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      return true
    }
  }
  false
}

///|
fn find_chart_spec(page : Page, id : String) -> ChartSpec? {
  for element in page.elements {
    match element {
      ChartElement(base, spec) => if base.id == id { return Some(spec) }
      _ => ()
    }
  }
  None
}

///|
fn find_text_content(page : Page, id : String) -> TextContent? {
  for element in page.elements {
    match element {
      TextElement(base, content) => if base.id == id { return Some(content) }
      _ => ()
    }
  }
  None
}
