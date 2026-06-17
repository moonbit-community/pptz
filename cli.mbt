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
pub struct CliResponse {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
pub fn version() -> String {
  "0.5.0"
}

///|
pub fn usage() -> String {
  cli_command().render_help()
}

///|
pub fn dispatch(args : ArrayView[String]) -> CliResponse {
  if args.length() == 1 && (args[0] == "--help" || args[0] == "-h") {
    return CliResponse::{ exit_code: 0, stdout: usage(), stderr: "" }
  }
  if args.length() == 1 && (args[0] == "--version" || args[0] == "-V") {
    return CliResponse::{ exit_code: 0, stdout: version(), stderr: "" }
  }
  let matches = cli_command().parse(argv=args, env={}) catch {
    err => return CliResponse::{ exit_code: 2, stdout: "", stderr: "\{err}" }
  }
  let deck_path = matches.values["deck"][0]
  let output_path = matches.values["out"][0]
  compile_deck(deck_path, output_path)
}

///|
fn cli_command() -> @argparse.Command {
  @argparse.Command(
    "pptz",
    about="PowerPoint Zero, compile YAML presentation sources to PPTX",
    version=version(),
    options=[
      @argparse.OptionArg("out", long="out", about="Output PPTX path.", default_values=[
        "output.pptx",
      ]),
    ],
    positionals=[
      @argparse.PositionArg(
        "deck",
        about="Input YAML deck file.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
}

///|
fn compile_deck(deck_path : String, output_path : String) -> CliResponse {
  let loaded = load_deck(deck_path) catch {
    LoadError::Fatal(message) =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: "error: \{message}",
      }
    LoadError::Diagnostics(diagnostics) =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: format_diagnostics(diagnostics),
      }
    err =>
      return CliResponse::{ exit_code: 1, stdout: "", stderr: "error: \{err}" }
  }
  let warning_text = format_diagnostics(loaded.warnings)
  write_pptx_file(loaded, output_path) catch {
    WriteError::Capability(message) =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: warning_text + "error: \{message}",
      }
    WriteError::Backend(message) =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: warning_text + "error: \{message}",
      }
    WriteError::Io(message) =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: warning_text + "error: \{message}",
      }
    err =>
      return CliResponse::{
        exit_code: 1,
        stdout: "",
        stderr: warning_text + "error: \{err}",
      }
  }
  CliResponse::{
    exit_code: 0,
    stdout: "wrote \{output_path}",
    stderr: warning_text,
  }
}

///|
fn format_diagnostics(diagnostics : Array[Diagnostic]) -> String {
  let mut text = ""
  for diagnostic in diagnostics {
    text = text + format_diagnostic(diagnostic) + "\n"
  }
  text
}

///|
fn format_diagnostic(diagnostic : Diagnostic) -> String {
  let severity = match diagnostic.severity {
    Error => "error"
    Warning => "warning"
  }
  "\{severity} \{diagnostic.code} \{optional_text(diagnostic.path)} \{optional_text(diagnostic.element_id)} \{optional_text(diagnostic.field)}: \{diagnostic.message}"
}

///|
fn optional_text(value : String?) -> String {
  match value {
    None => "-"
    Some(value) => value
  }
}
