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
fn parse_chart_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ChartSpec raise {
  reject_unknown_fields(table, path, [
    "chart_style", "kind", "title", "legend", "style", "data_labels", "data_table",
    "rounded_corners", "categories", "series", "data",
  ])
  let chart_style = optional_string(
    table.get("chart_style"),
    "\{path}.chart_style",
  )
  let kind = match table.get("kind") {
    Some(_) => required_string(table, "\{path}.kind", key="kind")
    None =>
      match chart_style {
        Some(_) => ""
        None => required_string(table, "\{path}.kind", key="kind")
      }
  }
  let (categories, series) = match table.get("data") {
    None =>
      (
        parse_optional_string_array(
          table.get("categories"),
          "\{path}.categories",
        ),
        parse_chart_series_array(
          required_array(table, "\{path}.series", key="series"),
          "\{path}.series",
        ),
      )
    Some(data) => {
      if table.get("categories") is Some(_) || table.get("series") is Some(_) {
        fail("\{path}: data cannot be combined with categories or series")
      }
      if kind == "scatter" || kind == "bubble" {
        fail("\{path}.data: data shorthand is only for category charts")
      }
      parse_chart_data(data, "\{path}.data")
    }
  }
  {
    chart_style,
    kind,
    title: optional_string(table.get("title"), "\{path}.title"),
    legend: optional_string(table.get("legend"), "\{path}.legend"),
    style: optional_int_or_none(table.get("style"), "\{path}.style"),
    data_labels: optional_string(
      table.get("data_labels"),
      "\{path}.data_labels",
    ),
    data_table: optional_bool(table.get("data_table"), "\{path}.data_table"),
    rounded_corners: optional_bool(
      table.get("rounded_corners"),
      "\{path}.rounded_corners",
    ),
    categories,
    series,
  }
}

///|
fn parse_chart_data(
  value : @toml.TomlValue,
  path : String,
) -> (Array[String]?, Array[ChartSeriesSpec]) raise {
  match value {
    TomlArray(rows) => {
      if rows.length() < 2 {
        fail("\{path}: expected a header row and at least one series row")
      }
      let header = expect_chart_data_row(rows[0], "\{path}[0]")
      if header.length() < 2 {
        fail("\{path}[0]: expected at least one category")
      }
      let categories = []
      for index in 1..<header.length() {
        categories.push(expect_string(header[index], "\{path}[0][\{index}]"))
      }
      let series = []
      for row_index in 1..<rows.length() {
        let row_path = "\{path}[\{row_index}]"
        let row = expect_chart_data_row(rows[row_index], row_path)
        if row.length() != header.length() {
          fail("\{row_path}: expected \{header.length()} cells")
        }
        let values = []
        for value_index in 1..<row.length() {
          values.push(
            expect_double(row[value_index], "\{row_path}[\{value_index}]"),
          )
        }
        series.push(ChartSeriesSpec::{
          name: expect_string(row[0], "\{row_path}[0]"),
          values,
          x_values: None,
          bubble_sizes: None,
        })
      }
      (Some(categories), series)
    }
    _ => fail("\{path}: expected array")
  }
}

///|
fn expect_chart_data_row(
  value : @toml.TomlValue,
  path : String,
) -> Array[@toml.TomlValue] raise {
  match value {
    TomlArray(values) => values
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_chart_series_array(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[ChartSeriesSpec] raise {
  let series = []
  for index, value in values {
    let series_path = "\{path}[\{index}]"
    let table = expect_table(value, series_path)
    reject_unknown_fields(table, series_path, [
      "name", "values", "x_values", "bubble_sizes",
    ])
    series.push(ChartSeriesSpec::{
      name: required_string(table, "\{series_path}.name", key="name"),
      values: parse_double_array(
        required_array(table, "\{series_path}.values", key="values"),
        "\{series_path}.values",
      ),
      x_values: parse_optional_double_array(
        table.get("x_values"),
        "\{series_path}.x_values",
      ),
      bubble_sizes: parse_optional_double_array(
        table.get("bubble_sizes"),
        "\{series_path}.bubble_sizes",
      ),
    })
  }
  series
}
