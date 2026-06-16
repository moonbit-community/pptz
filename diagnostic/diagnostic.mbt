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
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  path : String?
  element_id : String?
  field : String?
} derive(Eq, Debug)

///|
pub fn error_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Error, code, message, path, element_id, field }
}

///|
pub fn warning_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Warning, code, message, path, element_id, field }
}
