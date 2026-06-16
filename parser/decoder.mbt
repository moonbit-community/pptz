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
fn parse_size(values : Array[@toml.TomlValue], path : String) -> Size raise {
  guard values.length() == 2 else { fail("\{path}: expected [width, height]") }
  {
    width: expect_double(values[0], "\{path}[0]"),
    height: expect_double(values[1], "\{path}[1]"),
  }
}

///|
fn parse_bounds(values : Array[@toml.TomlValue], path : String) -> Bounds raise {
  guard values.length() == 4 else {
    fail("\{path}: expected [x, y, width, height]")
  }
  {
    x: expect_double(values[0], "\{path}[0]"),
    y: expect_double(values[1], "\{path}[1]"),
    width: expect_double(values[2], "\{path}[2]"),
    height: expect_double(values[3], "\{path}[3]"),
  }
}

///|
fn required_string(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> String raise {
  match table.get(key) {
    Some(value) => expect_string(value, path)
    None => fail("\{path}: missing required string")
  }
}

///|
fn required_double(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Double raise {
  match table.get(key) {
    Some(value) => expect_double(value, path)
    None => fail("\{path}: missing required number")
  }
}

///|
fn required_array(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Array[@toml.TomlValue] raise {
  match table.get(key) {
    Some(TomlArray(values)) => values
    Some(_) => fail("\{path}: expected array")
    None => fail("\{path}: missing required array")
  }
}

///|
fn expect_array(
  value : @toml.TomlValue,
  path : String,
) -> Array[@toml.TomlValue] raise {
  match value {
    TomlArray(values) => values
    _ => fail("\{path}: expected array")
  }
}

///|
fn parse_optional_double_array(
  value : @toml.TomlValue?,
  path : String,
) -> Array[Double]? raise {
  match value {
    None => None
    Some(TomlArray(values)) => Some(parse_double_array(values, path))
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn parse_double_array(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[Double] raise {
  let result = []
  for index, item in values {
    result.push(expect_double(item, "\{path}[\{index}]"))
  }
  result
}

///|
fn parse_optional_string_array(
  value : @toml.TomlValue?,
  path : String,
) -> Array[String]? raise {
  match value {
    None => None
    Some(TomlArray(values)) => {
      let result = []
      for index, item in values {
        result.push(expect_string(item, "\{path}[\{index}]"))
      }
      Some(result)
    }
    Some(_) => fail("\{path}: expected array")
  }
}

///|
fn[T] parse_named_table_map(
  table : Map[String, @toml.TomlValue],
  path : String,
  parse : (Map[String, @toml.TomlValue], String) -> T raise,
) -> Map[String, T] raise {
  let result = Map([], capacity=table.length())
  for name, value in table {
    let item_path = "\{path}.\{name}"
    result[name] = parse(expect_table(value, item_path), item_path)
  }
  result
}

///|
fn[T] parse_optional_named_table_map(
  value : @toml.TomlValue?,
  path : String,
  parse : (Map[String, @toml.TomlValue], String) -> T raise,
) -> Map[String, T] raise {
  match value {
    None => Map([], capacity=0)
    Some(value) => parse_named_table_map(expect_table(value, path), path, parse)
  }
}

///|
fn required_table(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Map[String, @toml.TomlValue] raise {
  match table.get(key) {
    Some(value) => expect_table(value, path)
    None => fail("\{path}: missing required table")
  }
}

///|
fn optional_string(value : @toml.TomlValue?, path : String) -> String? raise {
  match value {
    None => None
    Some(value) => Some(expect_string(value, path))
  }
}

///|
fn optional_double(value : @toml.TomlValue?, path : String) -> Double? raise {
  match value {
    None => None
    Some(value) => Some(expect_double(value, path))
  }
}

///|
fn optional_int(
  value : @toml.TomlValue?,
  path : String,
  default~ : Int,
) -> Int raise {
  match value {
    None => default
    Some(value) => expect_int(value, path)
  }
}

///|
fn optional_int_or_none(value : @toml.TomlValue?, path : String) -> Int? raise {
  match value {
    None => None
    Some(value) => Some(expect_int(value, path))
  }
}

///|
fn optional_bool(value : @toml.TomlValue?, path : String) -> Bool? raise {
  match value {
    None => None
    Some(TomlBoolean(value)) => Some(value)
    Some(_) => fail("\{path}: expected boolean")
  }
}

///|
fn expect_string(value : @toml.TomlValue, path : String) -> String raise {
  match value {
    TomlString(text) => text
    _ => fail("\{path}: expected string")
  }
}

///|
fn expect_double(value : @toml.TomlValue, path : String) -> Double raise {
  match value {
    TomlInteger(number) => number.to_double()
    TomlFloat(number) => number
    _ => fail("\{path}: expected number")
  }
}

///|
fn expect_int(value : @toml.TomlValue, path : String) -> Int raise {
  match value {
    TomlInteger(number) => number.to_int()
    _ => fail("\{path}: expected integer")
  }
}

///|
fn expect_table(
  value : @toml.TomlValue,
  path : String,
) -> Map[String, @toml.TomlValue] raise {
  match value {
    TomlTable(table) => table
    _ => fail("\{path}: expected table")
  }
}

///|
fn reject_unknown_fields(
  table : Map[String, @toml.TomlValue],
  path : String,
  allowed : Array[String],
) -> Unit raise {
  for key, _ in table {
    if !field_allowed(key, allowed) {
      fail("\{path}.\{key}: unknown field")
    }
  }
}

///|
fn field_allowed(key : String, allowed : Array[String]) -> Bool {
  for item in allowed {
    if key == item {
      return true
    }
  }
  false
}
