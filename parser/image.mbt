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
fn parse_image_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ImageSpec raise {
  reject_unknown_fields(table, path, ["path", "fit", "crop"])
  {
    path: required_string(table, "\{path}.path", key="path"),
    fit: parse_image_fit(
      optional_string(table.get("fit"), "\{path}.fit"),
      "\{path}.fit",
    ),
    crop: parse_optional_crop_rect(table.get("crop"), "\{path}.crop"),
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
      Some({
        left: required_double(table, "\{path}.left", key="left"),
        top: required_double(table, "\{path}.top", key="top"),
        right: required_double(table, "\{path}.right", key="right"),
        bottom: required_double(table, "\{path}.bottom", key="bottom"),
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
