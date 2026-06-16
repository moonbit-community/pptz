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
      ImageBackground({
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
  {
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
