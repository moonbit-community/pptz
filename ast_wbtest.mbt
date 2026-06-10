///|
test "deck ast covers minimal deck source" {
  let theme = Theme::{
    colors: Map::from_array([
      ("background", "#10131A"),
      ("text", "#F4F6FB"),
      ("primary", "#3B82F6"),
    ]),
    text_styles: Map::from_array([
      (
        "title",
        TextStyle::{
          font_size: Some(56),
          font_family: Some("Liter, MiSans"),
          color: Some("$text"),
          line_height: Some(1.1),
          letter_spacing: None,
        },
      ),
    ]),
    table_styles: Map([], capacity=0),
  }
  let deck = Deck::{
    title: "MoonBit PPTX Demo",
    size: Size::{ width: 1280, height: 720 },
    theme,
    pages: [
      PageRef::{ path: "pages/cover.page.toml" },
      PageRef::{ path: "pages/agenda.page.toml" },
    ],
    output: Some(Output::{ path: "dist/moonbit-pptx-demo.pptx" }),
  }
  assert_eq(deck.size.width, 1280)
  assert_eq(deck.pages.length(), 2)
  assert_eq(deck.theme.colors["text"], "#F4F6FB")
}

///|
test "page ast supports background image and text elements" {
  let page = Page::{
    page_type: Cover,
    background: Some(
      ImageBackground(ImageFill::{
        path: "../images/background.svg",
        fit: CoverFit,
      }),
    ),
    elements: [
      TextElement(
        ElementBase::{
          id: "title",
          bounds: Bounds::{ x: 100, y: 235, width: 1080, height: 95 },
        },
        TextContent::{
          text: "<p>MoonBit PPTX Demo</p>",
          style: Some("$title"),
          align: Some(Align::{ horizontal: "center", vertical: "middle" }),
          wrap: None,
          font_size: None,
          font_family: None,
          color: None,
        },
      ),
    ],
  }
  assert_eq(page.elements.length(), 1)
  match page.background {
    Some(ImageBackground(fill)) =>
      match fill.fit {
        CoverFit => ()
        _ => abort("expected cover fit")
      }
    _ => abort("expected image background")
  }
}
