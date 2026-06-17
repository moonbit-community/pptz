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
using @model {type Bounds, type Deck, type TextContent}

///|
using @style {resolve_text_properties}

///|
pub(all) struct TextFitEstimate {
  height : Double
  longest_token_width : Double
  available_width : Double
  available_height : Double
}

///|
pub fn estimate_text_fit(
  deck : Deck,
  bounds : Bounds,
  content : TextContent,
) -> TextFitEstimate {
  let font_size = match resolve_text_properties(deck, content).font_size {
    Some(size) => size
    None => 18.0
  }
  let fit_bounds = text_fit_bounds(bounds, content)
  let font_px = font_size / 72.0 * 96.0
  let line_height = font_px * 1.1
  let mut line_count = 0
  let mut longest_token_width = 0.0
  for paragraph in content.text.split("\n") {
    let (lines, token_width) = estimated_wrapped_lines(
      paragraph.to_owned(),
      font_px,
      fit_bounds.width.max(1.0),
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
    available_width: fit_bounds.width,
    available_height: fit_bounds.height,
  }
}

///|
fn text_fit_bounds(bounds : Bounds, content : TextContent) -> Bounds {
  match content.body {
    None => bounds
    Some(body) =>
      match body.inset {
        None => bounds
        Some(inset) => {
          let left = inset.left.unwrap_or(0.0)
          let right = inset.right.unwrap_or(0.0)
          let top = inset.top.unwrap_or(0.0)
          let bottom = inset.bottom.unwrap_or(0.0)
          Bounds::{
            x: bounds.x + left,
            y: bounds.y + top,
            width: (bounds.width - left - right).max(1.0),
            height: (bounds.height - top - bottom).max(1.0),
          }
        }
      }
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
