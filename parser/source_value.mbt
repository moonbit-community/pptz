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
enum SourceValue {
  SourceString(String)
  SourceInteger(Int64)
  SourceFloat(Double)
  SourceBoolean(Bool)
  SourceArray(Array[SourceValue])
  SourceTable(Map[String, SourceValue])
} derive(Debug, Eq)

///|
fn parse_yaml_document(source : String, path : String) -> SourceValue raise {
  let documents = @yaml.Yaml::load_from_string(source) catch {
    err => fail("\{path}: cannot parse YAML: \{err.to_repr()}")
  }
  guard documents.length() == 1 else {
    fail("\{path}: expected exactly one YAML document")
  }
  yaml_to_source(documents[0], path)
}

///|
fn yaml_to_source(value : @yaml.Yaml, path : String) -> SourceValue raise {
  match value {
    @yaml.Yaml::String(text) => SourceString(text)
    @yaml.Yaml::Integer(number) => SourceInteger(number)
    @yaml.Yaml::Real(number, ..) => SourceFloat(number)
    @yaml.Yaml::Boolean(value) => SourceBoolean(value)
    @yaml.Yaml::Array(items) => {
      let result = []
      for index, item in items {
        result.push(yaml_to_source(item, "\{path}[\{index}]"))
      }
      SourceArray(result)
    }
    @yaml.Yaml::Map(table) => {
      let result = Map([], capacity=table.length())
      for key, item in table {
        result[key] = yaml_to_source(item, "\{path}.\{key}")
      }
      SourceTable(result)
    }
    @yaml.Yaml::Null => fail("\{path}: null values are not supported")
    @yaml.Yaml::BadValue => fail("\{path}: unsupported YAML value")
  }
}
