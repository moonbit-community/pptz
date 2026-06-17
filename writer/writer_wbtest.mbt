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
using @parser {parse_page_yaml}

///|
using @loader {load_deck}

///|
using @model {
  type Align,
  type ChartSeriesSpec,
  type Deck,
  type Page,
  type PageRef,
  type Size,
  type TableCellMargin,
  type TableRowSpec,
  type TextStyle,
  type Theme,
}

///|
test "render minimal deck as pptx bytes" {
  let loaded = load_deck("examples/minimal/deck.pptz.yaml") catch {
    err => abort("load failed: \{err}")
  }
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  assert_openxml_pptx(bytes, slide_count=4)
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  let slides = prs.slides() catch {
    err => abort("read generated slides failed: \{err}")
  }
  assert_eq(slides.length(), 4)
  assert_true(slides[0].shapes.length() >= 2)
  assert_slide_xml_contains(prs, 2, "<a:tbl>")
  assert_slide_xml_contains(prs, 2, "<a:t>Metrics</a:t>")
  let charts = prs.charts() catch {
    err => abort("read generated charts failed: \{err}")
  }
  assert_true(charts.length() >= 1)
  assert_true(count_pictures(slides[3]) >= 4)
  assert_slide_xml_contains(prs, 1, "<p:bg>")
  assert_slide_xml_contains(prs, 1, "<a:gradFill")
  assert_slide_xml_contains(prs, 3, "prst=\"roundRect\"")
  assert_slide_xml_contains(prs, 3, "prst=\"diamond\"")
  assert_slide_xml_contains(prs, 3, "<a:gradFill")
  assert_slide_xml_contains(prs, 3, "alpha val=\"80000\"")
  assert_slide_xml_contains(prs, 3, "prstDash val=\"dash\"")
  assert_slide_xml_contains(prs, 3, "<p:cxnSp>")
  assert_slide_xml_contains(prs, 3, "<a:tailEnd type=\"triangle\"")
  assert_slide_xml_contains(prs, 3, "<a:outerShdw")
  assert_slide_xml_contains(prs, 3, "name=\"cube_icon\"")
  assert_slide_xml_contains(prs, 3, "prst=\"cube\"")
  assert_slide_xml_contains(prs, 3, "spcPct val=\"115000\"")
  assert_slide_xml_contains(prs, 3, "wrap=\"square\"")
  assert_slide_xml_contains(prs, 3, "<a:br>")
}

///|
test "writer renders icon elements" {
  let loaded = unsupported_loaded(
    page_with_element(
      IconElement(test_base("icon"), IconSpec::{
        name: "fas:cube",
        fill: Some(SolidFill("#F59E0B")),
      }),
    ),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "name=\"icon\"")
  assert_slide_xml_contains(prs, 1, "prst=\"cube\"")
  assert_slide_xml_contains(prs, 1, "val=\"F59E0B\"")
}

///|
test "writer renders table elements" {
  let loaded = unsupported_loaded(
    page_with_element(TableElement(test_base("table"), test_table_spec())),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "<a:tbl>")
  assert_slide_xml_contains(prs, 1, "<a:gridCol")
  assert_slide_xml_contains(prs, 1, "<a:t>A</a:t>")
  assert_slide_xml_contains(prs, 1, "<a:solidFill>")
  assert_slide_xml_contains(prs, 1, "<a:lnL")
}

