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
pub fn token_name(value : String) -> String? {
  match value.strip_prefix("$") {
    None => None
    Some(name_view) => {
      let name = name_view.to_owned()
      if is_identifier(name) {
        Some(name)
      } else {
        None
      }
    }
  }
}

///|
pub fn token_name_unchecked(value : String) -> String? {
  match value.strip_prefix("$") {
    None => None
    Some(name) => Some(name.to_owned())
  }
}

///|
pub fn is_hex_color(value : String) -> Bool {
  guard value.length() == 7 || value.length() == 9 else { return false }
  guard value.get_char(0) == Some('#') else { return false }
  for index in 1..<value.length() {
    match value.get_char(index) {
      Some(char) => if !char.is_ascii_hexdigit() { return false }
      None => return false
    }
  }
  true
}

///|
pub fn is_identifier(value : String) -> Bool {
  guard !value.is_empty() else { return false }
  let mut index = 0
  for char in value.iter() {
    if index == 0 {
      if !char.is_ascii_alphabetic() {
        return false
      }
    } else if !(char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '_' ||
      char == '-') {
      return false
    }
    index += 1
  }
  true
}
