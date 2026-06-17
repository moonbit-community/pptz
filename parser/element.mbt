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
fn parse_elements(
  values : Array[SourceValue],
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
  table : Map[String, SourceValue],
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
  table : Map[String, SourceValue],
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
  table : Map[String, SourceValue],
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
  table : Map[String, SourceValue],
  path : String,
) -> ConnectorSpec raise {
  parse_connector_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_text_content(
  table : Map[String, SourceValue],
  path : String,
) -> TextContent raise {
  parse_text_content(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_shape_spec(
  table : Map[String, SourceValue],
  path : String,
) -> ShapeSpec raise {
  parse_shape_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_image_spec(
  table : Map[String, SourceValue],
  path : String,
) -> ImageSpec raise {
  parse_image_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_icon_spec(
  table : Map[String, SourceValue],
  path : String,
) -> IconSpec raise {
  parse_icon_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_table_spec(
  table : Map[String, SourceValue],
  path : String,
) -> TableSpec raise {
  parse_table_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}

///|
fn parse_required_chart_spec(
  table : Map[String, SourceValue],
  path : String,
) -> ChartSpec raise {
  parse_chart_spec(
    required_table(table, "\{path}.content", key="content"),
    "\{path}.content",
  )
}