///|
test "writer renders chart elements" {
  let loaded = unsupported_loaded(
    page_with_element(ChartElement(test_base("chart"), test_chart_spec())),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  let charts = prs.charts() catch {
    err => abort("read generated charts failed: \{err}")
  }
  assert_eq(charts.length(), 1)
  assert_slide_xml_contains(prs, 1, "<c:chart")
  assert_chart_xml_contains(prs, 1, "Revenue")
  assert_chart_xml_contains(prs, 1, "<c:legendPos val=\"b\"/>")
  assert_chart_xml_contains(prs, 1, "<c:dLblPos val=\"outEnd\"/>")
  assert_chart_xml_contains(prs, 1, "<c:style val=\"4\"/>")
}

///|
test "writer renders table merge spans" {
  let loaded = unsupported_loaded(
    page_with_element(
      TableElement(test_base("merged_table"), test_merged_table_spec()),
    ),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "gridSpan=\"2\"")
  assert_slide_xml_contains(prs, 1, "rowSpan=\"2\"")
  assert_slide_xml_contains(prs, 1, "hMerge=\"1\"")
  assert_slide_xml_contains(prs, 1, "vMerge=\"1\"")
}

///|
test "writer maps expanded connector kinds" {
  let cases = [
    ("straight", "straightConnector1"),
    ("bent2", "bentConnector2"),
    ("bent3", "bentConnector3"),
    ("bent4", "bentConnector4"),
    ("bent5", "bentConnector5"),
    ("curved2", "curvedConnector2"),
    ("curved3", "curvedConnector3"),
    ("curved4", "curvedConnector4"),
    ("curved5", "curvedConnector5"),
  ]
  for item in cases {
    let (kind, xml_name) = item
    let loaded = unsupported_loaded(
      page_with_element(
        ConnectorElement(kind, ConnectorSpec::{
          kind,
          start: CoordinateEndpoint(100.0, 100.0),
          end: CoordinateEndpoint(320.0, 180.0),
          stroke: None,
          start_arrow: None,
          end_arrow: None,
          shadow: None,
        }),
      ),
    )
    let bytes = render_pptx(loaded) catch {
      err => abort("render \{kind} failed: \{err}")
    }
    let prs = @presentation.Presentation::open(bytes) catch {
      err => abort("open generated \{kind} pptx failed: \{err}")
    }
    assert_slide_xml_contains(prs, 1, "prst=\"\{xml_name}\"")
  }
}

///|
test "writer auto anchors element connectors to facing edges" {
  let shape_bounds : Map[String, Bounds] = {}
  shape_bounds["left"] = Bounds::{
    x: 100.0,
    y: 100.0,
    width: 200.0,
    height: 80.0,
  }
  shape_bounds["right"] = Bounds::{
    x: 500.0,
    y: 120.0,
    width: 120.0,
    height: 100.0,
  }
  shape_bounds["bottom"] = Bounds::{
    x: 140.0,
    y: 320.0,
    width: 160.0,
    height: 80.0,
  }
  let left_start = connector_endpoint_point(
    ElementEndpoint("left"),
    ElementEndpoint("right"),
    shape_bounds,
  ) catch {
    err => abort("resolve left endpoint failed: \{err}")
  }
  assert_eq(left_start.x, 300.0)
  assert_eq(left_start.y, 140.0)
  let right_end = connector_endpoint_point(
    ElementEndpoint("right"),
    ElementEndpoint("left"),
    shape_bounds,
  ) catch {
    err => abort("resolve right endpoint failed: \{err}")
  }
  assert_eq(right_end.x, 500.0)
  assert_eq(right_end.y, 170.0)
  let bottom_end = connector_endpoint_point(
    ElementEndpoint("bottom"),
    ElementEndpoint("left"),
    shape_bounds,
  ) catch {
    err => abort("resolve bottom endpoint failed: \{err}")
  }
  assert_eq(bottom_end.x, 220.0)
  assert_eq(bottom_end.y, 320.0)
  shape_bounds["wide"] = Bounds::{
    x: 200.0,
    y: 40.0,
    width: 320.0,
    height: 120.0,
  }
  shape_bounds["lower_right"] = Bounds::{
    x: 620.0,
    y: 280.0,
    width: 160.0,
    height: 90.0,
  }
  let wide_start = connector_endpoint_point(
    ElementEndpoint("wide"),
    ElementEndpoint("lower_right"),
    shape_bounds,
  ) catch {
    err => abort("resolve wide endpoint failed: \{err}")
  }
  assert_eq(wide_start.x, 360.0)
  assert_eq(wide_start.y, 160.0)
}

///|
test "writer respects explicit connector anchors" {
  let shape_bounds : Map[String, Bounds] = {}
  shape_bounds["box"] = Bounds::{
    x: 100.0,
    y: 100.0,
    width: 200.0,
    height: 80.0,
  }
  let point = connector_endpoint_point(
    AnchoredElementEndpoint("box", BottomAnchor),
    CoordinateEndpoint(700.0, 100.0),
    shape_bounds,
  ) catch {
    err => abort("resolve anchored endpoint failed: \{err}")
  }
  assert_eq(point.x, 200.0)
  assert_eq(point.y, 180.0)
}

///|
test "writer maps expanded icon names" {
  let cases = [
    ("fas:home", "actionButtonHome"),
    ("fas:info", "actionButtonInformation"),
    ("fas:sun", "sun"),
    ("fas:gear6", "gear6"),
    ("fas:chart_plus", "chartPlus"),
  ]
  for item in cases {
    let (name, xml_name) = item
    let loaded = unsupported_loaded(
      page_with_element(
        IconElement(test_base(xml_name), IconSpec::{
          name,
          fill: Some(SolidFill("#F59E0B")),
        }),
      ),
    )
    let bytes = render_pptx(loaded) catch {
      err => abort("render \{name} failed: \{err}")
    }
    let prs = @presentation.Presentation::open(bytes) catch {
      err => abort("open generated \{name} pptx failed: \{err}")
    }
    assert_slide_xml_contains(prs, 1, "prst=\"\{xml_name}\"")
  }
}

///|
test "writer preserves existing output when render fails" {
  let output = "examples/testdata/out/atomic-demo.pptx"
  let loaded = load_deck("examples/minimal/deck.pptz.yaml") catch {
    err => abort("load failed: \{err}")
  }
  write_pptx_file(loaded, output) catch {
    err => abort("initial write failed: \{err}")
  }
  let before = @miniio.read_file(output) catch {
    err => abort("read initial output failed: \{err}")
  }
  assert_openxml_pptx(before.binary().to_fixedarray(), slide_count=4)
  let failing = unsupported_loaded(Page::{
    page_type: None,
    layout: None,
    slots: Map([], capacity=0),
    background: None,
    components: [],
    elements: [
      IconElement(test_base("icon"), IconSpec::{
        name: "fas:dragon",
        fill: Some(SolidFill("#F59E0B")),
      }),
    ],
  })
  ignore(
    write_pptx_file(failing, output) catch {
      WriteError::Capability(_) => ()
      err => abort("expected capability error, got \{err}")
    },
  )
  let after = @miniio.read_file(output) catch {
    err => abort("read final output failed: \{err}")
  }
  assert_openxml_pptx(after.binary().to_fixedarray(), slide_count=4)
  assert_false(
    @miniio.exists("examples/testdata/out/.atomic-demo.pptx.tmp-1") catch {
      _ => false
    },
  )
  @miniio.remove_file(output) catch {
    _ => ()
  }
}

///|
test "writer renders image page backgrounds behind elements" {
  let loaded = load_deck("examples/testdata/image-background.pptz.yaml") catch {
    err => abort("load failed: \{err}")
  }
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  assert_openxml_pptx(bytes, slide_count=1)
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  let slides = prs.slides() catch {
    err => abort("read generated slides failed: \{err}")
  }
  assert_true(slides[0].shapes.length() >= 2)
  match slides[0].shapes[0] {
    @slide.Picture(_) => ()
    _ => abort("expected background image to be first shape")
  }
  assert_slide_xml_contains(prs, 1, "Image background")
}

///|
test "writer maps preset shape names" {
  let cases = [
    ("diamond", "diamond"),
    ("triangle", "triangle"),
    ("right_triangle", "rtTriangle"),
    ("parallelogram", "parallelogram"),
    ("trapezoid", "trapezoid"),
    ("pentagon", "pentagon"),
    ("hexagon", "hexagon"),
    ("octagon", "octagon"),
    ("chevron", "chevron"),
    ("right_arrow", "rightArrow"),
    ("left_arrow", "leftArrow"),
    ("up_arrow", "upArrow"),
    ("down_arrow", "downArrow"),
    ("plus", "plus"),
    ("star5", "star5"),
    ("flow_chart_process", "flowChartProcess"),
    ("flow_chart_connector", "flowChartConnector"),
    ("action_button_home", "actionButtonHome"),
    ("accent_border_callout2", "accentBorderCallout2"),
    ("round2_diag_rect", "round2DiagRect"),
    ("math_not_equal", "mathNotEqual"),
    ("no_smoking", "noSmoking"),
  ]
  for item in cases {
    let (shape_name, xml_name) = item
    let loaded = unsupported_loaded(
      page_with_element(
        ShapeElement(test_base(shape_name), ShapeSpec::{
          shape: shape_name,
          fill: Some(SolidFill("#3B82F6")),
          border: None,
          shadow: None,
          text: None,
        }),
      ),
    )
    let bytes = render_pptx(loaded) catch {
      err => abort("render \{shape_name} failed: \{err}")
    }
    let prs = @presentation.Presentation::open(bytes) catch {
      err => abort("open generated \{shape_name} pptx failed: \{err}")
    }
    assert_slide_xml_contains(prs, 1, "prst=\"\{xml_name}\"")
  }
}

///|
test "writer renders text inside shape" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "card"
      #|    type: "shape"
      #|    bounds: [80, 120, 520, 280]
      #|    content:
      #|      shape: "round_rect"
      #|      fill: { type: "solid", color: "#0F172A" }
      #|      border: { style: "solid", width: 1, color: "#475569" }
      #|      text:
      #|        font_size: 28
      #|        font_family: "Aptos Mono"
      #|        color: "#F8FAFC"
      #|        align: ["left", "top"]
      #|        body:
      #|          inset: { left: 28, right: 28, top: 24, bottom: 24 }
      #|        text: |-
      #|          enum Result[T, E] {
      #|            Ok(T)
      #|            Err(E)
      #|          }
    ),
  ) catch {
    err => abort("parse shape text page failed: \{err}")
  }
  let bytes = render_pptx(unsupported_loaded(page)) catch {
    err => abort("render shape text failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated shape text pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "prst=\"roundRect\"")
  assert_slide_xml_contains(prs, 1, "<a:t>enum Result[T, E] {</a:t>")
  assert_slide_xml_contains(prs, 1, "lIns=\"266700\"")
}

