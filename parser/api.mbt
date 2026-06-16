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
    TomlTable(table) => parse_deck_table(table)
    _ => fail("deck: expected top-level table")
  }
}

///|
pub fn parse_page_toml(source : String) -> Page raise {
  match @toml.parse(source) {
    TomlTable(table) => parse_page_table(table)
    _ => fail("page: expected top-level table")
  }
}

///|
fn parse_deck_table(table : Map[String, @toml.TomlValue]) -> Deck raise {
  reject_unknown_fields(table, "deck", [
    "title", "size", "theme", "layouts", "components", "pages",
  ])
  {
    title: optional_string(table.get("title"), "title"),
    size: parse_size(required_array(table, "size"), "size"),
    theme: parse_optional_theme(table.get("theme"), "theme"),
    layouts: parse_layouts(table.get("layouts"), "layouts"),
    components: parse_component_templates(table.get("components"), "components"),
    pages: parse_page_refs(required_array(table, "pages"), "pages"),
  }
}

///|
fn parse_page_table(table : Map[String, @toml.TomlValue]) -> Page raise {
  reject_unknown_fields(table, "page", [
    "page_type", "layout", "slots", "background", "components", "elements",
  ])
  {
    page_type: optional_string(table.get("page_type"), "page_type"),
    layout: optional_string(table.get("layout"), "layout"),
    slots: parse_string_map_optional(table.get("slots"), "slots"),
    background: parse_optional_background(table.get("background"), "background"),
    components: parse_component_instances(table.get("components"), "components"),
    elements: parse_elements(required_array(table, "elements"), "elements"),
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
      TomlString(text) => result[key] = text
      _ => fail("\{path}.\{key}: expected string")
    }
  }
  result
}

///|
fn parse_string_map_optional(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, String] raise {
  match value {
    None => Map([], capacity=0)
    Some(value) => parse_string_map(expect_table(value, path), path)
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
