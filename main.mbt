///|
fn main {
  let args = @miniio.args_get() catch { err => abort("args failed: \{err}") }
  let response = dispatch(args[1:])
  if response.stdout != "" {
    @miniio.stdout.write_text(response.stdout + "\n") catch {
      err => abort("stdout write failed: \{err}")
    }
  }
  if response.stderr != "" {
    @miniio.stderr.write_text(response.stderr + "\n") catch {
      err => abort("stderr write failed: \{err}")
    }
  }
  @miniio.exit(response.exit_code)
}
