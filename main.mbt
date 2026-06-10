///|
fn main {
  let args = @miniio.args_get() catch { err => abort("args failed: \{err}") }
  let response = dispatch(args[1:])
  if response.stdout != "" {
    println(response.stdout)
  }
  if response.stderr != "" {
    println(response.stderr)
  }
  if response.exit_code != 0 {
    // `moon runwasm` may not propagate WASI proc_exit locally.
    abort(response.stderr)
  }
  @miniio.exit(0)
}