///|
test "writer maps text wrap false" {
  let loaded = unsupported_loaded(
    page_with_element(
      TextElement(test_base("nowrap"), TextContent::{
        text: "No wrap",
        style: None,
        align: None,
        wrap: Some(false),
        body: None,
        paragraphs: None,
        font_size: None,
        font_family: None,
        color: None,
        bold: None,
        italic: None,
      }),
    ),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "wrap=\"none\"")
}

///|
test "writer enables shrink autofit for text by default" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "default_autofit"
      #|    type: "text"
      #|    bounds: [80, 120, 240, 60]
      #|    content:
      #|      text: "Default autofit"
    ),
  ) catch {
    err => abort("parse text page failed: \{err}")
  }
  let loaded = unsupported_loaded(page)
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "<a:normAutofit")
  assert_slide_xml_contains(prs, 1, "fontScale=\"100000\"")
}

///|
test "writer can disable default text autofit" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "manual_overflow"
      #|    type: "text"
      #|    bounds: [80, 120, 240, 60]
      #|    content:
      #|      text: "No autofit"
      #|      body:
      #|        auto_fit: "none"
    ),
  ) catch {
    err => abort("parse text page failed: \{err}")
  }
  let loaded = unsupported_loaded(page)
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "<a:noAutofit/>")
}

