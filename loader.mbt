// Copyright 2026 moonbit-community
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
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  path : String?
  element_id : String?
  field : String?
} derive(Eq, Debug)

///|
pub(all) suberror LoadError {
  Fatal(String)
  Diagnostics(Array[Diagnostic])
} derive(Debug)

///|
pub(all) struct LoadedDeck {
  bundle : DeckBundle
  warnings : Array[Diagnostic]
} derive(Eq, Debug)

///|
pub(all) struct DeckBundle {
  deck_path : String
  deck_dir : String
  deck : Deck
  pages : Array[ResolvedPage]
} derive(Eq, Debug)

///|
pub(all) struct ResolvedPage {
  path : String
  full_path : String
  page : Page
} derive(Eq, Debug)

///|
pub fn load_deck(input_path : String) -> LoadedDeck raise {
  let deck_path = normal_path(input_path)
  let deck_path_text = deck_path.to_string()
  if !(@miniio.is_file(deck_path_text) catch {
      err =>
        raise LoadError::Fatal("cannot stat deck file '\{input_path}': \{err}")
    }) {
    raise LoadError::Fatal("deck input is not a file: \{input_path}")
  }
  let source = @miniio.read_text_file(deck_path_text) catch {
    err =>
      raise LoadError::Fatal("cannot read deck file '\{input_path}': \{err}")
  }
  let deck = parse_deck_toml(source) catch {
    err =>
      raise LoadError::Fatal("cannot parse deck file '\{input_path}': \{err}")
  }
  let deck_dir = deck_path.dirname()
  let deck_dir_text = deck_dir.to_string()
  let errors = []
  let pages = load_pages(deck_dir, deck, errors)
  if errors.length() > 0 {
    raise LoadError::Diagnostics(errors)
  }
  let bundle = DeckBundle::{
    deck_path: deck_path_text,
    deck_dir: deck_dir_text,
    deck,
    pages,
  }
  let warnings = []
  let validation_errors = []
  validate_bundle(bundle, validation_errors, warnings)
  if validation_errors.length() > 0 {
    raise LoadError::Diagnostics(validation_errors)
  }
  LoadedDeck::{ bundle, warnings }
}

///|
fn load_pages(
  deck_dir : @path.Path,
  deck : Deck,
  errors : Array[Diagnostic],
) -> Array[ResolvedPage] raise {
  let parsed_pages = Map([], capacity=deck.pages.length())
  let resolved_pages = []
  for page_ref in deck.pages {
    match resolve_source_path(deck_dir, page_ref.path) {
      Some(full_path) => {
        let full_path_text = full_path.to_string()
        match parsed_pages.get(full_path_text) {
          Some(page) =>
            resolved_pages.push(ResolvedPage::{
              path: page_ref.path,
              full_path: full_path_text,
              page,
            })
          None =>
            if !(@miniio.is_file(full_path_text) catch { _ => false }) {
              errors.push(
                error_diagnostic(
                  "PZ010",
                  "page reference does not resolve to a file",
                  path=page_ref.path,
                  field="pages.path",
                ),
              )
            } else {
              let source = @miniio.read_text_file(full_path_text) catch {
                err =>
                  raise LoadError::Fatal(
                    "cannot read page file '\{page_ref.path}': \{err}",
                  )
              }
              let page = parse_page_toml(source) catch {
                err =>
                  raise LoadError::Fatal(
                    "cannot parse page file '\{page_ref.path}': \{err}",
                  )
              }
              parsed_pages[full_path_text] = page
              resolved_pages.push(ResolvedPage::{
                path: page_ref.path,
                full_path: full_path_text,
                page,
              })
            }
        }
      }
      None =>
        errors.push(
          error_diagnostic(
            "PZ010",
            "page path must be relative and stay inside the deck directory",
            path=page_ref.path,
            field="pages.path",
          ),
        )
    }
  }
  resolved_pages
}

///|
fn validate_bundle(
  bundle : DeckBundle,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  validate_deck_definition(bundle, errors)
  validate_theme(bundle.deck, bundle.deck_path, errors)
  validate_pages(bundle, errors, warnings)
}

///|
fn validate_deck_definition(
  bundle : DeckBundle,
  errors : Array[Diagnostic],
) -> Unit {
  if bundle.deck.size.width <= 0.0 || bundle.deck.size.height <= 0.0 {
    errors.push(
      error_diagnostic(
        "PZ001",
        "deck size must be positive",
        path=bundle.deck_path,
        field="size",
      ),
    )
  }
  if bundle.deck.pages.length() == 0 {
    errors.push(
      error_diagnostic(
        "PZ010",
        "deck must reference at least one page",
        path=bundle.deck_path,
        field="pages",
      ),
    )
  }
}

