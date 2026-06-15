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
  let expanded_deck = expand_deck_theme(deck, deck_path_text, errors)
  let expanded_pages = expand_pages(expanded_deck, pages, errors)
  if errors.length() > 0 {
    raise LoadError::Diagnostics(errors)
  }
  let bundle = DeckBundle::{
    deck_path: deck_path_text,
    deck_dir: deck_dir_text,
    deck: expanded_deck,
    pages: expanded_pages,
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
fn expand_deck_theme(
  deck : Deck,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Deck {
  match deck.theme {
    None => deck
    Some(theme) =>
      Deck::{
        title: deck.title,
        size: deck.size,
        theme: Some(Theme::{
          colors: theme.colors,
          text_styles: expand_text_styles(theme, deck_path, errors),
          table_styles: expand_table_styles(theme, deck_path, errors),
          chart_styles: expand_chart_styles(theme, deck_path, errors),
        }),
        layouts: deck.layouts,
        components: deck.components,
        pages: deck.pages,
      }
  }
}

///|
fn expand_text_styles(
  theme : Theme,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Map[String, TextStyle] {
  let resolved = Map([], capacity=theme.text_styles.length())
  for name, _ in theme.text_styles {
    ignore(
      resolve_text_style(name, theme, resolved, "|\{name}|", deck_path, errors),
    )
  }
  resolved
}

///|
fn resolve_text_style(
  name : String,
  theme : Theme,
  resolved : Map[String, TextStyle],
  stack : String,
  deck_path : String,
  errors : Array[Diagnostic],
) -> TextStyle? {
  match resolved.get(name) {
    Some(style) => Some(style)
    None =>
      match theme.text_styles.get(name) {
        None => None
        Some(style) => {
          let base = match style.extends {
            None => None
            Some(parent_ref) =>
              match token_name(parent_ref) {
                None => {
                  errors.push(
                    error_diagnostic(
                      "PZ030",
                      "text style extends must be a whole-string theme token",
                      path=deck_path,
                      field="theme.text_styles.\{name}.extends",
                    ),
                  )
                  None
                }
                Some(parent_name) =>
                  if style_stack_contains(stack, parent_name) {
                    errors.push(
                      error_diagnostic(
                        "PZ030",
                        "text style inheritance has a cycle",
                        path=deck_path,
                        field="theme.text_styles.\{name}.extends",
                      ),
                    )
                    None
                  } else {
                    match theme.text_styles.get(parent_name) {
                      None => {
                        errors.push(
                          error_diagnostic(
                            "PZ030",
                            "unresolved text style extends token",
                            path=deck_path,
                            field="theme.text_styles.\{name}.extends",
                          ),
                        )
                        None
                      }
                      Some(_) =>
                        resolve_text_style(
                          parent_name,
                          theme,
                          resolved,
                          "\{stack}\{parent_name}|",
                          deck_path,
                          errors,
                        )
                    }
                  }
              }
          }
          let expanded = match base {
            None => text_style_without_extends(style)
            Some(parent) => merge_text_style(parent, style)
          }
          resolved[name] = expanded
          Some(expanded)
        }
      }
  }
}

///|
fn text_style_without_extends(style : TextStyle) -> TextStyle {
  TextStyle::{
    extends: None,
    font_size: style.font_size,
    font_family: style.font_family,
    color: style.color,
    bold: style.bold,
    italic: style.italic,
    line_height: style.line_height,
    letter_spacing: style.letter_spacing,
  }
}

///|
fn merge_text_style(parent : TextStyle, child : TextStyle) -> TextStyle {
  TextStyle::{
    extends: None,
    font_size: option_double_or(child.font_size, parent.font_size),
    font_family: option_string_or(child.font_family, parent.font_family),
    color: option_string_or(child.color, parent.color),
    bold: option_bool_or(child.bold, parent.bold),
    italic: option_bool_or(child.italic, parent.italic),
    line_height: option_double_or(child.line_height, parent.line_height),
    letter_spacing: option_double_or(
      child.letter_spacing,
      parent.letter_spacing,
    ),
  }
}

///|
fn expand_table_styles(
  theme : Theme,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Map[String, TableStyle] {
  let resolved = Map([], capacity=theme.table_styles.length())
  for name, _ in theme.table_styles {
    ignore(
      resolve_table_style(name, theme, resolved, "|\{name}|", deck_path, errors),
    )
  }
  resolved
}

///|
fn resolve_table_style(
  name : String,
  theme : Theme,
  resolved : Map[String, TableStyle],
  stack : String,
  deck_path : String,
  errors : Array[Diagnostic],
) -> TableStyle? {
  match resolved.get(name) {
    Some(style) => Some(style)
    None =>
      match theme.table_styles.get(name) {
        None => None
        Some(style) => {
          let base = match style.extends {
            None => None
            Some(parent_ref) =>
              match token_name(parent_ref) {
                None => {
                  errors.push(
                    error_diagnostic(
                      "PZ030",
                      "table style extends must be a whole-string theme token",
                      path=deck_path,
                      field="theme.table_styles.\{name}.extends",
                    ),
                  )
                  None
                }
                Some(parent_name) =>
                  if style_stack_contains(stack, parent_name) {
                    errors.push(
                      error_diagnostic(
                        "PZ030",
                        "table style inheritance has a cycle",
                        path=deck_path,
                        field="theme.table_styles.\{name}.extends",
                      ),
                    )
                    None
                  } else {
                    match theme.table_styles.get(parent_name) {
                      None => {
                        errors.push(
                          error_diagnostic(
                            "PZ030",
                            "unresolved table style extends token",
                            path=deck_path,
                            field="theme.table_styles.\{name}.extends",
                          ),
                        )
                        None
                      }
                      Some(_) =>
                        resolve_table_style(
                          parent_name,
                          theme,
                          resolved,
                          "\{stack}\{parent_name}|",
                          deck_path,
                          errors,
                        )
                    }
                  }
              }
          }
          let expanded = match base {
            None => table_style_without_extends(style)
            Some(parent) => merge_table_style(parent, style)
          }
          resolved[name] = expanded
          Some(expanded)
        }
      }
  }
}

///|
fn table_style_without_extends(style : TableStyle) -> TableStyle {
  TableStyle::{
    extends: None,
    font_size: style.font_size,
    font_family: style.font_family,
    header_fill: style.header_fill,
    header_text_color: style.header_text_color,
    body_text_color: style.body_text_color,
    header_color: style.header_color,
    body_color: style.body_color,
    border: style.border,
  }
}

///|
fn merge_table_style(parent : TableStyle, child : TableStyle) -> TableStyle {
  TableStyle::{
    extends: None,
    font_size: option_double_or(child.font_size, parent.font_size),
    font_family: option_string_or(child.font_family, parent.font_family),
    header_fill: option_string_or(child.header_fill, parent.header_fill),
    header_text_color: option_string_or(
      child.header_text_color,
      parent.header_text_color,
    ),
    body_text_color: option_string_or(
      child.body_text_color,
      parent.body_text_color,
    ),
    header_color: option_string_or(child.header_color, parent.header_color),
    body_color: option_string_or(child.body_color, parent.body_color),
    border: option_border_or(child.border, parent.border),
  }
}

///|
fn expand_chart_styles(
  theme : Theme,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Map[String, ChartStyle] {
  let resolved = Map([], capacity=theme.chart_styles.length())
  for name, _ in theme.chart_styles {
    ignore(
      resolve_chart_style(name, theme, resolved, "|\{name}|", deck_path, errors),
    )
  }
  resolved
}

///|
fn resolve_chart_style(
  name : String,
  theme : Theme,
  resolved : Map[String, ChartStyle],
  stack : String,
  deck_path : String,
  errors : Array[Diagnostic],
) -> ChartStyle? {
  match resolved.get(name) {
    Some(style) => Some(style)
    None =>
      match theme.chart_styles.get(name) {
        None => None
        Some(style) => {
          let base = match style.extends {
            None => None
            Some(parent_ref) =>
              match token_name(parent_ref) {
                None => {
                  errors.push(
                    error_diagnostic(
                      "PZ030",
                      "chart style extends must be a whole-string theme token",
                      path=deck_path,
                      field="theme.chart_styles.\{name}.extends",
                    ),
                  )
                  None
                }
                Some(parent_name) =>
                  if style_stack_contains(stack, parent_name) {
                    errors.push(
                      error_diagnostic(
                        "PZ030",
                        "chart style inheritance has a cycle",
                        path=deck_path,
                        field="theme.chart_styles.\{name}.extends",
                      ),
                    )
                    None
                  } else {
                    match theme.chart_styles.get(parent_name) {
                      None => {
                        errors.push(
                          error_diagnostic(
                            "PZ030",
                            "unresolved chart style extends token",
                            path=deck_path,
                            field="theme.chart_styles.\{name}.extends",
                          ),
                        )
                        None
                      }
                      Some(_) =>
                        resolve_chart_style(
                          parent_name,
                          theme,
                          resolved,
                          "\{stack}\{parent_name}|",
                          deck_path,
                          errors,
                        )
                    }
                  }
              }
          }
          let expanded = match base {
            None => chart_style_without_extends(style)
            Some(parent) => merge_chart_style(parent, style)
          }
          resolved[name] = expanded
          Some(expanded)
        }
      }
  }
}

///|
fn chart_style_without_extends(style : ChartStyle) -> ChartStyle {
  ChartStyle::{
    extends: None,
    kind: style.kind,
    legend: style.legend,
    style: style.style,
    data_labels: style.data_labels,
    data_table: style.data_table,
    rounded_corners: style.rounded_corners,
  }
}

///|
fn merge_chart_style(parent : ChartStyle, child : ChartStyle) -> ChartStyle {
  ChartStyle::{
    extends: None,
    kind: option_string_or(child.kind, parent.kind),
    legend: option_string_or(child.legend, parent.legend),
    style: option_int_or(child.style, parent.style),
    data_labels: option_string_or(child.data_labels, parent.data_labels),
    data_table: option_bool_or(child.data_table, parent.data_table),
    rounded_corners: option_bool_or(
      child.rounded_corners,
      parent.rounded_corners,
    ),
  }
}

///|
fn expand_pages(
  deck : Deck,
  pages : Array[ResolvedPage],
  errors : Array[Diagnostic],
) -> Array[ResolvedPage] {
  let expanded = []
  for page in pages {
    expanded.push(ResolvedPage::{
      path: page.path,
      full_path: page.full_path,
      page: expand_page(deck, page.path, page.page, errors),
    })
  }
  expanded
}

///|
fn expand_page(
  deck : Deck,
  page_path : String,
  page : Page,
  errors : Array[Diagnostic],
) -> Page {
  let page = expand_page_layout(deck, page_path, page, errors)
  let page = expand_page_components(deck, page_path, page, errors)
  let elements = []
  for element in page.elements {
    elements.push(expand_element(deck, page_path, element, errors))
  }
  Page::{
    page_type: page.page_type,
    layout: None,
    slots: Map([], capacity=0),
    background: page.background,
    components: [],
    elements,
  }
}

///|
fn expand_page_layout(
  deck : Deck,
  page_path : String,
  page : Page,
  errors : Array[Diagnostic],
) -> Page {
  match page.layout {
    None => {
      if page.slots.length() > 0 {
        errors.push(
          error_diagnostic(
            "PZ030",
            "page slots require a layout",
            path=page_path,
            field="slots",
          ),
        )
      }
      page
    }
    Some(layout_ref) =>
      match token_name(layout_ref) {
        None => {
          errors.push(
            error_diagnostic(
              "PZ030",
              "layout must be a whole-string layout token",
              path=page_path,
              field="layout",
            ),
          )
          page
        }
        Some(name) =>
          match deck.layouts.get(name) {
            None => {
              errors.push(
                error_diagnostic(
                  "PZ030",
                  "unresolved layout token",
                  path=page_path,
                  field="layout",
                ),
              )
              page
            }
            Some(layout) =>
              apply_layout_template(page_path, page, layout, errors)
          }
      }
  }
}

///|
fn apply_layout_template(
  page_path : String,
  page : Page,
  layout : LayoutTemplate,
  errors : Array[Diagnostic],
) -> Page {
  for name, _ in page.slots {
    if !layout.slots.contains(name) {
      errors.push(
        error_diagnostic(
          "PZ030",
          "page slot is not declared by the layout",
          path=page_path,
          field="slots.\{name}",
        ),
      )
    }
  }
  let elements = []
  for element in layout.elements {
    elements.push(prefix_layout_element(element))
  }
  for name, slot in layout.slots {
    match page.slots.get(name) {
      None => ()
      Some(text) => elements.push(layout_slot_element(name, slot, text))
    }
  }
  for element in page.elements {
    elements.push(element)
  }
  Page::{
    page_type: page.page_type,
    layout: None,
    slots: Map([], capacity=0),
    background: option_background_or(page.background, layout.background),
    components: page.components,
    elements,
  }
}

///|
fn expand_page_components(
  deck : Deck,
  page_path : String,
  page : Page,
  errors : Array[Diagnostic],
) -> Page {
  let elements = []
  for instance in page.components {
    match token_name(instance.template) {
      None =>
        errors.push(
          error_diagnostic(
            "PZ030",
            "component use must be a whole-string component token",
            path=page_path,
            element_id=instance.id,
            field="components.use",
          ),
        )
      Some(name) =>
        match deck.components.get(name) {
          None =>
            errors.push(
              error_diagnostic(
                "PZ030",
                "unresolved component token",
                path=page_path,
                element_id=instance.id,
                field="components.use",
              ),
            )
          Some(template) =>
            for element in template.elements {
              elements.push(
                expand_component_element(instance, template, element),
              )
            }
        }
    }
  }
  for element in page.elements {
    elements.push(element)
  }
  Page::{
    page_type: page.page_type,
    layout: page.layout,
    slots: page.slots,
    background: page.background,
    components: [],
    elements,
  }
}

///|
fn expand_component_element(
  instance : ComponentInstance,
  template : ComponentTemplate,
  element : Element,
) -> Element {
  let element = apply_component_props(element, instance.props)
  match element {
    TextElement(base, content) =>
      TextElement(component_base(instance, template.bounds, base), content)
    ShapeElement(base, spec) =>
      ShapeElement(component_base(instance, template.bounds, base), spec)
    ImageElement(base, spec) =>
      ImageElement(component_base(instance, template.bounds, base), spec)
    IconElement(base, spec) =>
      IconElement(component_base(instance, template.bounds, base), spec)
    TableElement(base, spec) =>
      TableElement(component_base(instance, template.bounds, base), spec)
    ChartElement(base, spec) =>
      ChartElement(component_base(instance, template.bounds, base), spec)
    ConnectorElement(id, spec) => ConnectorElement("\{instance.id}_\{id}", spec)
  }
}

///|
fn component_base(
  instance : ComponentInstance,
  template_bounds : Bounds,
  base : ElementBase,
) -> ElementBase {
  let sx = if template_bounds.width > 0.0 {
    instance.bounds.width / template_bounds.width
  } else {
    1.0
  }
  let sy = if template_bounds.height > 0.0 {
    instance.bounds.height / template_bounds.height
  } else {
    1.0
  }
  ElementBase::{
    id: "\{instance.id}_\{base.id}",
    bounds: Bounds::{
      x: instance.bounds.x + (base.bounds.x - template_bounds.x) * sx,
      y: instance.bounds.y + (base.bounds.y - template_bounds.y) * sy,
      width: base.bounds.width * sx,
      height: base.bounds.height * sy,
    },
  }
}

///|
fn apply_component_props(
  element : Element,
  props : Map[String, String],
) -> Element {
  match element {
    TextElement(base, content) =>
      TextElement(base, apply_text_props(content, props))
    _ => element
  }
}

///|
fn apply_text_props(
  content : TextContent,
  props : Map[String, String],
) -> TextContent {
  TextContent::{
    text: replace_prop_value(content.text, props),
    style: content.style,
    align: content.align,
    wrap: content.wrap,
    body: content.body,
    paragraphs: apply_paragraph_props(content.paragraphs, props),
    font_size: content.font_size,
    font_family: content.font_family,
    color: content.color,
    bold: content.bold,
    italic: content.italic,
  }
}

///|
fn apply_paragraph_props(
  paragraphs : Array[TextParagraphSpec]?,
  props : Map[String, String],
) -> Array[TextParagraphSpec]? {
  match paragraphs {
    None => None
    Some(paragraphs) => {
      let result = []
      for paragraph in paragraphs {
        result.push(TextParagraphSpec::{
          text: replace_prop_option(paragraph.text, props),
          runs: apply_run_props(paragraph.runs, props),
          style: paragraph.style,
          align: paragraph.align,
          line_height: paragraph.line_height,
          space_before: paragraph.space_before,
          space_after: paragraph.space_after,
          margin_left: paragraph.margin_left,
          indent: paragraph.indent,
          bullet: paragraph.bullet,
        })
      }
      Some(result)
    }
  }
}

///|
fn apply_run_props(
  runs : Array[TextRunSpec]?,
  props : Map[String, String],
) -> Array[TextRunSpec]? {
  match runs {
    None => None
    Some(runs) => {
      let result = []
      for run in runs {
        result.push(TextRunSpec::{
          text: replace_prop_value(run.text, props),
          style: run.style,
          font_size: run.font_size,
          font_family: run.font_family,
          color: run.color,
          bold: run.bold,
          italic: run.italic,
          hyperlink: run.hyperlink,
          tooltip: run.tooltip,
        })
      }
      Some(result)
    }
  }
}

///|
fn replace_prop_option(value : String?, props : Map[String, String]) -> String? {
  match value {
    None => None
    Some(value) => Some(replace_prop_value(value, props))
  }
}

///|
fn replace_prop_value(value : String, props : Map[String, String]) -> String {
  match token_name(value) {
    None => value
    Some(name) =>
      match props.get(name) {
        None => value
        Some(value) => value
      }
  }
}

///|
fn layout_slot_element(
  name : String,
  slot : LayoutSlot,
  text : String,
) -> Element {
  TextElement(ElementBase::{ id: "layout_\{name}", bounds: slot.bounds }, TextContent::{
    text,
    style: slot.style,
    align: slot.align,
    wrap: Some(true),
    body: None,
    paragraphs: None,
    font_size: None,
    font_family: None,
    color: None,
    bold: None,
    italic: None,
  })
}

///|
fn prefix_layout_element(element : Element) -> Element {
  match element {
    TextElement(base, content) => TextElement(prefix_layout_base(base), content)
    ShapeElement(base, spec) => ShapeElement(prefix_layout_base(base), spec)
    ImageElement(base, spec) => ImageElement(prefix_layout_base(base), spec)
    IconElement(base, spec) => IconElement(prefix_layout_base(base), spec)
    TableElement(base, spec) => TableElement(prefix_layout_base(base), spec)
    ChartElement(base, spec) => ChartElement(prefix_layout_base(base), spec)
    ConnectorElement(id, spec) => ConnectorElement("layout_\{id}", spec)
  }
}

///|
fn prefix_layout_base(base : ElementBase) -> ElementBase {
  ElementBase::{ id: "layout_\{base.id}", bounds: base.bounds }
}

///|
fn expand_element(
  deck : Deck,
  page_path : String,
  element : Element,
  errors : Array[Diagnostic],
) -> Element {
  match element {
    ChartElement(base, spec) =>
      ChartElement(
        base,
        expand_chart_spec(deck, page_path, base.id, spec, errors),
      )
    _ => element
  }
}

///|
fn expand_chart_spec(
  deck : Deck,
  page_path : String,
  element_id : String,
  spec : ChartSpec,
  errors : Array[Diagnostic],
) -> ChartSpec {
  match spec.chart_style {
    None => spec
    Some(style_ref) =>
      match deck.theme {
        None => {
          errors.push(
            error_diagnostic(
              "PZ030",
              "chart style token has no deck theme",
              path=page_path,
              element_id~,
              field="elements.content.chart_style",
            ),
          )
          spec
        }
        Some(theme) =>
          match token_name(style_ref) {
            None => {
              errors.push(
                error_diagnostic(
                  "PZ030",
                  "chart style must be a whole-string theme token",
                  path=page_path,
                  element_id~,
                  field="elements.content.chart_style",
                ),
              )
              spec
            }
            Some(name) =>
              match theme.chart_styles.get(name) {
                None => {
                  errors.push(
                    error_diagnostic(
                      "PZ030",
                      "unresolved chart style token",
                      path=page_path,
                      element_id~,
                      field="elements.content.chart_style",
                    ),
                  )
                  spec
                }
                Some(style) => merge_chart_spec(style, spec)
              }
          }
      }
  }
}

///|
fn merge_chart_spec(style : ChartStyle, spec : ChartSpec) -> ChartSpec {
  ChartSpec::{
    chart_style: None,
    kind: if spec.kind.is_empty() {
      style.kind.unwrap_or("")
    } else {
      spec.kind
    },
    title: spec.title,
    legend: option_string_or(spec.legend, style.legend),
    style: option_int_or(spec.style, style.style),
    data_labels: option_string_or(spec.data_labels, style.data_labels),
    data_table: option_bool_or(spec.data_table, style.data_table),
    rounded_corners: option_bool_or(spec.rounded_corners, style.rounded_corners),
    categories: spec.categories,
    series: spec.series,
  }
}

///|
fn style_stack_contains(stack : String, name : String) -> Bool {
  stack.contains("|\{name}|")
}

///|
fn option_string_or(value : String?, fallback : String?) -> String? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn option_double_or(value : Double?, fallback : Double?) -> Double? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn option_bool_or(value : Bool?, fallback : Bool?) -> Bool? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn option_int_or(value : Int?, fallback : Int?) -> Int? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn option_border_or(value : Border?, fallback : Border?) -> Border? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn option_background_or(
  value : Background?,
  fallback : Background?,
) -> Background? {
  match value {
    Some(_) => value
    None => fallback
  }
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
  validate_theme(bundle.deck, bundle.deck_path, errors, warnings)
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
  warnings : Array[Diagnostic],
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
        validate_font_family(
          deck_path,
          None,
          "theme.text_styles.\{name}.font_family",
          style.font_family,
          warnings,
        )
      }
      for name, style in theme.table_styles {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme table style token name is invalid",
              path=deck_path,
              field="theme.table_styles.\{name}",
            ),
          )
        }
        match style.header_fill {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.header_fill",
              errors,
            )
        }
        match style.header_text_color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.header_text_color",
              errors,
            )
        }
        match style.body_text_color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.body_text_color",
              errors,
            )
        }
        match style.header_color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.header_color",
              errors,
            )
        }
        match style.body_color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.body_color",
              errors,
            )
        }
        match style.border {
          None => ()
          Some(border) =>
            validate_color_value(
              border.color,
              theme,
              deck_path,
              None,
              "theme.table_styles.\{name}.border.color",
              errors,
            )
        }
        validate_font_family(
          deck_path,
          None,
          "theme.table_styles.\{name}.font_family",
          style.font_family,
          warnings,
        )
      }
      for name, style in theme.chart_styles {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme chart style token name is invalid",
              path=deck_path,
              field="theme.chart_styles.\{name}",
            ),
          )
        }
        validate_chart_style(deck_path, name, style, errors)
      }
    }
  }
}