///|
test "writer renders text letter spacing" {
  let loaded = unsupported_loaded(
    page_with_element(
      TextElement(test_base("spacing_text"), TextContent::{
        text: "Spacing",
        style: Some("$spaced"),
        align: None,
        wrap: None,
        body: None,
        paragraphs: None,
        font_size: None,
        font_family: None,
        color: None,
        bold: None,
        italic: None,
      }),
    ),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "spc=\"100\"")
}

///|
test "writer renders rich text paragraphs runs and body options" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "copy"
      #|    type: "text"
      #|    bounds: [80, 120, 640, 240]
      #|    content:
      #|      style: "$body"
      #|      align: ["left", "top"]
      #|      wrap: true
      #|      body:
      #|        auto_fit: "shape"
      #|        inset:
      #|          left: 12
      #|          right: 12
      #|          top: 8
      #|          bottom: 8
      #|      paragraphs:
      #|        - text: "Overview"
      #|          space_after: 6
      #|          margin_left: 18
      #|          indent: -9
      #|          bullet:
      #|            kind: "char"
      #|            char: "-"
      #|        - space_before: 4
      #|          runs:
      #|            - text: "Read "
      #|            - text: "docs"
      #|              style: "$link"
      #|              hyperlink: "https://example.com"
      #|              tooltip: "Documentation"
    ),
  ) catch {
    err => abort("parse rich text page failed: \{err}")
  }
  let loaded = unsupported_loaded(page)
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "<a:t>Overview</a:t>")
  assert_slide_xml_contains(prs, 1, "<a:t>docs</a:t>")
  assert_slide_xml_contains(prs, 1, "<a:buChar char=\"-\"")
  assert_slide_xml_contains(prs, 1, "<a:spAutoFit/>")
  assert_slide_xml_contains(prs, 1, "lIns=\"114300\"")
  assert_slide_xml_contains(prs, 1, "marL=\"171450\"")
  assert_slide_xml_contains(prs, 1, "indent=\"-85725\"")
  assert_slide_xml_contains(prs, 1, "<a:hlinkClick")
  assert_slide_xml_contains(prs, 1, "tooltip=\"Documentation\"")
}

