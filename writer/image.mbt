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
priv struct ImagePlacement {
  bounds : Bounds
  crop : CropRect?
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
