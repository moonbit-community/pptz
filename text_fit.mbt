///|
priv struct TextFitEstimate {
  height : Double
  longest_token_width : Double
}

///|
fn estimate_text_fit(
  bundle : DeckBundle,
  bounds : Bounds,
  content : TextContent,
) -> TextFitEstimate {
  let font_size = resolved_text_font_size(bundle, content)
  let font_px = font_size / 72.0 * 96.0
  let line_height = font_px * 1.1
  let mut line_count = 0
  let mut longest_token_width = 0.0
  for paragraph in content.text.split("\n") {
    let (lines, token_width) = estimated_wrapped_lines(
      paragraph.to_owned(),
      font_px,
      bounds.width.max(1.0),
      wrap=content.wrap != Some(false),
    )
    line_count += lines
    if token_width > longest_token_width {
      longest_token_width = token_width
    }
  }
  if line_count == 0 {
    line_count = 1
  }
  TextFitEstimate::{
    height: line_count.to_double() * line_height,
    longest_token_width,
  }
}

///|
fn estimated_wrapped_lines(
  text : String,
  font_px : Double,
  max_width : Double,
  wrap~ : Bool,
) -> (Int, Double) {
  let width = measured_text_width(text, font_px)
  let mut longest_token_width = 0.0
  for token in text.split(" ") {
    let token_width = measured_text_width(token.to_owned(), font_px)
    if token_width > longest_token_width {
      longest_token_width = token_width
    }
  }
  let lines = if wrap { (width / max_width).ceil().to_int().max(1) } else { 1 }
  (lines, longest_token_width)
}

///|
fn measured_text_width(text : String, font_px : Double) -> Double {
  let mut width = 0.0
  for char in text {
    width += char_width_factor(char) * font_px
  }
  width
}

///|
fn char_width_factor(char : Char) -> Double {
  if char.is_ascii_whitespace() {
    0.33
  } else if char.is_ascii() {
    if char.is_ascii_punctuation() {
      0.38
    } else {
      0.56
    }
  } else {
    1.0
  }
}

///|
fn resolved_text_font_size(
  bundle : DeckBundle,
  content : TextContent,
) -> Double {
  match content.font_size {
    Some(size) => size
    None =>
      match content.style {
        None => 18.0
        Some(style_token) =>
          match token_name(style_token) {
            None => 18.0
            Some(name) =>
              match bundle.deck.theme {
                None => 18.0
                Some(theme) =>
                  match theme.text_styles.get(name) {
                    Some(style) =>
                      match style.font_size {
                        Some(size) => size
                        None => 18.0
                      }
                    None => 18.0
                  }
              }
          }
      }
  }
}