///|
fn validate_pages(
  bundle : DeckBundle,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  for resolved_page in bundle.pages {
    validate_page(bundle, resolved_page, errors, warnings)
  }
}

///|
fn validate_theme(
  deck : Deck,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  match deck.theme {
    None => ()
    Some(theme) => {
      for name, value in theme.colors {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme color token name is invalid",
              path=deck_path,
              field="theme.colors.\{name}",
            ),
          )
        }
        validate_color_value(
          value,
          theme,
          deck_path,
          None,
          "theme.colors.\{name}",
          errors,
        )
      }
      for name, style in theme.text_styles {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme text style token name is invalid",
              path=deck_path,
              field="theme.text_styles.\{name}",
            ),
          )
        }
        match style.color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.text_styles.\{name}.color",
              errors,
            )
        }
      }
    }
  }
}

///|
fn validate_page(
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  match resolved_page.page.background {
    None => ()
    Some(background) =>
      validate_background(bundle, resolved_page.path, background, errors)
  }
  let ids = Map([], capacity=resolved_page.page.elements.length())
  for element in resolved_page.page.elements {
    let id = element_id(element)
    if !is_identifier(id) {
      errors.push(
        error_diagnostic(
          "PZ021",
          "element id is invalid",
          path=resolved_page.path,
          element_id=id,
          field="elements.id",
        ),
      )
    }
    if ids.contains(id) {
      errors.push(
        error_diagnostic(
          "PZ020",
          "duplicate element id",
          path=resolved_page.path,
          element_id=id,
          field="elements.id",
        ),
      )
    } else {
      ids[id] = true
    }
    match element_base(element) {
      None => ()
      Some(base) =>
        validate_bounds(bundle, resolved_page.path, base, errors, warnings)
    }
  }
  for element in resolved_page.page.elements {
    validate_element(bundle, resolved_page.path, element, errors, warnings)
    validate_connector_refs(
      resolved_page.path,
      element,
      ids,
      errors,
      warnings,
      bundle,
    )
  }
}

///|
fn validate_background(
  bundle : DeckBundle,
  page_path : String,
  background : Background,
  errors : Array[Diagnostic],
) -> Unit {
  match background {
    SolidBackground(color) =>
      validate_page_color(
        bundle,
        page_path,
        None,
        "background.color",
        color,
        errors,
      )
    GradientBackground(gradient) =>
      validate_gradient(bundle, page_path, None, "background", gradient, errors)
    ImageBackground(fill) => {
      validate_asset_path(
        bundle,
        page_path,
        None,
        "background.path",
        fill.path,
        errors,
      )
      validate_image_fit_source_size(
        bundle,
        page_path,
        None,
        "background.path",
        "background.fit",
        fill.path,
        fill.fit,
        errors,
      )
    }
  }
}

///|
fn validate_element(
  bundle : DeckBundle,
  page_path : String,
  element : Element,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  match element {
    TextElement(base, content) => {
      if content.text.trim().is_empty() {
        warnings.push(
          warning_diagnostic(
            "PZ102",
            "text is empty or whitespace-only",
            path=page_path,
            element_id=base.id,
            field="elements.content.text",
          ),
        )
      }
      validate_text_fit(bundle, page_path, base, content, warnings)
      validate_text_style_ref(bundle, page_path, base.id, content.style, errors)
      match content.color {
        None => ()
        Some(color) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.color",
            color,
            errors,
          )
      }
    }
    ShapeElement(base, spec) => {
      match spec.fill {
        None | Some(NoFill) => ()
        Some(SolidFill(color)) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill.color",
            color,
            errors,
          )
        Some(GradientFill(gradient)) =>
          validate_gradient(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill",
            gradient,
            errors,
          )
      }
      match spec.border {
        None => ()
        Some(border) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.border.color",
            border.color,
            errors,
          )
      }
      validate_shadow(bundle, page_path, base.id, spec.shadow, errors)
    }
    ImageElement(base, spec) => {
      validate_asset_path(
        bundle,
        page_path,
        Some(base.id),
        "elements.content.path",
        spec.path,
        errors,
      )
      validate_image_crop(page_path, base.id, spec.crop, errors)
      validate_image_source_size(bundle, page_path, base.id, spec, errors)
    }
    IconElement(base, spec) => {
      if spec.name.is_blank() {
        errors.push(
          error_diagnostic(
            "PZ040",
            "icon name must not be empty",
            path=page_path,
            element_id=base.id,
            field="elements.content.name",
          ),
        )
      }
      match spec.fill {
        None | Some(NoFill) => ()
        Some(SolidFill(color)) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill.color",
            color,
            errors,
          )
        Some(GradientFill(gradient)) =>
          validate_gradient(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill",
            gradient,
            errors,
          )
      }
    }
    ConnectorElement(id, spec) => {
      match spec.stroke {
        None => ()
        Some(stroke) =>
          validate_page_color(
            bundle,
            page_path,
            Some(id),
            "elements.content.stroke.color",
            stroke.color,
            errors,
          )
      }
      validate_shadow(bundle, page_path, id, spec.shadow, errors)
    }
    TableElement(base, spec) =>
      validate_table(bundle, page_path, base, spec, errors)
    ChartElement(base, spec) => validate_chart(page_path, base, spec, errors)
  }
}

