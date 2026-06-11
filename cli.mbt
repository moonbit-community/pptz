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
    #|  pptz <deck.toml> [--out <output.pptx>]
    #|  pptz --version
    #|
    #|The current implementation has the CLI contract and semantic AST. The
    #|compile path will be wired to project loading, validation, and PPTX writing
    #|in later slices.
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
  if argc == 3 && args[1] == "--out" {
    return compile_not_implemented(args[0], args[2])
  }
  CliResponse::{
    exit_code: 2,
    stdout: "",
    stderr: "usage: pptz <deck.toml> [--out <output.pptx>]",
  }
}

///|
fn compile_not_implemented(
  project_dir : String,
  output : String,
) -> CliResponse {
  CliResponse::{
    exit_code: 1,
    stdout: "",
    stderr: "pptz compile is not implemented yet for \{project_dir} -> \{output}",
  }
}
