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
  assert_slide_xml_contains(prs, 3, "spcPct val=\"115000\"")
  assert_slide_xml_contains(prs, 3, "wrap=\"square\"")
  assert_slide_xml_contains(prs, 3, "<a:br>")
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
        name: "fas:cube",
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
          name: "fas:cube",
          fill: Some(SolidFill("#F59E0B")),
        }),
      ),
    ),
    "icon elements",
  )
  expect_capability(
    unsupported_loaded(page_with_element(TableElement(test_base("table")))),
    "table elements",
  )
  expect_capability(
    unsupported_loaded(page_with_element(ChartElement(test_base("chart")))),
    "chart elements",
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
fn test_base(id : String) -> ElementBase {
  ElementBase::{
    id,
    bounds: Bounds::{ x: 100.0, y: 100.0, width: 240.0, height: 120.0 },
  }
}
