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
  {
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
      Some({
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
      Some({
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
    Some(TomlArray(values)) => {
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
  {
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
    Some(TomlArray(values)) => {
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
  {
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
      Some({
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
