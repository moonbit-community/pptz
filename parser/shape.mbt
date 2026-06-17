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
fn parse_shape_spec(
  table : Map[String, SourceValue],
  path : String,
) -> ShapeSpec raise {
  reject_unknown_fields(table, path, [
    "shape", "fill", "border", "shadow", "text",
  ])
  {
    shape: required_string(table, "\{path}.shape", key="shape"),
    fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
    border: parse_optional_border(table.get("border"), "\{path}.border"),
    shadow: parse_optional_shadow(table.get("shadow"), "\{path}.shadow"),
    text: parse_optional_text_content(table.get("text"), "\{path}.text"),
  }
}
