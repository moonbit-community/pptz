///|
priv struct ResolvedTextProperties {
  font_size : Double?
  font_family : String?
  color : String?
  bold : Bool?
  italic : Bool?
  line_height : Double?
  letter_spacing : Double?
}

///|
fn resolve_text_properties(
  bundle : DeckBundle,
  content : TextContent,
) -> ResolvedTextProperties {
  let theme_style = theme_text_style(bundle, content.style)
  ResolvedTextProperties::{
    font_size: option_or(content.font_size, text_style_font_size(theme_style)),
    font_family: option_or(
      content.font_family,
      text_style_font_family(theme_style),
    ),
    color: option_or(content.color, text_style_color(theme_style)),
    bold: option_or(content.bold, text_style_bold(theme_style)),
    italic: option_or(content.italic, text_style_italic(theme_style)),
    line_height: text_style_line_height(theme_style),
    letter_spacing: text_style_letter_spacing(theme_style),
  }
}

///|
fn theme_text_style(bundle : DeckBundle, style : String?) -> TextStyle? {
  match style {
    None => None
    Some(style_token) =>
      match token_name(style_token) {
        None => None
        Some(name) =>
          match bundle.deck.theme {
            None => None
            Some(theme) => theme.text_styles.get(name)
          }
      }
  }
}

///|
fn text_style_font_size(style : TextStyle?) -> Double? {
  match style {
    None => None
    Some(style) => style.font_size
  }
}

///|
fn text_style_font_family(style : TextStyle?) -> String? {
  match style {
    None => None
    Some(style) => style.font_family
  }
}

///|
fn text_style_color(style : TextStyle?) -> String? {
  match style {
    None => None
    Some(style) => style.color
  }
}

///|
fn text_style_bold(style : TextStyle?) -> Bool? {
  match style {
    None => None
    Some(style) => style.bold
  }
}

///|
fn text_style_italic(style : TextStyle?) -> Bool? {
  match style {
    None => None
    Some(style) => style.italic
  }
}

///|
fn text_style_line_height(style : TextStyle?) -> Double? {
  match style {
    None => None
    Some(style) => style.line_height
  }
}

///|
fn text_style_letter_spacing(style : TextStyle?) -> Double? {
  match style {
    None => None
    Some(style) => style.letter_spacing
  }
}

///|
fn[T] option_or(value : T?, fallback : T?) -> T? {
  match value {
    Some(_) => value
    None => fallback
  }
}
