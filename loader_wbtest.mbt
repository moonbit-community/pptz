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
}

///|
test "loader rejects invalid image crop" {
  let diagnostics = load_error_diagnostics(
    "examples/testdata/invalid-crop.pptz.toml",
  )
  assert_true(has_diagnostic_code(diagnostics, "PZ041"))
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
