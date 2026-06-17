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
fn parse_table_spec(
  table : Map[String, SourceValue],
  path : String,
) -> TableSpec raise {
  reject_unknown_fields(table, path, [
    "style", "col_widths", "row_heights", "rows", "data",
  ])
  let rows = match (table.get("rows"), table.get("data")) {
    (Some(_), Some(_)) => fail("\{path}: use either rows or data, not both")
    (Some(rows), None) => parse_table_rows(rows, "\{path}.rows")
    (None, Some(data)) => parse_table_data(data, "\{path}.data")
    (None, None) => fail("\{path}: missing rows or data")
  }
  {
    style: optional_string(table.get("style"), "\{path}.style"),
    col_widths: parse_optional_double_array(
      table.get("col_widths"),
      "\{path}.col_widths",
    ),
    row_heights: parse_optional_double_array(
      table.get("row_heights"),
      "\{path}.row_heights",
    ),
    rows,
  }
}

///|
fn parse_table_rows(
  value : SourceValue,
  path : String,
) -> Array[TableRowSpec] raise {
  match value {
    SourceArray(items) => {
      let rows = []
      for index, item in items {
        let row_path = "\{path}[\{index}]"
        let table = expect_table(item, row_path)
        reject_unknown_fields(table, row_path, ["cells"])
        rows.push(TableRowSpec::{
          cells: parse_table_cells(
            required_array(table, "\{row_path}.cells", key="cells"),
            "\{row_path}.cells",
          ),
        })
      }
      rows
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_table_data(
  value : SourceValue,
  path : String,
) -> Array[TableRowSpec] raise {
  match value {
    SourceArray(rows) => {
      let result = []
      for row_index, row_value in rows {
        match row_value {
          SourceArray(cells) => {
            let parsed_cells = []
            for cell_index, cell_value in cells {
              parsed_cells.push(TableCellSpec::{
                text: expect_string(
                  cell_value,
                  "\{path}[\{row_index}][\{cell_index}]",
                ),
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              })
            }
            result.push(TableRowSpec::{ cells: parsed_cells })
          }
          _ => fail("\{path}[\{row_index}]: expected array")
        }
      }
      result
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_table_cells(
  values : Array[SourceValue],
  path : String,
) -> Array[TableCellSpec] raise {
  let cells = []
  for index, value in values {
    cells.push(parse_table_cell(value, "\{path}[\{index}]"))
  }
  cells
}

///|
fn parse_table_cell(value : SourceValue, path : String) -> TableCellSpec raise {
  match value {
    SourceString(text) =>
      {
        text,
        fill: None,
        border: None,
        col_span: 1,
        row_span: 1,
        align: None,
        margin: None,
      }
    SourceTable(table) => {
      reject_unknown_fields(table, path, [
        "text", "fill", "border", "col_span", "row_span", "align", "margin",
      ])
      {
        text: required_string(table, "\{path}.text", key="text"),
        fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
        border: parse_optional_border(table.get("border"), "\{path}.border"),
        col_span: optional_int(
          table.get("col_span"),
          "\{path}.col_span",
          default=1,
        ),
        row_span: optional_int(
          table.get("row_span"),
          "\{path}.row_span",
          default=1,
        ),
        align: parse_optional_align(table.get("align"), "\{path}.align"),
        margin: parse_optional_table_cell_margin(
          table.get("margin"),
          "\{path}.margin",
        ),
      }
    }
    _ => fail("\{path}: expected string or table")
  }
}

///|
fn parse_optional_table_cell_margin(
  value : SourceValue?,
  path : String,
) -> TableCellMargin? raise {
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
