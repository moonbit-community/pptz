///|
fn error_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Error, code, message, path, element_id, field }
}

///|
fn warning_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Warning, code, message, path, element_id, field }
}
