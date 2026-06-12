///|
test "render minimal deck as pptx bytes" {
  let loaded = load_deck("examples/minimal/deck.pptz.toml") catch {
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
  let loaded = load_deck("examples/minimal/deck.pptz.toml") catch {
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
    background: None,
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
  let loaded = load_deck("examples/testdata/image-background.pptz.toml") catch {
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
test "writer maps text wrap false" {
  let loaded = unsupported_loaded(
    page_with_element(
      TextElement(test_base("nowrap"), TextContent::{
        text: "No wrap",
        style: None,
        align: None,
        wrap: Some(false),
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
        }),
      ),
    ),
    "border style 'zigzag'",
  )
  expect_capability(
    unsupported_loaded(
      page_with_element(
        TextElement(test_base("spacing_text"), TextContent::{
          text: "Spacing",
          style: Some("$spaced"),
          align: None,
          wrap: None,
          font_size: None,
          font_family: None,
          color: None,
          bold: None,
          italic: None,
        }),
      ),
    ),
    "letter_spacing",
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
      deck_path: "examples/minimal/deck.pptz.toml",
      deck_dir: "examples/minimal",
      deck: Deck::{
        title: Some("Unsupported"),
        size: Size::{ width: 1280.0, height: 720.0 },
        theme: Some(Theme::{
          colors: Map::from_array([
            ("background", "#10131A"),
            ("surface", "#1C2230"),
            ("text", "#F4F6FB"),
          ]),
          text_styles: Map::from_array([
            (
              "spaced",
              TextStyle::{
                font_size: Some(24.0),
                font_family: Some("Liter, MiSans"),
                color: Some("$text"),
                bold: None,
                italic: None,
                line_height: Some(1.2),
                letter_spacing: Some(1.0),
              },
            ),
          ]),
          table_styles: Map([], capacity=0),
        }),
        pages: [PageRef::{ path: "pages/unsupported.page.toml" }],
      },
      pages: [
        ResolvedPage::{
          path: "pages/unsupported.page.toml",
          full_path: "examples/minimal/pages/unsupported.page.toml",
          page,
        },
      ],
    },
    warnings: [],
  }
}

///|
fn page_with_element(element : Element) -> Page {
  Page::{ page_type: None, background: None, elements: [element] }
}

///|
fn test_table_spec() -> TableSpec {
  TableSpec::{
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