///|
test "writer applies table styles" {
  let loaded = unsupported_loaded(
    page_with_element(
      TableElement(test_base("styled_table"), TableSpec::{
        style: Some("$compact"),
        col_widths: Some([120.0, 120.0]),
        row_heights: Some([36.0, 36.0]),
        rows: [
          TableRowSpec::{
            cells: [
              TableCellSpec::{
                text: "Metric",
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              },
              TableCellSpec::{
                text: "Value",
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              },
            ],
          },
          TableRowSpec::{
            cells: [
              TableCellSpec::{
                text: "Revenue",
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              },
              TableCellSpec::{
                text: "100",
                fill: None,
                border: None,
                col_span: 1,
                row_span: 1,
                align: None,
                margin: None,
              },
            ],
          },
        ],
      }),
    ),
  )
  let bytes = render_pptx(loaded) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_slide_xml_contains(prs, 1, "<a:t>Metric</a:t>")
  assert_slide_xml_contains(prs, 1, "val=\"334155\"")
  assert_slide_xml_contains(prs, 1, "val=\"F8FAFC\"")
  assert_slide_xml_contains(prs, 1, "val=\"0F172A\"")
  assert_slide_xml_contains(prs, 1, "val=\"CBD5E1\"")
  assert_slide_xml_contains(prs, 1, "sz=\"1400\"")
}

///|
test "writer renders chart data shorthand" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "chart"
      #|    type: "chart"
      #|    bounds: [80, 120, 720, 360]
      #|    content:
      #|      kind: "bar"
      #|      data:
      #|        - ["", "Q1", "Q2"]
      #|        - ["Revenue", 100, 200]
    ),
  ) catch {
    err => abort("parse chart shorthand failed: \{err}")
  }
  let bytes = render_pptx(unsupported_loaded(page)) catch {
    err => abort("render failed: \{err}")
  }
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  assert_chart_xml_contains(prs, 1, "Revenue")
  assert_chart_xml_contains(prs, 1, "Q2")
  assert_chart_xml_contains(prs, 1, "<c:v>200</c:v>")
}

