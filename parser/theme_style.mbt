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
  reject_unknown_fields(table, path, [
    "colors", "text_styles", "table_styles", "chart_styles",
  ])
  {
    colors: parse_string_map(required_table(table, "colors"), "\{path}.colors"),
    text_styles: parse_text_styles(
      required_table(table, "text_styles"),
      "\{path}.text_styles",
    ),
    table_styles: parse_table_styles(
      table.get("table_styles"),
      "\{path}.table_styles",
    ),
    chart_styles: parse_chart_styles(
      table.get("chart_styles"),
      "\{path}.chart_styles",
    ),
  }
}

///|
fn parse_text_styles(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Map[String, TextStyle] raise {
  parse_named_table_map(table, path, parse_text_style)
}

///|
fn parse_text_style(
  style_table : Map[String, @toml.TomlValue],
  style_path : String,
) -> TextStyle raise {
  reject_unknown_fields(style_table, style_path, [
    "extends", "font_size", "font_family", "color", "bold", "italic", "line_height",
    "letter_spacing",
  ])
  {
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

///|
fn parse_table_styles(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, TableStyle] raise {
  parse_optional_named_table_map(value, path, parse_table_style)
}

///|
fn parse_table_style(
  style_table : Map[String, @toml.TomlValue],
  style_path : String,
) -> TableStyle raise {
  reject_unknown_fields(style_table, style_path, [
    "extends", "font_size", "font_family", "header_fill", "header_text_color", "body_text_color",
    "header_color", "body_color", "border",
  ])
  if style_table.get("header_text_color") is Some(_) &&
    style_table.get("header_color") is Some(_) {
    fail(
      "\{style_path}: use either header_text_color or header_color, not both",
    )
  }
  if style_table.get("body_text_color") is Some(_) &&
    style_table.get("body_color") is Some(_) {
    fail("\{style_path}: use either body_text_color or body_color, not both")
  }
  {
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

///|
fn parse_chart_styles(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, ChartStyle] raise {
  parse_optional_named_table_map(value, path, parse_chart_style)
}

///|
fn parse_chart_style(
  style_table : Map[String, @toml.TomlValue],
  style_path : String,
) -> ChartStyle raise {
  reject_unknown_fields(style_table, style_path, [
    "extends", "kind", "legend", "style", "data_labels", "data_table", "rounded_corners",
  ])
  {
    extends: optional_string(
      style_table.get("extends"),
      "\{style_path}.extends",
    ),
    kind: optional_string(style_table.get("kind"), "\{style_path}.kind"),
    legend: optional_string(style_table.get("legend"), "\{style_path}.legend"),
    style: optional_int_or_none(style_table.get("style"), "\{style_path}.style"),
    data_labels: optional_string(
      style_table.get("data_labels"),
      "\{style_path}.data_labels",
    ),
    data_table: optional_bool(
      style_table.get("data_table"),
      "\{style_path}.data_table",
    ),
    rounded_corners: optional_bool(
      style_table.get("rounded_corners"),
      "\{style_path}.rounded_corners",
    ),
  }
}