///|
fn validate_chart(
  page_path : String,
  base : ElementBase,
  spec : ChartSpec,
  errors : Array[Diagnostic],
) -> Unit {
  if !chart_kind_supported(spec.kind) {
    errors.push(
      error_diagnostic(
        "PZ070",
        "unsupported chart kind",
        path=page_path,
        element_id=base.id,
        field="elements.content.kind",
      ),
    )
  }
  validate_chart_options(page_path, base.id, spec, errors)
  if spec.series.is_empty() {
    errors.push(
      error_diagnostic(
        "PZ070",
        "chart must have at least one series",
        path=page_path,
        element_id=base.id,
        field="elements.content.series",
      ),
    )
  }
  if chart_kind_uses_categories(spec.kind) {
    match spec.categories {
      None =>
        errors.push(
          error_diagnostic(
            "PZ070",
            "chart categories are required for this chart kind",
            path=page_path,
            element_id=base.id,
            field="elements.content.categories",
          ),
        )
      Some(categories) => {
        if categories.is_empty() {
          errors.push(
            error_diagnostic(
              "PZ070",
              "chart categories must not be empty",
              path=page_path,
              element_id=base.id,
              field="elements.content.categories",
            ),
          )
        }
        for index, series in spec.series {
          validate_chart_series_common(
            page_path,
            base.id,
            index,
            series,
            errors,
          )
          validate_chart_length(
            page_path,
            base.id,
            "elements.content.series[\{index}].values",
            series.values.length(),
            categories.length(),
            errors,
          )
        }
      }
    }
  } else {
    if spec.categories is Some(_) {
      errors.push(
        error_diagnostic(
          "PZ070",
          "scatter and bubble charts do not use categories",
          path=page_path,
          element_id=base.id,
          field="elements.content.categories",
        ),
      )
    }
    for index, series in spec.series {
      validate_chart_series_common(page_path, base.id, index, series, errors)
      validate_required_chart_array(
        page_path,
        base.id,
        "elements.content.series[\{index}].x_values",
        series.x_values,
        series.values.length(),
        errors,
      )
      if spec.kind == "bubble" {
        validate_required_chart_array(
          page_path,
          base.id,
          "elements.content.series[\{index}].bubble_sizes",
          series.bubble_sizes,
          series.values.length(),
          errors,
        )
      }
    }
  }
}

///|
fn validate_chart_options(
  page_path : String,
  element_id : String,
  spec : ChartSpec,
  errors : Array[Diagnostic],
) -> Unit {
  match spec.title {
    None => ()
    Some(title) =>
      if title.is_blank() {
        errors.push(
          error_diagnostic(
            "PZ070",
            "chart title must not be empty",
            path=page_path,
            element_id~,
            field="elements.content.title",
          ),
        )
      }
  }
  match spec.legend {
    None => ()
    Some(legend) =>
      if !chart_legend_supported(legend) {
        errors.push(
          error_diagnostic(
            "PZ070",
            "unsupported chart legend",
            path=page_path,
            element_id~,
            field="elements.content.legend",
          ),
        )
      }
  }
  match spec.style {
    None => ()
    Some(style) =>
      if style < 1 || style > 48 {
        errors.push(
          error_diagnostic(
            "PZ070",
            "chart style must be between 1 and 48",
            path=page_path,
            element_id~,
            field="elements.content.style",
          ),
        )
      }
  }
  match spec.data_labels {
    None => ()
    Some(pos) =>
      if !chart_data_label_supported(pos) {
        errors.push(
          error_diagnostic(
            "PZ070",
            "unsupported chart data_labels position",
            path=page_path,
            element_id~,
            field="elements.content.data_labels",
          ),
        )
      }
  }
}

