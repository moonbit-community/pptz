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
pub fn parse_deck_toml(source : String) -> Deck raise {
  match @toml.parse(source) {
    @toml.TomlTable(table) => parse_deck_table(table)
    _ => fail("deck: expected top-level table")
  }
}

///|
pub fn parse_page_toml(source : String) -> Page raise {
  match @toml.parse(source) {
    @toml.TomlTable(table) => parse_page_table(table)
    _ => fail("page: expected top-level table")
  }
}

///|
fn parse_deck_table(table : Map[String, @toml.TomlValue]) -> Deck raise {
  reject_unknown_fields(table, "deck", ["title", "size", "theme", "pages"])
  Deck::{
    title: optional_string(table.get("title"), "title"),
    size: parse_size(required_array(table, "size"), "size"),
    theme: parse_optional_theme(table.get("theme"), "theme"),
    pages: parse_page_refs(required_array(table, "pages"), "pages"),
  }
}

///|
fn parse_page_table(table : Map[String, @toml.TomlValue]) -> Page raise {
  reject_unknown_fields(table, "page", ["page_type", "background", "elements"])
  Page::{
    page_type: optional_string(table.get("page_type"), "page_type"),
    background: parse_optional_background(table.get("background"), "background"),
    elements: parse_elements(required_array(table, "elements"), "elements"),
  }
}

///|
fn parse_optional_theme(
  value : @toml.TomlValue?,
  path : String,
) -> Theme? raise {
  match value {
    None => None
    Some(value) => Some(parse_theme(expect_table(value, path), path))
  }
}