///|
fn validate_chart_style(
  deck_path : String,
  name : String,
  style : ChartStyle,
  errors : Array[Diagnostic],
) -> Unit {
  match style.kind {
    None => ()
    Some(kind) =>
      if !chart_kind_supported(kind) {
        errors.push(
          error_diagnostic(
            "PZ070",
            "unsupported chart kind",
            path=deck_path,
            field="theme.chart_styles.\{name}.kind",
          ),
        )
      }
  }
  match style.legend {
    None => ()
    Some(legend) =>
      if !chart_legend_supported(legend) {
        errors.push(
          error_diagnostic(
            "PZ070",
            "unsupported chart legend",
            path=deck_path,
            field="theme.chart_styles.\{name}.legend",
          ),
        )
      }
  }
  match style.style {
    None => ()
    Some(style_number) =>
      if style_number < 1 || style_number > 48 {
        errors.push(
          error_diagnostic(
            "PZ070",
            "chart style must be between 1 and 48",
            path=deck_path,
            field="theme.chart_styles.\{name}.style",
          ),
        )
      }
  }
  match style.data_labels {
    None => ()
    Some(pos) =>
      if !chart_data_label_supported(pos) {
        errors.push(
          error_diagnostic(
            "PZ070",
            "unsupported chart data_labels position",
            path=deck_path,
            field="theme.chart_styles.\{name}.data_labels",
          ),
        )
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
    validate_element(
      bundle,
      resolved_page.path,
      resolved_page.page.background,
      element,
      errors,
      warnings,
    )
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
  page_background : Background?,
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
      validate_text_layout_spaces(page_path, base, content, warnings)
      validate_text_fit(bundle, page_path, base, content, warnings)
      validate_text_style_ref(bundle, page_path, base.id, content.style, errors)
      validate_text_content(
        bundle,
        page_path,
        base.id,
        content,
        errors,
        warnings,
      )
      validate_font_family(
        page_path,
        Some(base.id),
        "elements.content.font_family",
        content.font_family,
        warnings,
      )
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
      validate_table(
        bundle, page_path, page_background, base, spec, errors, warnings,
      )
    ChartElement(base, spec) => validate_chart(page_path, base, spec, errors)
  }
}

///|
fn validate_text_content(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  content : TextContent,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  match content.paragraphs {
    None => ()
    Some(paragraphs) =>
      for paragraph_index, paragraph in paragraphs {
        let paragraph_field = "elements.content.paragraphs[\{paragraph_index}]"
        validate_text_style_ref_at(
          bundle,
          page_path,
          element_id,
          paragraph.style,
          "\{paragraph_field}.style",
          errors,
        )
        match paragraph.runs {
          None => ()
          Some(runs) =>
            for run_index, run in runs {
              let run_field = "\{paragraph_field}.runs[\{run_index}]"
              validate_text_style_ref_at(
                bundle,
                page_path,
                element_id,
                run.style,
                "\{run_field}.style",
                errors,
              )
              match run.color {
                None => ()
                Some(color) =>
                  validate_page_color(
                    bundle,
                    page_path,
                    Some(element_id),
                    "\{run_field}.color",
                    color,
                    errors,
                  )
              }
              validate_font_family(
                page_path,
                Some(element_id),
                "\{run_field}.font_family",
                run.font_family,
                warnings,
              )
            }
        }
      }
  }
}

///|
fn validate_font_family(
  path : String,
  element_id : String?,
  field : String,
  font_family : String?,
  warnings : Array[Diagnostic],
) -> Unit {
  match font_family {
    None => ()
    Some(family) =>
      if font_family_looks_like_fallback_list(family) {
        warnings.push(
          warning_diagnostic(
            "PZ105",
            "font_family should name one PowerPoint typeface, not a CSS fallback list",
            path~,
            element_id?,
            field~,
          ),
        )
      }
  }
}

///|
fn font_family_looks_like_fallback_list(value : String) -> Bool {
  value.contains(",")
}

///|
fn validate_text_layout_spaces(
  page_path : String,
  base : ElementBase,
  content : TextContent,
  warnings : Array[Diagnostic],
) -> Unit {
  match content.paragraphs {
    Some(_) => ()
    None =>
      if text_has_layout_spaces(content.text) {
        warnings.push(
          warning_diagnostic(
            "PZ106",
            "text contains repeated spaces that may be used for layout; use separate text boxes, tables, or components",
            path=page_path,
            element_id=base.id,
            field="elements.content.text",
          ),
        )
      }
  }
}

///|
fn text_has_layout_spaces(value : String) -> Bool {
  let mut seen_non_space_on_line = false
  let mut spaces = 0
  for char in value {
    if char == '\n' {
      seen_non_space_on_line = false
      spaces = 0
    } else if char == ' ' {
      if seen_non_space_on_line {
        spaces += 1
        if spaces >= 3 {
          return true
        }
      }
    } else {
      seen_non_space_on_line = true
      spaces = 0
    }
  }
  false
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
  page_background : Background?,
  base : ElementBase,
  spec : TableSpec,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  validate_table_style_ref(bundle, page_path, base.id, spec.style, errors)
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
  validate_table_text_contrast(
    bundle, page_path, page_background, base, spec, warnings,
  )
}

///|
fn validate_table_text_contrast(
  bundle : DeckBundle,
  page_path : String,
  page_background : Background?,
  base : ElementBase,
  spec : TableSpec,
  warnings : Array[Diagnostic],
) -> Unit {
  match theme_table_style(bundle, spec.style) {
    None => ()
    Some(style) => {
      let page_bg = page_solid_background_color(page_background)
      warn_low_table_contrast(
        bundle,
        page_path,
        base.id,
        "elements.content.style",
        table_style_text_color(style, 0),
        table_header_background_color(style, page_bg),
        warnings,
      )
      warn_low_table_contrast(
        bundle,
        page_path,
        base.id,
        "elements.content.style",
        table_style_text_color(style, 1),
        page_bg,
        warnings,
      )
      for row_index, row in spec.rows {
        for cell_index, cell in row.cells {
          match table_cell_solid_fill(cell.fill) {
            None => ()
            Some(fill) =>
              warn_low_table_contrast(
                bundle,
                page_path,
                base.id,
                "elements.content.rows[\{row_index}].cells[\{cell_index}].fill",
                table_style_text_color(style, row_index),
                Some(fill),
                warnings,
              )
          }
        }
      }
    }
  }
}

///|
fn warn_low_table_contrast(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  field : String,
  foreground : String?,
  background : String?,
  warnings : Array[Diagnostic],
) -> Unit {
  match (foreground, background) {
    (Some(foreground), Some(background)) =>
      if is_low_contrast_color_pair(bundle, foreground, background) {
        warnings.push(
          warning_diagnostic(
            "PZ104",
            "table text may have low contrast",
            path=page_path,
            element_id~,
            field~,
          ),
        )
      }
    _ => ()
  }
}

///|
fn page_solid_background_color(background : Background?) -> String? {
  match background {
    None => Some("#FFFFFF")
    Some(SolidBackground(color)) => Some(color)
    Some(GradientBackground(_)) | Some(ImageBackground(_)) => None
  }
}

///|
fn table_header_background_color(
  style : TableStyle,
  page_background : String?,
) -> String? {
  match style.header_fill {
    Some(color) => Some(color)
    None => page_background
  }
}

///|
fn table_cell_solid_fill(fill : Fill?) -> String? {
  match fill {
    Some(SolidFill(color)) => Some(color)
    _ => None
  }
}

///|
fn is_low_contrast_color_pair(
  bundle : DeckBundle,
  foreground : String,
  background : String,
) -> Bool {
  match
    (
      resolve_solid_color(bundle, foreground),
      resolve_solid_color(bundle, background),
    ) {
    (Some(foreground), Some(background)) =>
      match (relative_luminance(foreground), relative_luminance(background)) {
        (Some(fg), Some(bg)) => contrast_ratio(fg, bg) < 3.0
        _ => false
      }
    _ => false
  }
}

///|
fn resolve_solid_color(bundle : DeckBundle, color : String) -> String? {
  match token_name(color) {
    Some(name) =>
      match bundle.deck.theme {
        None => None
        Some(theme) =>
          match theme.colors.get(name) {
            Some(value) => if is_hex_color(value) { Some(value) } else { None }
            None => None
          }
      }
    None => if is_hex_color(color) { Some(color) } else { None }
  }
}

///|
fn relative_luminance(color : String) -> Double? {
  guard color.length() >= 7 else { return None }
  match
    (
      color_hex_byte(color, 1),
      color_hex_byte(color, 3),
      color_hex_byte(color, 5),
    ) {
    (Some(red), Some(green), Some(blue)) =>
      Some(
        (
          0.2126 * red.to_double() +
          0.7152 * green.to_double() +
          0.0722 * blue.to_double()
        ) /
        255.0,
      )
    _ => None
  }
}

///|
fn color_hex_byte(color : String, offset : Int) -> Int? {
  match (color.get_char(offset), color.get_char(offset + 1)) {
    (Some(hi), Some(lo)) =>
      match (color_hex_digit(hi), color_hex_digit(lo)) {
        (Some(hi), Some(lo)) => Some(hi * 16 + lo)
        _ => None
      }
    _ => None
  }
}

///|
fn color_hex_digit(char : Char) -> Int? {
  let code = char.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn contrast_ratio(first : Double, second : Double) -> Double {
  let lighter = if first > second { first } else { second }
  let darker = if first > second { second } else { first }
  (lighter + 0.05) / (darker + 0.05)
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
  validate_text_style_ref_at(
    bundle, page_path, element_id, style, "elements.content.style", errors,
  )
}

///|
fn validate_text_style_ref_at(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  style : String?,
  field : String,
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
              field~,
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
                    field~,
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
                  field~,
                ),
              )
          }
      }
  }
}

///|
fn validate_table_style_ref(
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
              "table style token has no deck theme",
              path=page_path,
              element_id~,
              field="elements.content.style",
            ),
          )
        Some(theme) =>
          match token_name(style) {
            Some(name) =>
              if !theme.table_styles.contains(name) {
                errors.push(
                  error_diagnostic(
                    "PZ030",
                    "unresolved table style token",
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
                  "table style must be a whole-string theme token",
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
