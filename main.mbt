// Copyright 2026 moonbit-community
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