///|
fn parse_theme(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Theme raise {
  reject_unknown_fields(table, path, ["colors", "text_styles", "table_styles"])
  Theme::{
    colors: parse_string_map(required_table(table, "colors"), "\{path}.colors"),
    text_styles: parse_text_styles(
      required_table(table, "text_styles"),
      "\{path}.text_styles",
    ),
    table_styles: parse_table_styles(
      table.get("table_styles"),
      "\{path}.table_styles",
    ),
  }
}

///|
fn parse_string_map(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Map[String, String] raise {
  let result = Map([], capacity=table.length())
  for key, value in table {
    match value {
      @toml.TomlString(text) => result[key] = text
      _ => fail("\{path}.\{key}: expected string")
    }
  }
  result
}

///|
fn parse_text_styles(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Map[String, TextStyle] raise {
  let result = Map([], capacity=table.length())
  for name, value in table {
    let style_path = "\{path}.\{name}"
    let style_table = expect_table(value, style_path)
    reject_unknown_fields(style_table, style_path, [
      "extends", "font_size", "font_family", "color", "bold", "italic", "line_height",
      "letter_spacing",
    ])
    result[name] = TextStyle::{
      extends: optional_string(
        style_table.get("extends"),
        "\{style_path}.extends",
      ),
      font_size: optional_double(
        style_table.get("font_size"),
        "\{style_path}.font_size",
      ),
      font_family: optional_string(
        style_table.get("font_family"),
        "\{style_path}.font_family",
      ),
      color: optional_string(style_table.get("color"), "\{style_path}.color"),
      bold: optional_bool(style_table.get("bold"), "\{style_path}.bold"),
      italic: optional_bool(style_table.get("italic"), "\{style_path}.italic"),
      line_height: optional_double(
        style_table.get("line_height"),
        "\{style_path}.line_height",
      ),
      letter_spacing: optional_double(
        style_table.get("letter_spacing"),
        "\{style_path}.letter_spacing",
      ),
    }
  }
  result
}

///|
fn parse_table_styles(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, TableStyle] raise {
  match value {
    None => Map([], capacity=0)
    Some(value) => {
      let table = expect_table(value, path)
      let result = Map([], capacity=table.length())
      for name, style_value in table {
        let style_path = "\{path}.\{name}"
        let style_table = expect_table(style_value, style_path)
        reject_unknown_fields(style_table, style_path, [
          "extends", "font_size", "font_family", "header_fill", "header_text_color",
          "body_text_color", "header_color", "body_color", "border",
        ])
        if style_table.get("header_text_color") is Some(_) &&
          style_table.get("header_color") is Some(_) {
          fail(
            "\{style_path}: use either header_text_color or header_color, not both",
          )
        }
        if style_table.get("body_text_color") is Some(_) &&
          style_table.get("body_color") is Some(_) {
          fail(
            "\{style_path}: use either body_text_color or body_color, not both",
          )
        }
        result[name] = TableStyle::{
          extends: optional_string(
            style_table.get("extends"),
            "\{style_path}.extends",
          ),
          font_size: optional_double(
            style_table.get("font_size"),
            "\{style_path}.font_size",
          ),
          font_family: optional_string(
            style_table.get("font_family"),
            "\{style_path}.font_family",
          ),
          header_fill: optional_string(
            style_table.get("header_fill"),
            "\{style_path}.header_fill",
          ),
          header_text_color: optional_string(
            style_table.get("header_text_color"),
            "\{style_path}.header_text_color",
          ),
          body_text_color: optional_string(
            style_table.get("body_text_color"),
            "\{style_path}.body_text_color",
          ),
          header_color: optional_string(
            style_table.get("header_color"),
            "\{style_path}.header_color",
          ),
          body_color: optional_string(
            style_table.get("body_color"),
            "\{style_path}.body_color",
          ),
          border: parse_optional_border(
            style_table.get("border"),
            "\{style_path}.border",
          ),
        }
      }
      result
    }
  }
}

///|
fn parse_page_refs(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[PageRef] raise {
  let refs = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    let table = expect_table(value, item_path)
    reject_unknown_fields(table, item_path, ["path"])
    refs.push(PageRef::{
      path: required_string(table, "\{item_path}.path", key="path"),
    })
  }
  refs
}

///|
fn parse_optional_background(
  value : @toml.TomlValue?,
  path : String,
) -> Background? raise {
  match value {
    None => None
    Some(value) => Some(parse_background_table(expect_table(value, path), path))
  }
}

///|
fn parse_background_table(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Background raise {
  match required_string(table, "\{path}.type", key="type") {
    "solid" => {
      reject_unknown_fields(table, path, ["type", "color"])
      SolidBackground(required_string(table, "\{path}.color", key="color"))
    }
    "image" => {
      reject_unknown_fields(table, path, ["type", "path", "fit"])
      ImageBackground(ImageFill::{
        path: required_string(table, "\{path}.path", key="path"),
        fit: parse_image_fit(
          optional_string(table.get("fit"), "\{path}.fit"),
          "\{path}.fit",
        ),
      })
    }
    "gradient" => {
      reject_unknown_fields(table, path, ["type", "direction", "stops"])
      GradientBackground(parse_gradient(table, path))
    }
    kind => fail("\{path}.type: unsupported background type '\{kind}'")
  }
}

///|
fn parse_gradient(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Gradient raise {
  Gradient::{
    direction: optional_double(table.get("direction"), "\{path}.direction"),
    stops: parse_gradient_stops(
      required_array(table, "\{path}.stops", key="stops"),
      "\{path}.stops",
    ),
  }
}

///|
fn parse_gradient_stops(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[GradientStop] raise {
  let stops = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    let table = expect_table(value, item_path)
    reject_unknown_fields(table, item_path, ["at", "color"])
    stops.push(GradientStop::{
      at: required_double(table, "\{item_path}.at", key="at"),
      color: required_string(table, "\{item_path}.color", key="color"),
    })
  }
  stops
}

///|
fn parse_elements(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[Element] raise {
  let elements = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    elements.push(
      parse_element_table(expect_table(value, item_path), item_path),
    )
  }
  elements
}

///|
fn parse_element_table(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Element raise {
  let kind = required_string(table, "\{path}.type", key="type")
  reject_unknown_element_fields(table, path, kind)
  let id = required_string(table, "\{path}.id", key="id")
  if kind == "connector" {
    ConnectorElement(id, parse_required_connector_spec(table, path))
  } else {
    let base = ElementBase::{
      id,
      bounds: parse_bounds(
        required_array(table, "\{path}.bounds", key="bounds"),
        "\{path}.bounds",
      ),
    }
    parse_element_content(kind, base, table, path)
  }
}

///|
fn reject_unknown_element_fields(
  table : Map[String, @toml.TomlValue],
  path : String,
  kind : String,
) -> Unit raise {
  match kind {
    "text" | "shape" | "image" | "icon" | "table" | "chart" =>
      reject_unknown_fields(table, path, ["id", "type", "bounds", "content"])
    "connector" => reject_unknown_fields(table, path, ["id", "type", "content"])
    _ => fail("\{path}.type: unsupported element type '\{kind}'")
  }
}

///|
fn parse_element_content(
  kind : String,
  base : ElementBase,
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Element raise {
  match kind {
    "text" => TextElement(base, parse_required_text_content(table, path))
    "shape" => ShapeElement(base, parse_required_shape_spec(table, path))
    "image" => ImageElement(base, parse_required_image_spec(table, path))
    "icon" => IconElement(base, parse_required_icon_spec(table, path))
    "table" => TableElement(base, parse_required_table_spec(table, path))
    "chart" => ChartElement(base, parse_required_chart_spec(table, path))
    kind => fail("\{path}.type: unsupported element type '\{kind}'")
  }
}

///|
fn parse_required_connector_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ConnectorSpec raise {
  parse_connector_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_text_content(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> TextContent raise {
  parse_text_content(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_shape_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ShapeSpec raise {
  parse_shape_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_image_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ImageSpec raise {
  parse_image_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_icon_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> IconSpec raise {
  parse_icon_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_table_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> TableSpec raise {
  parse_table_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_chart_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ChartSpec raise {
  parse_chart_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_text_content(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> TextContent raise {
  reject_unknown_fields(table, path, [
    "text", "style", "align", "wrap", "font_size", "font_family", "color", "bold",
    "italic", "body", "paragraphs",
  ])
  let paragraphs = parse_optional_text_paragraphs(
    table.get("paragraphs"),
    "\{path}.paragraphs",
  )
  let text = match (table.get("text"), paragraphs) {
    (Some(_), Some(_)) =>
      fail("\{path}: use either text or paragraphs, not both")
    (Some(value), None) => expect_string(value, "\{path}.text")
    (None, Some(paragraphs)) => text_from_paragraphs(paragraphs)
    (None, None) => fail("\{path}.text: missing required string")
  }
  TextContent::{
    text,
    style: optional_string(table.get("style"), "\{path}.style"),
    align: parse_optional_align(table.get("align"), "\{path}.align"),
    wrap: optional_bool(table.get("wrap"), "\{path}.wrap"),
    body: parse_optional_text_body_options(table.get("body"), "\{path}.body"),
    paragraphs,
    font_size: optional_double(table.get("font_size"), "\{path}.font_size"),
    font_family: optional_string(
      table.get("font_family"),
      "\{path}.font_family",
    ),
    color: optional_string(table.get("color"), "\{path}.color"),
    bold: optional_bool(table.get("bold"), "\{path}.bold"),
    italic: optional_bool(table.get("italic"), "\{path}.italic"),
  }
}

///|
fn parse_optional_text_body_options(
  value : @toml.TomlValue?,
  path : String,
) -> TextBodyOptions? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["inset", "auto_fit"])
      Some(TextBodyOptions::{
        inset: parse_optional_text_inset(table.get("inset"), "\{path}.inset"),
        auto_fit: optional_string(table.get("auto_fit"), "\{path}.auto_fit"),
      })
    }
  }
}

///|
fn parse_optional_text_inset(
  value : @toml.TomlValue?,
  path : String,
) -> TextInset? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["left", "right", "top", "bottom"])
      Some(TextInset::{
        left: optional_double(table.get("left"), "\{path}.left"),
        right: optional_double(table.get("right"), "\{path}.right"),
        top: optional_double(table.get("top"), "\{path}.top"),
        bottom: optional_double(table.get("bottom"), "\{path}.bottom"),
      })
    }
  }
}

///|
fn parse_optional_text_paragraphs(
  value : @toml.TomlValue?,
  path : String,
) -> Array[TextParagraphSpec]? raise {
  match value {
    None => None
    Some(@toml.TomlArray(values)) => {
      let paragraphs = []
      for index, value in values {
        paragraphs.push(parse_text_paragraph(value, "\{path}[\{index}]"))
      }
      Some(paragraphs)
    }
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn parse_text_paragraph(
  value : @toml.TomlValue,
  path : String,
) -> TextParagraphSpec raise {
  let table = expect_table(value, path)
  reject_unknown_fields(table, path, [
    "text", "runs", "style", "align", "line_height", "space_before", "space_after",
    "margin_left", "indent", "bullet",
  ])
  let text = optional_string(table.get("text"), "\{path}.text")
  let runs = parse_optional_text_runs(table.get("runs"), "\{path}.runs")
  if text is Some(_) && runs is Some(_) {
    fail("\{path}: use either text or runs, not both")
  }
  if text is None && runs is None {
    fail("\{path}: missing text or runs")
  }
  TextParagraphSpec::{
    text,
    runs,
    style: optional_string(table.get("style"), "\{path}.style"),
    align: parse_optional_align(table.get("align"), "\{path}.align"),
    line_height: optional_double(
      table.get("line_height"),
      "\{path}.line_height",
    ),
    space_before: optional_double(
      table.get("space_before"),
      "\{path}.space_before",
    ),
    space_after: optional_double(
      table.get("space_after"),
      "\{path}.space_after",
    ),
    margin_left: optional_double(
      table.get("margin_left"),
      "\{path}.margin_left",
    ),
    indent: optional_double(table.get("indent"), "\{path}.indent"),
    bullet: parse_optional_bullet(table.get("bullet"), "\{path}.bullet"),
  }
}

///|
fn parse_optional_text_runs(
  value : @toml.TomlValue?,
  path : String,
) -> Array[TextRunSpec]? raise {
  match value {
    None => None
    Some(@toml.TomlArray(values)) => {
      let runs = []
      for index, value in values {
        runs.push(parse_text_run(value, "\{path}[\{index}]"))
      }
      Some(runs)
    }
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn parse_text_run(value : @toml.TomlValue, path : String) -> TextRunSpec raise {
  let table = expect_table(value, path)
  reject_unknown_fields(table, path, [
    "text", "style", "font_size", "font_family", "color", "bold", "italic", "hyperlink",
    "tooltip",
  ])
  TextRunSpec::{
    text: required_string(table, "\{path}.text", key="text"),
    style: optional_string(table.get("style"), "\{path}.style"),
    font_size: optional_double(table.get("font_size"), "\{path}.font_size"),
    font_family: optional_string(
      table.get("font_family"),
      "\{path}.font_family",
    ),
    color: optional_string(table.get("color"), "\{path}.color"),
    bold: optional_bool(table.get("bold"), "\{path}.bold"),
    italic: optional_bool(table.get("italic"), "\{path}.italic"),
    hyperlink: optional_string(table.get("hyperlink"), "\{path}.hyperlink"),
    tooltip: optional_string(table.get("tooltip"), "\{path}.tooltip"),
  }
}

///|
fn parse_optional_bullet(
  value : @toml.TomlValue?,
  path : String,
) -> BulletSpec? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["kind", "char", "start"])
      Some(BulletSpec::{
        kind: required_string(table, "\{path}.kind", key="kind"),
        char: optional_string(table.get("char"), "\{path}.char"),
        start: optional_int_or_none(table.get("start"), "\{path}.start"),
      })
    }
  }
}

///|
fn text_from_paragraphs(paragraphs : Array[TextParagraphSpec]) -> String {
  let lines = []
  for paragraph in paragraphs {
    match paragraph.text {
      Some(text) => lines.push(text)
      None =>
        match paragraph.runs {
          None => lines.push("")
          Some(runs) => {
            let mut line = ""
            for run in runs {
              line = line + run.text
            }
            lines.push(line)
          }
        }
    }
  }
  lines.join("\n")
}

///|
fn parse_shape_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ShapeSpec raise {
  reject_unknown_fields(table, path, ["shape", "fill", "border", "shadow"])
  ShapeSpec::{
    shape: required_string(table, "\{path}.shape", key="shape"),
    fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
    border: parse_optional_border(table.get("border"), "\{path}.border"),
    shadow: parse_optional_shadow(table.get("shadow"), "\{path}.shadow"),
  }
}

///|
fn parse_image_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ImageSpec raise {
  reject_unknown_fields(table, path, ["path", "fit", "crop"])
  ImageSpec::{
    path: required_string(table, "\{path}.path", key="path"),
    fit: parse_image_fit(
      optional_string(table.get("fit"), "\{path}.fit"),
      "\{path}.fit",
    ),
    crop: parse_optional_crop_rect(table.get("crop"), "\{path}.crop"),
  }
}

///|
fn parse_connector_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ConnectorSpec raise {
  reject_unknown_fields(table, path, [
    "kind", "start", "end", "stroke", "start_arrow", "end_arrow", "shadow",
  ])
  ConnectorSpec::{
    kind: required_string(table, "\{path}.kind", key="kind"),
    start: parse_connector_endpoint(table.get("start"), "\{path}.start"),
    end: parse_connector_endpoint(table.get("end"), "\{path}.end"),
    stroke: parse_optional_stroke(table.get("stroke"), "\{path}.stroke"),
    start_arrow: optional_string(
      table.get("start_arrow"),
      "\{path}.start_arrow",
    ),
    end_arrow: optional_string(table.get("end_arrow"), "\{path}.end_arrow"),
    shadow: parse_optional_shadow(table.get("shadow"), "\{path}.shadow"),
  }
}

///|
fn parse_connector_endpoint(
  value : @toml.TomlValue?,
  path : String,
) -> ConnectorEndpoint raise {
  match value {
    None => fail("\{path}: missing required value")
    Some(@toml.TomlArray(items)) => {
      let values = parse_size(items, path)
      CoordinateEndpoint(values.width, values.height)
    }
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["element"])
      ElementEndpoint(required_string(table, "\{path}.element", key="element"))
    }
  }
}

///|
fn parse_optional_stroke(
  value : @toml.TomlValue?,
  path : String,
) -> Border? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["dash", "width", "color"])
      Some(Border::{
        style: required_string(table, "\{path}.dash", key="dash"),
        width: required_double(table, "\{path}.width", key="width"),
        color: required_string(table, "\{path}.color", key="color"),
      })
    }
  }
}

///|
fn parse_optional_shadow(
  value : @toml.TomlValue?,
  path : String,
) -> ShadowSpec? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, [
        "color", "blur", "distance", "direction",
      ])
      Some(ShadowSpec::{
        color: required_string(table, "\{path}.color", key="color"),
        blur: required_double(table, "\{path}.blur", key="blur"),
        distance: required_double(table, "\{path}.distance", key="distance"),
        direction: required_double(table, "\{path}.direction", key="direction"),
      })
    }
  }
}

