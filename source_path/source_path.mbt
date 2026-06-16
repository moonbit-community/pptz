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
pub fn normal_path(value : String) -> @path.Path {
  let path : @path.Path = value
  path.normalize()
}

///|
pub fn resolve_source_path(base : @path.Path, value : String) -> @path.Path? {
  let relative : @path.Path = value
  if relative.is_absolute() || value.is_blank() {
    return None
  }
  let full_path = base.join(relative).normalize()
  let rel_text = full_path.relative(base~).to_string()
  if rel_text == ".." ||
    rel_text.has_prefix("../") ||
    rel_text.has_prefix("..\\") {
    None
  } else {
    Some(full_path)
  }
}

///|
pub fn source_full_path(base : String, value : String) -> @path.Path {
  let base_path : @path.Path = base
  let relative : @path.Path = value
  base_path.join(relative).normalize()
}

///|
pub fn resolve_existing_source_file(
  deck_dir : String,
  source_path : String,
) -> String? {
  let base : @path.Path = deck_dir
  match resolve_source_path(base, source_path) {
    None => None
    Some(full_path) => {
      let full_path_text = full_path.to_string()
      if (@miniio.is_file(full_path_text) catch { _ => false }) {
        Some(full_path_text)
      } else {
        None
      }
    }
  }
}