///|
fn chart_legend_supported(value : String) -> Bool {
  match value {
    "hidden" | "bottom" | "top_right" | "left" | "right" | "top" => true
    _ => false
  }
}

///|
fn chart_data_label_supported(value : String) -> Bool {
  match value {
    "hidden"
    | "best_fit"
    | "bottom"
    | "center"
    | "inside_base"
    | "inside_end"
    | "left"
    | "outside_end"
    | "right"
    | "top" => true
    _ => false
  }
}

///|
fn chart_kind_supported(kind : String) -> Bool {
  match kind {
    "bar"
    | "line"
    | "pie"
    | "doughnut"
    | "area"
    | "scatter"
    | "bubble"
    | "radar" => true
    _ => false
  }
}

///|
fn chart_kind_uses_categories(kind : String) -> Bool {
  match kind {
    "scatter" | "bubble" => false
    _ => true
  }
}

///|
fn validate_chart_series_common(
  page_path : String,
  element_id : String,
  index : Int,
  series : ChartSeriesSpec,
  errors : Array[Diagnostic],
) -> Unit {
  if series.name.is_blank() {
    errors.push(
      error_diagnostic(
        "PZ070",
        "chart series name must not be empty",
        path=page_path,
        element_id~,
        field="elements.content.series[\{index}].name",
      ),
    )
  }
  if series.values.is_empty() {
    errors.push(
      error_diagnostic(
        "PZ070",
        "chart series values must not be empty",
        path=page_path,
        element_id~,
        field="elements.content.series[\{index}].values",
      ),
    )
  }
}

///|
fn validate_required_chart_array(
  page_path : String,
  element_id : String,
  field : String,
  values : Array[Double]?,
  expected_length : Int,
  errors : Array[Diagnostic],
) -> Unit {
  match values {
    None =>
      errors.push(
        error_diagnostic(
          "PZ070",
          "chart series array is required for this chart kind",
          path=page_path,
          element_id~,
          field~,
        ),
      )
    Some(values) =>
      validate_chart_length(
        page_path,
        element_id,
        field,
        values.length(),
        expected_length,
        errors,
      )
  }
}

///|
fn validate_chart_length(
  page_path : String,
  element_id : String,
  field : String,
  actual : Int,
  expected : Int,
  errors : Array[Diagnostic],
) -> Unit {
  if actual != expected {
    errors.push(
      error_diagnostic(
        "PZ070",
        "chart data arrays must have matching lengths",
        path=page_path,
        element_id~,
        field~,
      ),
    )
  }
}

///|
fn validate_table(
  bundle : DeckBundle,
  page_path : String,
  base : ElementBase,
  spec : TableSpec,
  errors : Array[Diagnostic],
) -> Unit {
  if spec.rows.is_empty() {
    errors.push(
      error_diagnostic(
        "PZ060",
        "table must have at least one row",
        path=page_path,
        element_id=base.id,
        field="elements.content.rows",
      ),
    )
    return
  }
  for row_index, row in spec.rows {
    for cell_index, cell in row.cells {
      validate_table_cell(
        bundle,
        page_path,
        base.id,
        row_index,
        cell_index,
        cell,
        spec.rows.length(),
        errors,
      )
    }
  }
  let expected_columns = validate_table_grid(page_path, base.id, spec, errors)
  validate_table_sizes(
    page_path,
    base.id,
    "elements.content.col_widths",
    spec.col_widths,
    expected_columns,
    errors,
  )
  validate_table_sizes(
    page_path,
    base.id,
    "elements.content.row_heights",
    spec.row_heights,
    spec.rows.length(),
    errors,
  )
}