///|
fn parse_optional_crop_rect(
  value : @toml.TomlValue?,
  path : String,
) -> CropRect? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["left", "top", "right", "bottom"])
      Some(CropRect::{
        left: required_double(table, "\{path}.left", key="left"),
        top: required_double(table, "\{path}.top", key="top"),
        right: required_double(table, "\{path}.right", key="right"),
        bottom: required_double(table, "\{path}.bottom", key="bottom"),
      })
    }
  }
}

///|
fn parse_icon_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> IconSpec raise {
  reject_unknown_fields(table, path, ["name", "fill"])
  IconSpec::{
    name: required_string(table, "\{path}.name", key="name"),
    fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
  }
}

///|
fn parse_table_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> TableSpec raise {
  reject_unknown_fields(table, path, [
    "style", "col_widths", "row_heights", "rows", "data",
  ])
  let rows = match (table.get("rows"), table.get("data")) {
    (Some(_), Some(_)) => fail("\{path}: use either rows or data, not both")
    (Some(rows), None) => parse_table_rows(rows, "\{path}.rows")
    (None, Some(data)) => parse_table_data(data, "\{path}.data")
    (None, None) => fail("\{path}: missing rows or data")
  }
  TableSpec::{
    style: optional_string(table.get("style"), "\{path}.style"),
    col_widths: parse_optional_double_array(
      table.get("col_widths"),
      "\{path}.col_widths",
    ),
    row_heights: parse_optional_double_array(
      table.get("row_heights"),
      "\{path}.row_heights",
    ),
    rows,
  }
}