///|
test "writer reports capability errors for unsupported schema-valid features" {
  expect_capability(
    unsupported_loaded(
      page_with_element(
        IconElement(test_base("icon"), IconSpec::{
          name: "fas:dragon",
          fill: Some(SolidFill("#F59E0B")),
        }),
      ),
    ),
    "icon 'fas:dragon'",
  )
  expect_capability(
    unsupported_loaded(
      page_with_element(
        ShapeElement(test_base("line"), ShapeSpec::{
          shape: "straightConnector1",
          fill: None,
          border: None,
          shadow: None,
          text: None,
        }),
      ),
    ),
    "straightConnector1",
  )
  expect_capability(
    unsupported_loaded(
      page_with_element(
        ShapeElement(test_base("connector"), ShapeSpec::{
          shape: "straight_connector1",
          fill: None,
          border: None,
          shadow: None,
          text: None,
        }),
      ),
    ),
    "connector or line",
  )
  expect_capability(
    unsupported_loaded(
      page_with_element(
        ShapeElement(test_base("zigzag_border"), ShapeSpec::{
          shape: "rect",
          fill: None,
          border: Some(Border::{ style: "zigzag", width: 2.0, color: "#F4F6FB" }),
          shadow: None,
          text: None,
        }),
      ),
    ),
    "border style 'zigzag'",
  )
}

///|
fn assert_openxml_pptx(bytes : FixedArray[Byte], slide_count~ : Int) -> Unit {
  let prs = @presentation.Presentation::open(bytes) catch {
    err => abort("open generated pptx failed: \{err}")
  }
  ignore(
    prs.pkg.require_part("/[Content_Types].xml") catch {
      err => abort("missing content types: \{err}")
    },
  )
  ignore(
    prs.pkg.require_part("/_rels/.rels") catch {
      err => abort("missing package rels: \{err}")
    },
  )
  ignore(
    prs.pkg.require_part("/ppt/presentation.xml") catch {
      err => abort("missing presentation: \{err}")
    },
  )
  for index in 1..<=slide_count {
    ignore(
      prs.pkg.require_part("/ppt/slides/slide\{index}.xml") catch {
        err => abort("missing slide \{index}: \{err}")
      },
    )
  }
  ignore(
    prs.pkg.require_part("/ppt/slides/_rels/slide1.xml.rels") catch {
      err => abort("missing slide rels: \{err}")
    },
  )
}