///|
fn validate_table_grid(
  page_path : String,
  element_id : String,
  spec : TableSpec,
  errors : Array[Diagnostic],
) -> Int {
  let mut expected_columns = match spec.col_widths {
    Some(widths) => widths.length()
    None => 0
  }
  let mut active_counts = zero_int_array(expected_columns)
  let mut active_horizontal = false_bool_array(expected_columns)
  for row_index, row in spec.rows {
    if expected_columns == 0 {
      expected_columns = table_row_span_sum(row)
      active_counts = zero_int_array(expected_columns)
      active_horizontal = false_bool_array(expected_columns)
    }
    let occupied = false_bool_array(expected_columns)
    let next_counts = zero_int_array(expected_columns)
    let next_horizontal = false_bool_array(expected_columns)
    for column in 0..<expected_columns {
      if active_counts[column] > 0 {
        occupied[column] = true
        next_counts[column] = active_counts[column] - 1
        next_horizontal[column] = active_counts[column] > 1 &&
          active_horizontal[column]
      }
    }
    let mut column = 0
    for cell_index, cell in row.cells {
      while column < expected_columns && occupied[column] {
        column += 1
      }
      if column >= expected_columns || column + cell.col_span > expected_columns {
        errors.push(
          error_diagnostic(
            "PZ060",
            "table row exceeds the table column span",
            path=page_path,
            element_id~,
            field="elements.content.rows[\{row_index}].cells[\{cell_index}]",
          ),
        )
        continue
      }
      let mut conflict = false
      for offset in 0..<cell.col_span {
        if occupied[column + offset] {
          conflict = true
        }
      }
      if conflict {
        errors.push(
          error_diagnostic(
            "PZ060",
            "table cell merge overlaps another cell",
            path=page_path,
            element_id~,
            field="elements.content.rows[\{row_index}].cells[\{cell_index}]",
          ),
        )
      } else {
        for offset in 0..<cell.col_span {
          occupied[column + offset] = true
          if cell.row_span > 1 {
            next_counts[column + offset] = cell.row_span - 1
            next_horizontal[column + offset] = offset > 0
          }
        }
      }
      column += cell.col_span
    }
    if !row_complete(occupied) {
      errors.push(
        error_diagnostic(
          "PZ060",
          "table rows must fill the same column span after merges",
          path=page_path,
          element_id~,
          field="elements.content.rows[\{row_index}].cells",
        ),
      )
    }
    if row.cells.is_empty() && !row_complete(occupied) {
      errors.push(
        error_diagnostic(
          "PZ060",
          "table row must have at least one cell unless it is covered by row spans",
          path=page_path,
          element_id~,
          field="elements.content.rows[\{row_index}].cells",
        ),
      )
    }
    active_counts = next_counts
    active_horizontal = next_horizontal
  }
  expected_columns
}

///|
fn table_row_span_sum(row : TableRowSpec) -> Int {
  let mut columns = 0
  for cell in row.cells {
    if cell.col_span > 0 {
      columns += cell.col_span
    }
  }
  columns
}

///|
fn row_complete(occupied : Array[Bool]) -> Bool {
  if occupied.is_empty() {
    return false
  }
  for item in occupied {
    if !item {
      return false
    }
  }
  true
}

///|
fn validate_table_cell(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  row_index : Int,
  cell_index : Int,
  cell : TableCellSpec,
  row_count : Int,
  errors : Array[Diagnostic],
) -> Unit {
  let field = "elements.content.rows[\{row_index}].cells[\{cell_index}]"
  if cell.col_span < 1 {
    errors.push(
      error_diagnostic(
        "PZ060",
        "table cell col_span must be greater than zero",
        path=page_path,
        element_id~,
        field="\{field}.col_span",
      ),
    )
  }
  if cell.row_span < 1 {
    errors.push(
      error_diagnostic(
        "PZ060",
        "table cell row_span must be greater than zero",
        path=page_path,
        element_id~,
        field="\{field}.row_span",
      ),
    )
  } else if row_index + cell.row_span > row_count {
    errors.push(
      error_diagnostic(
        "PZ060",
        "table cell row_span extends beyond the table",
        path=page_path,
        element_id~,
        field="\{field}.row_span",
      ),
    )
  }
  validate_table_cell_fill(
    bundle,
    page_path,
    element_id,
    "\{field}.fill",
    cell.fill,
    errors,
  )
  match cell.border {
    None => ()
    Some(border) =>
      validate_page_color(
        bundle,
        page_path,
        Some(element_id),
        "\{field}.border.color",
        border.color,
        errors,
      )
  }
  validate_table_cell_margin(page_path, element_id, field, cell.margin, errors)
}

