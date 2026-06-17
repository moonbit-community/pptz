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
test "parse table content rows and data shorthand" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "summary"
      #|    type: "table"
      #|    bounds: [80, 120, 720, 300]
      #|    content:
      #|      style: "$compact"
      #|      col_widths: [240, 240]
      #|      row_heights: [48, 48]
      #|      rows:
      #|        - cells:
      #|            - text: "Metric"
      #|              fill: { type: "solid", color: "$surface" }
      #|              border: { style: "solid", width: 1, color: "$text" }
      #|              align: ["center", "center"]
      #|              margin: { left: 4, right: 4 }
      #|            - "Q1"
      #|        - cells: ["Revenue", "100"]
    ),
  ) catch {
    err => abort("parse table page failed: \{err}")
  }
  match page.elements[0] {
    TableElement(base, spec) => {
      assert_eq(base.id, "summary")
      match spec.style {
        Some(style) => assert_eq(style, "$compact")
        None => abort("expected table style")
      }
      assert_eq(spec.rows.length(), 2)
      assert_eq(spec.rows[0].cells[0].text, "Metric")
      match spec.rows[0].cells[0].fill {
        Some(SolidFill(color)) => assert_eq(color, "$surface")
        _ => abort("expected cell fill")
      }
      match spec.rows[0].cells[0].margin {
        Some(margin) =>
          match margin.left {
            Some(left) => assert_eq(left, 4.0)
            None => abort("expected left margin")
          }
        None => abort("expected margin")
      }
    }
    _ => abort("expected table element")
  }
  let shorthand = parse_page_yaml(
    (
      #|elements:
      #|  - id: "shorthand"
      #|    type: "table"
      #|    bounds: [0, 0, 300, 120]
      #|    content:
      #|      data:
      #|        - ["Metric", "Q1"]
      #|        - ["Revenue", "100"]
    ),
  ) catch {
    err => abort("parse shorthand table failed: \{err}")
  }
  match shorthand.elements[0] {
    TableElement(_, spec) => assert_eq(spec.rows[1].cells[0].text, "Revenue")
    _ => abort("expected shorthand table element")
  }
}

///|
test "parse chart data shorthand" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "chart"
      #|    type: "chart"
      #|    bounds: [80, 120, 720, 360]
      #|    content:
      #|      kind: "line"
      #|      data:
      #|        - ["", "Q1", "Q2", "Q3"]
      #|        - ["Revenue", 100, 200, 150]
      #|        - ["Users", 10.0, 24.0, 32.0]
    ),
  ) catch {
    err => abort("parse chart shorthand failed: \{err}")
  }
  match page.elements[0] {
    ChartElement(_, spec) => {
      match spec.categories {
        Some(categories) => assert_eq(categories[2], "Q3")
        None => abort("expected categories")
      }
      assert_eq(spec.series.length(), 2)
      assert_eq(spec.series[1].name, "Users")
      assert_eq(spec.series[0].values[1], 200.0)
    }
    _ => abort("expected chart element")
  }
}

///|
test "parse chart content" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "revenue_chart"
      #|    type: "chart"
      #|    bounds: [80, 120, 720, 360]
      #|    content:
      #|      kind: "bar"
      #|      title: "Quarterly revenue"
      #|      legend: "bottom"
      #|      style: 5
      #|      data_labels: "outside_end"
      #|      data_table: true
      #|      rounded_corners: false
      #|      categories: ["Q1", "Q2", "Q3"]
      #|      series:
      #|        - name: "Revenue"
      #|          values: [100.0, 200.0, 150.0]
    ),
  ) catch {
    err => abort("parse chart page failed: \{err}")
  }
  match page.elements[0] {
    ChartElement(base, spec) => {
      assert_eq(base.id, "revenue_chart")
      assert_eq(spec.kind, "bar")
      match spec.categories {
        Some(categories) => assert_eq(categories[1], "Q2")
        None => abort("expected categories")
      }
      match spec.title {
        Some(title) => assert_eq(title, "Quarterly revenue")
        None => abort("expected title")
      }
      match spec.legend {
        Some(legend) => assert_eq(legend, "bottom")
        None => abort("expected legend")
      }
      match spec.style {
        Some(style) => assert_eq(style, 5)
        None => abort("expected style")
      }
      match spec.data_labels {
        Some(pos) => assert_eq(pos, "outside_end")
        None => abort("expected data labels")
      }
      match spec.data_table {
        Some(show) => assert_true(show)
        None => abort("expected data table")
      }
      match spec.rounded_corners {
        Some(value) => assert_false(value)
        None => abort("expected rounded corners")
      }
      assert_eq(spec.series[0].name, "Revenue")
      assert_eq(spec.series[0].values[2], 150.0)
    }
    _ => abort("expected chart element")
  }
}