///|
fn count_pictures(slide : @slide.Slide) -> Int {
  let mut count = 0
  for shape in slide.shapes {
    match shape {
      @slide.Picture(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn assert_slide_xml_contains(
  prs : @presentation.Presentation,
  slide_number : Int,
  expected : String,
) -> Unit raise {
  let part = prs.pkg.require_part("/ppt/slides/slide\{slide_number}.xml") catch {
    err => abort("missing slide \{slide_number}: \{err}")
  }
  let text = part.text() catch {
    err => abort("decode slide \{slide_number}: \{err}")
  }
  assert_true(text.contains(expected))
}

///|
fn assert_chart_xml_contains(
  prs : @presentation.Presentation,
  chart_number : Int,
  expected : String,
) -> Unit raise {
  let part = prs.pkg.require_part("/ppt/charts/chart\{chart_number}.xml") catch {
    err => abort("missing chart \{chart_number}: \{err}")
  }
  let text = part.text() catch {
    err => abort("decode chart \{chart_number}: \{err}")
  }
  assert_true(text.contains(expected))
}

///|
fn expect_capability(loaded : LoadedDeck, message : String) -> Unit raise {
  ignore(
    render_pptx(loaded) catch {
      WriteError::Capability(actual) => {
        assert_true(actual.contains(message))
        return
      }
      err => abort("expected capability error, got \{err}")
    },
  )
  abort("expected capability error")
}

///|
fn unsupported_loaded(page : Page) -> LoadedDeck {
  LoadedDeck::{
    bundle: DeckBundle::{
      deck_path: "examples/minimal/deck.pptz.yaml",
      deck_dir: "examples/minimal",
      deck: Deck::{
        title: Some("Unsupported"),
        size: Size::{ width: 1280.0, height: 720.0 },
        theme: Some(Theme::{
          colors: Map::from_array([
            ("background", "#10131A"),
            ("surface", "#1C2230"),
            ("text", "#F4F6FB"),
            ("accent", "#38BDF8"),
          ]),
          text_styles: Map::from_array([
            (
              "body",
              TextStyle::{
                extends: None,
                font_size: Some(18.0),
                font_family: Some("Aptos"),
                color: Some("$text"),
                bold: None,
                italic: None,
                line_height: Some(1.2),
                letter_spacing: None,
              },
            ),
            (
              "link",
              TextStyle::{
                extends: None,
                font_size: Some(18.0),
                font_family: Some("Aptos"),
                color: Some("$accent"),
                bold: Some(true),
                italic: None,
                line_height: None,
                letter_spacing: None,
              },
            ),
            (
              "spaced",
              TextStyle::{
                extends: None,
                font_size: Some(24.0),
                font_family: Some("Aptos"),
                color: Some("$text"),
                bold: None,
                italic: None,
                line_height: Some(1.2),
                letter_spacing: Some(1.0),
              },
            ),
          ]),
          table_styles: Map::from_array([
            (
              "compact",
              TableStyle::{
                extends: None,
                font_size: Some(14.0),
                font_family: Some("Aptos"),
                header_fill: Some("#334155"),
                header_text_color: Some("#F8FAFC"),
                body_text_color: Some("#0F172A"),
                header_color: None,
                body_color: None,
                border: Some(Border::{
                  style: "solid",
                  width: 1.0,
                  color: "#CBD5E1",
                }),
              },
            ),
          ]),
          chart_styles: Map([], capacity=0),
        }),
        layouts: Map([], capacity=0),
        components: Map([], capacity=0),
        pages: [PageRef::{ path: "pages/unsupported.page.yaml" }],
      },
      pages: [
        ResolvedPage::{
          path: "pages/unsupported.page.yaml",
          full_path: "examples/minimal/pages/unsupported.page.yaml",
          page,
        },
      ],
    },
    warnings: [],
  }
}

///|
fn page_with_element(element : Element) -> Page {
  Page::{
    page_type: None,
    layout: None,
    slots: Map([], capacity=0),
    background: None,
    components: [],
    elements: [element],
  }
}

///|
fn test_table_spec() -> TableSpec {
  TableSpec::{
    style: None,
    col_widths: Some([120.0]),
    row_heights: Some([36.0]),
    rows: [
      TableRowSpec::{
        cells: [
          TableCellSpec::{
            text: "A",
            fill: Some(SolidFill("#F59E0B")),
            border: Some(Border::{
              style: "solid",
              width: 1.0,
              color: "#F4F6FB",
            }),
            col_span: 1,
            row_span: 1,
            align: Some(Align::{ horizontal: "center", vertical: "center" }),
            margin: Some(TableCellMargin::{
              left: Some(4.0),
              right: Some(4.0),
              top: Some(2.0),
              bottom: Some(2.0),
            }),
          },
        ],
      },
    ],
  }
}

///|
fn test_merged_table_spec() -> TableSpec {
  TableSpec::{
    style: None,
    col_widths: Some([80.0, 80.0, 80.0]),
    row_heights: Some([32.0, 32.0]),
    rows: [
      TableRowSpec::{
        cells: [
          TableCellSpec::{
            text: "A",
            fill: None,
            border: None,
            col_span: 2,
            row_span: 2,
            align: None,
            margin: None,
          },
          TableCellSpec::{
            text: "B",
            fill: None,
            border: None,
            col_span: 1,
            row_span: 1,
            align: None,
            margin: None,
          },
        ],
      },
      TableRowSpec::{
        cells: [
          TableCellSpec::{
            text: "C",
            fill: None,
            border: None,
            col_span: 1,
            row_span: 1,
            align: None,
            margin: None,
          },
        ],
      },
    ],
  }
}

///|
fn test_chart_spec() -> ChartSpec {
  ChartSpec::{
    chart_style: None,
    kind: "bar",
    title: Some("Revenue"),
    legend: Some("bottom"),
    style: Some(4),
    data_labels: Some("outside_end"),
    data_table: Some(false),
    rounded_corners: Some(false),
    categories: Some(["Q1", "Q2"]),
    series: [
      ChartSeriesSpec::{
        name: "Revenue",
        values: [100.0, 150.0],
        x_values: None,
        bubble_sizes: None,
      },
    ],
  }
}

///|
fn test_base(id : String) -> ElementBase {
  ElementBase::{
    id,
    bounds: Bounds::{ x: 100.0, y: 100.0, width: 240.0, height: 120.0 },
  }
}