///|
fn parse_chart_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ChartSpec raise {
  reject_unknown_fields(table, path, [
    "kind", "title", "legend", "style", "data_labels", "data_table", "rounded_corners",
    "categories", "series", "data",
  ])
  let kind = required_string(table, "\{path}.kind", key="kind")
  let (categories, series) = match table.get("data") {
    None =>
      (
        parse_optional_string_array(
          table.get("categories"),
          "\{path}.categories",
        ),
        parse_chart_series_array(
          required_array(table, "\{path}.series", key="series"),
          "\{path}.series",
        ),
      )
    Some(data) => {
      if table.get("categories") is Some(_) || table.get("series") is Some(_) {
        fail("\{path}: data cannot be combined with categories or series")
      }
      if kind == "scatter" || kind == "bubble" {
        fail("\{path}.data: data shorthand is only for category charts")
      }
      parse_chart_data(data, "\{path}.data")
    }
  }
  ChartSpec::{
    kind,
    title: optional_string(table.get("title"), "\{path}.title"),
    legend: optional_string(table.get("legend"), "\{path}.legend"),
    style: optional_int_or_none(table.get("style"), "\{path}.style"),
    data_labels: optional_string(
      table.get("data_labels"),
      "\{path}.data_labels",
    ),
    data_table: optional_bool(table.get("data_table"), "\{path}.data_table"),
    rounded_corners: optional_bool(
      table.get("rounded_corners"),
      "\{path}.rounded_corners",
    ),
    categories,
    series,
  }
}