///|
fn validate_table_cell_fill(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  field : String,
  fill : Fill?,
  errors : Array[Diagnostic],
) -> Unit {
  match fill {
    None | Some(NoFill) => ()
    Some(SolidFill(color)) =>
      validate_page_color(
        bundle,
        page_path,
        Some(element_id),
        "\{field}.color",
        color,
        errors,
      )
    Some(GradientFill(gradient)) =>
      validate_gradient(
        bundle,
        page_path,
        Some(element_id),
        field,
        gradient,
        errors,
      )
  }
}

///|
fn validate_table_cell_margin(
  page_path : String,
  element_id : String,
  field : String,
  margin : TableCellMargin?,
  errors : Array[Diagnostic],
) -> Unit {
  match margin {
    None => ()
    Some(margin) => {
      validate_optional_non_negative(
        page_path,
        element_id,
        "\{field}.margin.left",
        margin.left,
        errors,
      )
      validate_optional_non_negative(
        page_path,
        element_id,
        "\{field}.margin.right",
        margin.right,
        errors,
      )
      validate_optional_non_negative(
        page_path,
        element_id,
        "\{field}.margin.top",
        margin.top,
        errors,
      )
      validate_optional_non_negative(
        page_path,
        element_id,
        "\{field}.margin.bottom",
        margin.bottom,
        errors,
      )
    }
  }
}

///|
fn validate_optional_non_negative(
  page_path : String,
  element_id : String,
  field : String,
  value : Double?,
  errors : Array[Diagnostic],
) -> Unit {
  match value {
    None => ()
    Some(value) =>
      if value < 0.0 {
        errors.push(
          error_diagnostic(
            "PZ060",
            "table cell margin must not be negative",
            path=page_path,
            element_id~,
            field~,
          ),
        )
      }
  }
}

///|
fn validate_table_sizes(
  page_path : String,
  element_id : String,
  field : String,
  sizes : Array[Double]?,
  expected_length : Int,
  errors : Array[Diagnostic],
) -> Unit {
  match sizes {
    None => ()
    Some(sizes) => {
      if sizes.length() != expected_length {
        errors.push(
          error_diagnostic(
            "PZ060",
            "table size array length must match the table grid",
            path=page_path,
            element_id~,
            field~,
          ),
        )
      }
      for index, size in sizes {
        if size <= 0.0 {
          errors.push(
            error_diagnostic(
              "PZ060",
              "table sizes must be greater than zero",
              path=page_path,
              element_id~,
              field="\{field}[\{index}]",
            ),
          )
        }
      }
    }
  }
}

///|
fn validate_shadow(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  shadow : ShadowSpec?,
  errors : Array[Diagnostic],
) -> Unit {
  match shadow {
    None => ()
    Some(shadow) =>
      validate_page_color(
        bundle,
        page_path,
        Some(element_id),
        "elements.content.shadow.color",
        shadow.color,
        errors,
      )
  }
}

///|
fn validate_connector_refs(
  page_path : String,
  element : Element,
  ids : Map[String, Bool],
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
  bundle : DeckBundle,
) -> Unit {
  match element {
    ConnectorElement(id, spec) => {
      validate_connector_endpoint(
        page_path,
        id,
        "elements.content.start",
        spec.start,
        ids,
        errors,
        warnings,
        bundle,
      )
      validate_connector_endpoint(
        page_path,
        id,
        "elements.content.end",
        spec.end,
        ids,
        errors,
        warnings,
        bundle,
      )
    }
    _ => ()
  }
}

///|
fn validate_connector_endpoint(
  page_path : String,
  element_id : String,
  field : String,
  endpoint : ConnectorEndpoint,
  ids : Map[String, Bool],
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
  bundle : DeckBundle,
) -> Unit {
  match endpoint {
    ElementEndpoint(target) =>
      if !ids.contains(target) {
        errors.push(
          error_diagnostic(
            "PZ050",
            "connector endpoint references unknown element",
            path=page_path,
            element_id~,
            field~,
          ),
        )
      }
    CoordinateEndpoint(x, y) =>
      if x < 0.0 ||
        y < 0.0 ||
        x > bundle.deck.size.width ||
        y > bundle.deck.size.height {
        warnings.push(
          warning_diagnostic(
            "PZ100",
            "connector endpoint extends outside canvas",
            path=page_path,
            element_id~,
            field~,
          ),
        )
      }
  }
}

