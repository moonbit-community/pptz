///|
pub struct CliResponse {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
pub fn version() -> String {
  "0.1.0"
}

///|
pub fn usage() -> String {
  (
    #|pptz - PowerPoint Zero, compile TOML presentation sources to PPTX
    #|
    #|Usage:
    #|  pptz check <deck.pptz.toml>
    #|  pptz build <deck.pptz.toml> --out <output.pptx>
    #|  pptz format <deck.pptz.toml> --write
    #|  pptz --version
    #|
    #|The current implementation has the CLI contract and semantic AST. The
    #|check/build/format commands are reserved and will be wired to TOML parsing,
    #|validation, formatting, and PPTX writing in later slices.
  )
}

///|
pub fn dispatch(args : ArrayView[String]) -> CliResponse {
  let argc = args.length()
  if argc == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
    return CliResponse::{ exit_code: 0, stdout: usage(), stderr: "" }
  }
  if args[0] == "--version" || args[0] == "version" {
    return CliResponse::{ exit_code: 0, stdout: version(), stderr: "" }
  }
  if args[0] == "check" {
    if argc != 2 {
      return CliResponse::{
        exit_code: 2,
        stdout: "",
        stderr: "usage: pptz check <deck.pptz.toml>",
      }
    }
    return not_implemented("check", args[1])
  }
  if args[0] == "build" {
    if argc != 4 || args[2] != "--out" {
      return CliResponse::{
        exit_code: 2,
        stdout: "",
        stderr: "usage: pptz build <deck.pptz.toml> --out <output.pptx>",
      }
    }
    return not_implemented("build", args[1])
  }
  if args[0] == "format" {
    if argc != 3 || args[2] != "--write" {
      return CliResponse::{
        exit_code: 2,
        stdout: "",
        stderr: "usage: pptz format <deck.pptz.toml> --write",
      }
    }
    return not_implemented("format", args[1])
  }
  CliResponse::{
    exit_code: 2,
    stdout: "",
    stderr: "unknown command: \{args[0]}\n\n\{usage()}",
  }
}

///|
fn not_implemented(command : String, deck : String) -> CliResponse {
  CliResponse::{
    exit_code: 1,
    stdout: "",
    stderr: "pptz \{command} is not implemented yet for \{deck}",
  }
}