///|
fn parse_chart_data(
  value : @toml.TomlValue,
  path : String,
) -> (Array[String]?, Array[ChartSeriesSpec]) raise {
  match value {
    @toml.TomlArray(rows) => {
      if rows.length() < 2 {
        fail("\{path}: expected a header row and at least one series row")
      }
      let header = expect_chart_data_row(rows[0], "\{path}[0]")
      if header.length() < 2 {
        fail("\{path}[0]: expected at least one category")
      }
      let categories = []
      for index in 1..<header.length() {
        categories.push(expect_string(header[index], "\{path}[0][\{index}]"))
      }
      let series = []
      for row_index in 1..<rows.length() {
        let row_path = "\{path}[\{row_index}]"
        let row = expect_chart_data_row(rows[row_index], row_path)
        if row.length() != header.length() {
          fail("\{row_path}: expected \{header.length()} cells")
        }
        let values = []
        for value_index in 1..<row.length() {
          values.push(
            expect_double(row[value_index], "\{row_path}[\{value_index}]"),
          )
        }
        series.push(ChartSeriesSpec::{
          name: expect_string(row[0], "\{row_path}[0]"),
          values,
          x_values: None,
          bubble_sizes: None,
        })
      }
      (Some(categories), series)
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn expect_chart_data_row(
  value : @toml.TomlValue,
  path : String,
) -> Array[@toml.TomlValue] raise {
  match value {
    @toml.TomlArray(values) => values
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_chart_series_array(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[ChartSeriesSpec] raise {
  let series = []
  for index, value in values {
    let series_path = "\{path}[\{index}]"
    let table = expect_table(value, series_path)
    reject_unknown_fields(table, series_path, [
      "name", "values", "x_values", "bubble_sizes",
    ])
    series.push(ChartSeriesSpec::{
      name: required_string(table, "\{series_path}.name", key="name"),
      values: parse_double_array(
        required_array(table, "\{series_path}.values", key="values"),
        "\{series_path}.values",
      ),
      x_values: parse_optional_double_array(
        table.get("x_values"),
        "\{series_path}.x_values",
      ),
      bubble_sizes: parse_optional_double_array(
        table.get("bubble_sizes"),
        "\{series_path}.bubble_sizes",
      ),
    })
  }
  series
}

///|
fn parse_table_rows(
  value : @toml.TomlValue,
  path : String,
) -> Array[TableRowSpec] raise {
  match value {
    @toml.TomlArray(items) => {
      let rows = []
      for index, item in items {
        let row_path = "\{path}[\{index}]"
        let table = expect_table(item, row_path)
        reject_unknown_fields(table, row_path, ["cells"])
        rows.push(TableRowSpec::{
          cells: parse_table_cells(
            required_array(table, "\{row_path}.cells", key="cells"),
            "\{row_path}.cells",
          ),
        })
      }
      rows
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_table_data(
  value : @toml.TomlValue,
  path : String,
) -> Array[TableRowSpec] raise {
  match value {
    @toml.TomlArray(rows) => {
      let result = []
      for row_index, row_value in rows {
        match row_value {
          @toml.TomlArray(cells) => {
            let parsed_cells = []
            for cell_index, cell_value in cells {
              parsed_cells.push(TableCellSpec::{
                text: expect_string(
                  cell_value,
                  "\{path}[\{row_index}][\{cell_index}]",
                ),
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              })
            }
            result.push(TableRowSpec::{ cells: parsed_cells })
          }
          _ => fail("\{path}[\{row_index}]: expected array")
        }
      }
      result
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_table_cells(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[TableCellSpec] raise {
  let cells = []
  for index, value in values {
    cells.push(parse_table_cell(value, "\{path}[\{index}]"))
  }
  cells
}

///|
fn parse_table_cell(
  value : @toml.TomlValue,
  path : String,
) -> TableCellSpec raise {
  match value {
    @toml.TomlString(text) =>
      TableCellSpec::{
        text,
        fill: None,
        border: None,
        col_span: 1,
        row_span: 1,
        align: None,
        margin: None,
      }
    @toml.TomlTable(table) => {
      reject_unknown_fields(table, path, [
        "text", "fill", "border", "col_span", "row_span", "align", "margin",
      ])
      TableCellSpec::{
        text: required_string(table, "\{path}.text", key="text"),
        fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
        border: parse_optional_border(table.get("border"), "\{path}.border"),
        col_span: optional_int(
          table.get("col_span"),
          "\{path}.col_span",
          default=1,
        ),
        row_span: optional_int(
          table.get("row_span"),
          "\{path}.row_span",
          default=1,
        ),
        align: parse_optional_align(table.get("align"), "\{path}.align"),
        margin: parse_optional_table_cell_margin(
          table.get("margin"),
          "\{path}.margin",
        ),
      }
    }
    _ => fail("\{path}: expected string or table")
  }
}

///|
fn parse_optional_table_cell_margin(
  value : @toml.TomlValue?,
  path : String,
) -> TableCellMargin? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["left", "right", "top", "bottom"])
      Some(TableCellMargin::{
        left: optional_double(table.get("left"), "\{path}.left"),
        right: optional_double(table.get("right"), "\{path}.right"),
        top: optional_double(table.get("top"), "\{path}.top"),
        bottom: optional_double(table.get("bottom"), "\{path}.bottom"),
      })
    }
  }
}

///|
fn parse_optional_align(
  value : @toml.TomlValue?,
  path : String,
) -> Align? raise {
  match value {
    None => None
    Some(
      @toml.TomlArray(
        [@toml.TomlString(horizontal), @toml.TomlString(vertical)]
      )
    ) => Some(Align::{ horizontal, vertical })
    Some(_) => fail("\{path}: expected [horizontal, vertical]")
  }
}

///|
fn parse_optional_fill(value : @toml.TomlValue?, path : String) -> Fill? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      match required_string(table, "\{path}.type", key="type") {
        "solid" => {
          reject_unknown_fields(table, path, ["type", "color"])
          Some(SolidFill(required_string(table, "\{path}.color", key="color")))
        }
        "gradient" => {
          reject_unknown_fields(table, path, ["type", "direction", "stops"])
          Some(GradientFill(parse_gradient(table, path)))
        }
        "none" => {
          reject_unknown_fields(table, path, ["type"])
          Some(NoFill)
        }
        kind => fail("\{path}.type: unsupported fill type '\{kind}'")
      }
    }
  }
}

///|
fn parse_optional_border(
  value : @toml.TomlValue?,
  path : String,
) -> Border? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      reject_unknown_fields(table, path, ["style", "width", "color"])
      Some(Border::{
        style: required_string(table, "\{path}.style", key="style"),
        width: required_double(table, "\{path}.width", key="width"),
        color: required_string(table, "\{path}.color", key="color"),
      })
    }
  }
}

///|
fn parse_image_fit(value : String?, path : String) -> ImageFit raise {
  match value {
    None => StretchFit
    Some("cover") => CoverFit
    Some("contain") => ContainFit
    Some("stretch") => StretchFit
    Some(other) => fail("\{path}: unsupported image fit '\{other}'")
  }
}

///|
fn parse_size(values : Array[@toml.TomlValue], path : String) -> Size raise {
  guard values.length() == 2 else { fail("\{path}: expected [width, height]") }
  Size::{
    width: expect_double(values[0], "\{path}[0]"),
    height: expect_double(values[1], "\{path}[1]"),
  }
}

///|
fn parse_bounds(values : Array[@toml.TomlValue], path : String) -> Bounds raise {
  guard values.length() == 4 else {
    fail("\{path}: expected [x, y, width, height]")
  }
  Bounds::{
    x: expect_double(values[0], "\{path}[0]"),
    y: expect_double(values[1], "\{path}[1]"),
    width: expect_double(values[2], "\{path}[2]"),
    height: expect_double(values[3], "\{path}[3]"),
  }
}

///|
fn required_string(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> String raise {
  match table.get(key) {
    Some(value) => expect_string(value, path)
    None => fail("\{path}: missing required string")
  }
}

///|
fn required_double(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Double raise {
  match table.get(key) {
    Some(value) => expect_double(value, path)
    None => fail("\{path}: missing required number")
  }
}

///|
fn required_array(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Array[@toml.TomlValue] raise {
  match table.get(key) {
    Some(@toml.TomlArray(values)) => values
    Some(_) => fail("\{path}: expected array")
    None => fail("\{path}: missing required array")
  }
}

///|
fn parse_optional_double_array(
  value : @toml.TomlValue?,
  path : String,
) -> Array[Double]? raise {
  match value {
    None => None
    Some(@toml.TomlArray(values)) => Some(parse_double_array(values, path))
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn parse_double_array(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[Double] raise {
  let result = []
  for index, item in values {
    result.push(expect_double(item, "\{path}[\{index}]"))
  }
  result
}

///|
fn parse_optional_string_array(
  value : @toml.TomlValue?,
  path : String,
) -> Array[String]? raise {
  match value {
    None => None
    Some(@toml.TomlArray(values)) => {
      let result = []
      for index, item in values {
        result.push(expect_string(item, "\{path}[\{index}]"))
      }
      Some(result)
    }
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn required_table(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Map[String, @toml.TomlValue] raise {
  match table.get(key) {
    Some(value) => expect_table(value, path)
    None => fail("\{path}: missing required table")
  }
}

///|
fn optional_string(value : @toml.TomlValue?, path : String) -> String? raise {
  match value {
    None => None
    Some(value) => Some(expect_string(value, path))
  }
}

///|
fn optional_double(value : @toml.TomlValue?, path : String) -> Double? raise {
  match value {
    None => None
    Some(value) => Some(expect_double(value, path))
  }
}

///|
fn optional_int(
  value : @toml.TomlValue?,
  path : String,
  default~ : Int,
) -> Int raise {
  match value {
    None => default
    Some(value) => expect_int(value, path)
  }
}

///|
fn optional_int_or_none(value : @toml.TomlValue?, path : String) -> Int? raise {
  match value {
    None => None
    Some(value) => Some(expect_int(value, path))
  }
}

///|
fn optional_bool(value : @toml.TomlValue?, path : String) -> Bool? raise {
  match value {
    None => None
    Some(@toml.TomlBoolean(value)) => Some(value)
    Some(_) => fail("\{path}: expected boolean")
  }
}

///|
fn expect_string(value : @toml.TomlValue, path : String) -> String raise {
  match value {
    @toml.TomlString(text) => text
    _ => fail("\{path}: expected string")
  }
}

///|
fn expect_double(value : @toml.TomlValue, path : String) -> Double raise {
  match value {
    @toml.TomlInteger(number) => number.to_double()
    @toml.TomlFloat(number) => number
    _ => fail("\{path}: expected number")
  }
}

///|
fn expect_int(value : @toml.TomlValue, path : String) -> Int raise {
  match value {
    @toml.TomlInteger(number) => number.to_int()
    _ => fail("\{path}: expected integer")
  }
}

///|
fn expect_table(
  value : @toml.TomlValue,
  path : String,
) -> Map[String, @toml.TomlValue] raise {
  match value {
    @toml.TomlTable(table) => table
    _ => fail("\{path}: expected table")
  }
}

///|
fn reject_unknown_fields(
  table : Map[String, @toml.TomlValue],
  path : String,
  allowed : Array[String],
) -> Unit raise {
  for key, _ in table {
    if !field_allowed(key, allowed) {
      fail("\{path}.\{key}: unknown field")
    }
  }
}

///|
fn field_allowed(key : String, allowed : Array[String]) -> Bool {
  for item in allowed {
    if key == item {
      return true
    }
  }
  false
}
