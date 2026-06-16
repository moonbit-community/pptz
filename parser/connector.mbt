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
fn parse_connector_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ConnectorSpec raise {
  reject_unknown_fields(table, path, [
    "kind", "start", "end", "stroke", "start_arrow", "end_arrow", "shadow",
  ])
  {
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
    Some(TomlArray(items)) => {
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
      Some({
        style: required_string(table, "\{path}.dash", key="dash"),
        width: required_double(table, "\{path}.width", key="width"),
        color: required_string(table, "\{path}.color", key="color"),
      })
    }
  }
}
