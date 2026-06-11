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
          font_size: Some(56.0),
          font_family: Some("Liter, MiSans"),
          color: Some("$text"),
          bold: Some(true),
          italic: None,
          line_height: Some(1.1),
          letter_spacing: None,
        },
      ),
    ]),
    table_styles: Map([], capacity=0),
  }
  let deck = Deck::{
    title: Some("MoonBit PPTX Demo"),
    size: Size::{ width: 1280.0, height: 720.0 },
    theme: Some(theme),
    pages: [
      PageRef::{ path: "pages/cover.page.toml" },
      PageRef::{ path: "pages/agenda.page.toml" },
    ],
  }
  assert_eq(deck.size.width, 1280.0)
  assert_eq(deck.pages.length(), 2)
  match deck.theme {
    Some(theme) => assert_eq(theme.colors["text"], "#F4F6FB")
    None => abort("expected theme")
  }
}

///|
test "page ast supports solid background and text elements" {
  let page = Page::{
    page_type: Some("cover"),
    background: Some(SolidBackground("$background")),
    elements: [
      TextElement(
        ElementBase::{
          id: "title",
          bounds: Bounds::{ x: 100.0, y: 235.0, width: 1080.0, height: 95.0 },
        },
        TextContent::{
          text: "MoonBit PPTX Demo",
          style: Some("$title"),
          align: Some(Align::{ horizontal: "center", vertical: "center" }),
          wrap: None,
          font_size: None,
          font_family: None,
          color: None,
          bold: None,
          italic: None,
        },
      ),
    ],
  }
  assert_eq(page.elements.length(), 1)
  match page.background {
    Some(SolidBackground(color)) => assert_eq(color, "$background")
    _ => abort("expected solid background")
  }
}
