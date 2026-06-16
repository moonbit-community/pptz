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
fn parse_layouts(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, LayoutTemplate] raise {
  parse_optional_named_table_map(value, path, parse_layout)
}

///|
fn parse_layout(
  layout_table : Map[String, @toml.TomlValue],
  layout_path : String,
) -> LayoutTemplate raise {
  reject_unknown_fields(layout_table, layout_path, [
    "background", "slots", "elements",
  ])
  let elements = match layout_table.get("elements") {
    None => []
    Some(values) =>
      parse_elements(
        expect_array(values, "\{layout_path}.elements"),
        "\{layout_path}.elements",
      )
  }
  {
    background: parse_optional_background(
      layout_table.get("background"),
      "\{layout_path}.background",
    ),
    slots: parse_layout_slots(layout_table.get("slots"), "\{layout_path}.slots"),
    elements,
  }
}

///|
fn parse_layout_slots(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, LayoutSlot] raise {
  parse_optional_named_table_map(value, path, parse_layout_slot)
}

///|
fn parse_layout_slot(
  slot_table : Map[String, @toml.TomlValue],
  slot_path : String,
) -> LayoutSlot raise {
  reject_unknown_fields(slot_table, slot_path, ["bounds", "style", "align"])
  {
    bounds: parse_bounds(
      required_array(slot_table, "\{slot_path}.bounds", key="bounds"),
      "\{slot_path}.bounds",
    ),
    style: optional_string(slot_table.get("style"), "\{slot_path}.style"),
    align: parse_optional_align(slot_table.get("align"), "\{slot_path}.align"),
  }
}

///|
fn parse_component_templates(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, ComponentTemplate] raise {
  parse_optional_named_table_map(value, path, parse_component_template)
}

///|
fn parse_component_template(
  component_table : Map[String, @toml.TomlValue],
  component_path : String,
) -> ComponentTemplate raise {
  reject_unknown_fields(component_table, component_path, ["bounds", "elements"])
  {
    bounds: parse_bounds(
      required_array(component_table, "\{component_path}.bounds", key="bounds"),
      "\{component_path}.bounds",
    ),
    elements: parse_elements(
      required_array(
        component_table,
        "\{component_path}.elements",
        key="elements",
      ),
      "\{component_path}.elements",
    ),
  }
}

///|
fn parse_component_instances(
  value : @toml.TomlValue?,
  path : String,
) -> Array[ComponentInstance] raise {
  match value {
    None => []
    Some(value) => {
      let values = expect_array(value, path)
      let result = []
      for index, value in values {
        let item_path = "\{path}[\{index}]"
        let table = expect_table(value, item_path)
        reject_unknown_fields(table, item_path, ["id", "use", "bounds", "props"])
        result.push(ComponentInstance::{
          id: required_string(table, "\{item_path}.id", key="id"),
          template: required_string(table, "\{item_path}.use", key="use"),
          bounds: parse_bounds(
            required_array(table, "\{item_path}.bounds", key="bounds"),
            "\{item_path}.bounds",
          ),
          props: parse_string_map_optional(
            table.get("props"),
            "\{item_path}.props",
          ),
        })
      }
      result
    }
  }
}
