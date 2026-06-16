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
      Some({
        color: required_string(table, "\{path}.color", key="color"),
        blur: required_double(table, "\{path}.blur", key="blur"),
        distance: required_double(table, "\{path}.distance", key="distance"),
        direction: required_double(table, "\{path}.direction", key="direction"),
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
    Some(TomlArray([TomlString(horizontal), TomlString(vertical)])) =>
      Some({ horizontal, vertical })
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
      Some({
        style: required_string(table, "\{path}.style", key="style"),
        width: required_double(table, "\{path}.width", key="width"),
        color: required_string(table, "\{path}.color", key="color"),
      })
    }
  }
}
