///|
priv struct ImageSourceSize {
  width : Double
  height : Double
}

///|
priv struct ImagePlacement {
  bounds : Bounds
  crop : CropRect?
}

///|
fn image_source_size(
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
fn is_svg_path(path : String) -> Bool {
  path.to_lower().has_suffix(".svg")
}

///|
fn image_placement(
  bounds : Bounds,
  fit : ImageFit,
  source : ImageSourceSize?,
  crop : CropRect?,
) -> ImagePlacement raise {
  match fit {
    StretchFit => ImagePlacement::{ bounds, crop: normalize_crop(crop) }
    ContainFit => {
      let source = require_source_size(source, "contain")
      ImagePlacement::{
        bounds: contain_bounds(bounds, source, crop),
        crop: normalize_crop(crop),
      }
    }
    CoverFit => {
      let source = require_source_size(source, "cover")
      ImagePlacement::{
        bounds,
        crop: normalize_crop(Some(cover_crop(bounds, source, crop))),
      }
    }
  }
}

///|
fn require_source_size(
  source : ImageSourceSize?,
  fit : String,
) -> ImageSourceSize raise {
  match source {
    Some(source) => source
    None =>
      raise WriteError::Backend(
        "image fit '\{fit}' requires readable image dimensions",
      )
  }
}

///|
fn contain_bounds(
  bounds : Bounds,
  source : ImageSourceSize,
  crop : CropRect?,
) -> Bounds {
  let crop = crop_or_zero(crop)
  let visible_width = source.width * (1.0 - crop.left - crop.right)
  let visible_height = source.height * (1.0 - crop.top - crop.bottom)
  let source_aspect = visible_width / visible_height
  let bounds_aspect = bounds.width / bounds.height
  if source_aspect > bounds_aspect {
    let height = bounds.width / source_aspect
    Bounds::{
      x: bounds.x,
      y: bounds.y + (bounds.height - height) / 2.0,
      width: bounds.width,
      height,
    }
  } else {
    let width = bounds.height * source_aspect
    Bounds::{
      x: bounds.x + (bounds.width - width) / 2.0,
      y: bounds.y,
      width,
      height: bounds.height,
    }
  }
}

///|
fn cover_crop(
  bounds : Bounds,
  source : ImageSourceSize,
  crop : CropRect?,
) -> CropRect {
  let crop = crop_or_zero(crop)
  let visible_width = source.width * (1.0 - crop.left - crop.right)
  let visible_height = source.height * (1.0 - crop.top - crop.bottom)
  let source_aspect = visible_width / visible_height
  let bounds_aspect = bounds.width / bounds.height
  if source_aspect > bounds_aspect {
    let desired_width = visible_height * bounds_aspect
    let extra = (visible_width - desired_width) / source.width / 2.0
    CropRect::{
      left: crop.left + extra,
      top: crop.top,
      right: crop.right + extra,
      bottom: crop.bottom,
    }
  } else if source_aspect < bounds_aspect {
    let desired_height = visible_width / bounds_aspect
    let extra = (visible_height - desired_height) / source.height / 2.0
    CropRect::{
      left: crop.left,
      top: crop.top + extra,
      right: crop.right,
      bottom: crop.bottom + extra,
    }
  } else {
    crop
  }
}

///|
fn crop_or_zero(crop : CropRect?) -> CropRect {
  match crop {
    Some(crop) => crop
    None => CropRect::{ left: 0.0, top: 0.0, right: 0.0, bottom: 0.0 }
  }
}

///|
fn normalize_crop(crop : CropRect?) -> CropRect? {
  match crop {
    None => None
    Some(crop) =>
      if crop.left == 0.0 &&
        crop.top == 0.0 &&
        crop.right == 0.0 &&
        crop.bottom == 0.0 {
        None
      } else {
        Some(crop)
      }
  }
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
