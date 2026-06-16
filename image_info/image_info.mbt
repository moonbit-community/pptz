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
pub(all) struct ImageSourceSize {
  width : Double
  height : Double
}

///|
pub fn image_source_size(
  path : String,
  bytes : FixedArray[Byte],
) -> ImageSourceSize? {
  if is_svg_path(path) {
    svg_source_size(bytes)
  } else {
    match @oxml.detect_image_dimensions(bytes) {
      None => None
      Some(dimensions) =>
        Some(ImageSourceSize::{
          width: dimensions.width_px.to_double(),
          height: dimensions.height_px.to_double(),
        })
    }
  }
}

///|
pub fn is_svg_path(path : String) -> Bool {
  path.to_lower().has_suffix(".svg")
}

///|
fn svg_source_size(bytes : FixedArray[Byte]) -> ImageSourceSize? {
  let source = @oxml.bytes_to_string(bytes) catch { _ => return None }
  match
    (
      svg_number_attribute(source, "width"),
      svg_number_attribute(source, "height"),
    ) {
    (Some(width), Some(height)) =>
      if width > 0.0 && height > 0.0 {
        Some(ImageSourceSize::{ width, height })
      } else {
        None
      }
    _ => svg_viewbox_size(source)
  }
}

///|
fn svg_number_attribute(source : String, name : String) -> Double? {
  match svg_attribute(source, name) {
    None => None
    Some(value) => parse_number_prefix(value)
  }
}

///|
fn svg_attribute(source : String, name : String) -> String? {
  match source.find("\{name}=\"") {
    Some(index) =>
      quoted_attribute_value(source, index + name.length() + 2, '"')
    None =>
      match source.find("\{name}='") {
        Some(index) =>
          quoted_attribute_value(source, index + name.length() + 2, '\'')
        None => None
      }
  }
}

///|
fn quoted_attribute_value(
  source : String,
  start : Int,
  quote : Char,
) -> String? {
  for index in start..<source.length() {
    if source.get_char(index) == Some(quote) {
      return Some(source.sub(start~, end=index).to_owned())
    }
  }
  None
}

///|
fn svg_viewbox_size(source : String) -> ImageSourceSize? {
  match svg_attribute(source, "viewBox") {
    None => None
    Some(value) => {
      let numbers = parse_number_list(value)
      if numbers.length() == 4 && numbers[2] > 0.0 && numbers[3] > 0.0 {
        Some(ImageSourceSize::{ width: numbers[2], height: numbers[3] })
      } else {
        None
      }
    }
  }
}

///|
fn parse_number_list(value : String) -> Array[Double] {
  let result = []
  let mut index = 0
  while index < value.length() {
    match value.get_char(index) {
      Some(char) =>
        if char.is_ascii_whitespace() || char == ',' {
          index += 1
        } else {
          match parse_number_at(value, index) {
            Some((number, next)) => {
              result.push(number)
              index = next
            }
            None => index += 1
          }
        }
      None => index += 1
    }
  }
  result
}

///|
fn parse_number_prefix(value : String) -> Double? {
  match parse_number_at(value.trim().to_owned(), 0) {
    Some((number, _)) => Some(number)
    None => None
  }
}

///|
fn parse_number_at(value : String, start : Int) -> (Double, Int)? {
  let mut index = start
  let mut sign = 1.0
  match value.get_char(index) {
    Some('-') => {
      sign = -1.0
      index += 1
    }
    Some('+') => index += 1
    _ => ()
  }
  let mut integer = 0.0
  let mut has_digit = false
  while index < value.length() {
    match value.get_char(index) {
      Some(char) =>
        if char.is_ascii_digit() {
          integer = integer * 10.0 + digit_value(char).to_double()
          has_digit = true
          index += 1
        } else {
          break
        }
      None => break
    }
  }
  let mut fraction = 0.0
  let mut scale = 1.0
  if value.get_char(index) == Some('.') {
    index += 1
    while index < value.length() {
      match value.get_char(index) {
        Some(char) =>
          if char.is_ascii_digit() {
            scale = scale * 10.0
            fraction = fraction + digit_value(char).to_double() / scale
            has_digit = true
            index += 1
          } else {
            break
          }
        None => break
      }
    }
  }
  if has_digit {
    Some(((integer + fraction) * sign, index))
  } else {
    None
  }
}

///|
fn digit_value(char : Char) -> Int {
  char.to_int() - '0'.to_int()
}