///|
fn validate_text_fit(
  bundle : DeckBundle,
  page_path : String,
  base : ElementBase,
  content : TextContent,
  warnings : Array[Diagnostic],
) -> Unit {
  let bounds = base.bounds
  if bounds.width <= 0.0 ||
    bounds.height <= 0.0 ||
    content.text.trim().is_empty() {
    return
  }
  let estimate = estimate_text_fit(bundle, bounds, content)
  if estimate.height > bounds.height * 1.05 ||
    estimate.longest_token_width > bounds.width {
    warnings.push(
      warning_diagnostic(
        "PZ103",
        "text may overflow its bounds",
        path=page_path,
        element_id=base.id,
        field="elements.content.text",
      ),
    )
  }
}

///|
fn validate_bounds(
  bundle : DeckBundle,
  page_path : String,
  base : ElementBase,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  let bounds = base.bounds
  if bounds.width < 0.0 || bounds.height < 0.0 {
    errors.push(
      error_diagnostic(
        "PZ101",
        "bounds width and height must not be negative",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  } else if bounds.width == 0.0 || bounds.height == 0.0 {
    warnings.push(
      warning_diagnostic(
        "PZ101",
        "bounds have zero width or height",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  }
  if bounds.x < 0.0 ||
    bounds.y < 0.0 ||
    bounds.x + bounds.width > bundle.deck.size.width ||
    bounds.y + bounds.height > bundle.deck.size.height {
    warnings.push(
      warning_diagnostic(
        "PZ100",
        "bounds extend outside canvas",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  }
}

///|
fn validate_text_style_ref(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  style : String?,
  errors : Array[Diagnostic],
) -> Unit {
  match style {
    None => ()
    Some(style) =>
      match bundle.deck.theme {
        None =>
          errors.push(
            error_diagnostic(
              "PZ030",
              "text style token has no deck theme",
              path=page_path,
              element_id~,
              field="elements.content.style",
            ),
          )
        Some(theme) =>
          match token_name(style) {
            Some(name) =>
              if !theme.text_styles.contains(name) {
                errors.push(
                  error_diagnostic(
                    "PZ030",
                    "unresolved text style token",
                    path=page_path,
                    element_id~,
                    field="elements.content.style",
                  ),
                )
              }
            None =>
              errors.push(
                error_diagnostic(
                  "PZ030",
                  "text style must be a whole-string theme token",
                  path=page_path,
                  element_id~,
                  field="elements.content.style",
                ),
              )
          }
      }
  }
}

///|
fn validate_page_color(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  color : String,
  errors : Array[Diagnostic],
) -> Unit {
  match bundle.deck.theme {
    None => validate_color_syntax(color, page_path, element_id, field, errors)
    Some(theme) =>
      validate_color_value(color, theme, page_path, element_id, field, errors)
  }
}

///|
fn validate_color_value(
  color : String,
  theme : Theme,
  path : String,
  element_id : String?,
  field : String,
  errors : Array[Diagnostic],
) -> Unit {
  match token_name(color) {
    Some(name) =>
      if !theme.colors.contains(name) {
        errors.push(
          error_diagnostic(
            "PZ030",
            "unresolved color token",
            path~,
            element_id?,
            field~,
          ),
        )
      }
    None => validate_color_syntax(color, path, element_id, field, errors)
  }
}

///|
fn validate_color_syntax(
  color : String,
  path : String,
  element_id : String?,
  field : String,
  errors : Array[Diagnostic],
) -> Unit {
  if !is_hex_color(color) {
    errors.push(
      error_diagnostic(
        "PZ032",
        "color must be #RRGGBB, #RRGGBBAA, or a theme token",
        path~,
        element_id?,
        field~,
      ),
    )
  }
}

///|
fn validate_gradient(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  gradient : Gradient,
  errors : Array[Diagnostic],
) -> Unit {
  for index, stop in gradient.stops {
    validate_page_color(
      bundle,
      page_path,
      element_id,
      "\{field}.stops[\{index}].color",
      stop.color,
      errors,
    )
  }
}

///|
fn validate_asset_path(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  asset_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  if asset_path.is_blank() {
    errors.push(
      error_diagnostic(
        "PZ040",
        "asset path must not be empty",
        path=page_path,
        element_id?,
        field~,
      ),
    )
    return
  }
  if asset_path.contains("://") {
    errors.push(
      error_diagnostic(
        "PZ040",
        "remote asset URLs are not allowed",
        path=page_path,
        element_id?,
        field~,
      ),
    )
    return
  }
  match resolve_source_path(bundle.deck_dir, asset_path) {
    None =>
      errors.push(
        error_diagnostic(
          "PZ040",
          "asset path must be relative and stay inside the deck directory",
          path=page_path,
          element_id?,
          field~,
        ),
      )
    Some(full_path) => {
      let full_path_text = full_path.to_string()
      if !(@miniio.is_file(full_path_text) catch { _ => false }) {
        errors.push(
          error_diagnostic(
            "PZ040",
            "asset path does not resolve to a file",
            path=page_path,
            element_id?,
            field~,
          ),
        )
      }
    }
  }
}

///|
fn validate_image_crop(
  page_path : String,
  element_id : String,
  crop : CropRect?,
  errors : Array[Diagnostic],
) -> Unit {
  match crop {
    None => ()
    Some(crop) => {
      if !valid_crop_edge(crop.left) ||
        !valid_crop_edge(crop.top) ||
        !valid_crop_edge(crop.right) ||
        !valid_crop_edge(crop.bottom) {
        errors.push(
          error_diagnostic(
            "PZ041",
            "image crop values must be between 0.0 and 1.0",
            path=page_path,
            element_id~,
            field="elements.content.crop",
          ),
        )
      }
      if crop.left + crop.right >= 1.0 || crop.top + crop.bottom >= 1.0 {
        errors.push(
          error_diagnostic(
            "PZ041",
            "image crop must leave a non-empty source rectangle",
            path=page_path,
            element_id~,
            field="elements.content.crop",
          ),
        )
      }
    }
  }
}

///|
fn valid_crop_edge(value : Double) -> Bool {
  value >= 0.0 && value <= 1.0
}

///|
fn validate_image_source_size(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  spec : ImageSpec,
  errors : Array[Diagnostic],
) -> Unit {
  validate_image_fit_source_size(
    bundle,
    page_path,
    Some(element_id),
    "elements.content.path",
    "elements.content.fit",
    spec.path,
    spec.fit,
    errors,
  )
}

///|
fn validate_image_fit_source_size(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  path_field : String,
  fit_field : String,
  image_path : String,
  fit : ImageFit,
  errors : Array[Diagnostic],
) -> Unit {
  match fit {
    StretchFit => ()
    CoverFit | ContainFit =>
      match resolve_existing_asset_path(bundle, image_path) {
        None => ()
        Some(full_path) => {
          let bytes = @miniio.read_file(full_path) catch {
            err => {
              errors.push(
                image_fit_diagnostic(
                  "PZ040",
                  "cannot read image asset: \{err}",
                  page_path,
                  element_id,
                  path_field,
                ),
              )
              return
            }
          }
          match image_source_size(image_path, bytes.binary().to_fixedarray()) {
            Some(size) =>
              if size.width <= 0.0 || size.height <= 0.0 {
                errors.push(
                  image_fit_diagnostic(
                    "PZ041", "image dimensions must be positive", page_path, element_id,
                    path_field,
                  ),
                )
              }
            None =>
              errors.push(
                image_fit_diagnostic(
                  "PZ041", "image fit requires readable image dimensions", page_path,
                  element_id, fit_field,
                ),
              )
          }
        }
      }
  }
}

///|
fn image_fit_diagnostic(
  code : String,
  message : String,
  page_path : String,
  element_id : String?,
  field : String,
) -> Diagnostic {
  match element_id {
    None => error_diagnostic(code, message, path=page_path, field~)
    Some(element_id) =>
      error_diagnostic(code, message, path=page_path, element_id~, field~)
  }
}

///|
fn resolve_existing_asset_path(
  bundle : DeckBundle,
  asset_path : String,
) -> String? {
  resolve_existing_source_file(bundle.deck_dir, asset_path)
}

///|
fn element_id(element : Element) -> String {
  match element {
    TextElement(base, _) => base.id
    ShapeElement(base, _) => base.id
    ImageElement(base, _) => base.id
    ConnectorElement(id, _) => id
    IconElement(base, _) => base.id
    TableElement(base, _) => base.id
    ChartElement(base, _) => base.id
  }
}

///|
fn element_base(element : Element) -> ElementBase? {
  match element {
    TextElement(base, _) => Some(base)
    ShapeElement(base, _) => Some(base)
    ImageElement(base, _) => Some(base)
    ConnectorElement(_, _) => None
    IconElement(base, _) => Some(base)
    TableElement(base, _) => Some(base)
    ChartElement(base, _) => Some(base)
  }
}
