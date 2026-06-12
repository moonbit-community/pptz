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
test "help exits successfully" {
  let response = dispatch(["--help"][0:])
  assert_eq(response.exit_code, 0)
  assert_true(response.stdout.contains("Usage: pptz"))
  assert_eq(response.stderr, "")
}

///|
test "version exits successfully" {
  let response = dispatch(["--version"][0:])
  assert_eq(response.exit_code, 0)
  assert_eq(response.stdout, version())
}

///|
test "compile command validates arguments before implementation" {
  let response = dispatch(["examples/minimal/deck.pptz.toml", "extra"][0:])
  assert_eq(response.exit_code, 2)
  assert_true(response.stderr.contains("unexpected value"))
}

///|
test "compile command writes pptx" {
  let output = "examples/testdata/out/dispatch-demo.pptx"
  let response = dispatch(
    ["examples/minimal/deck.pptz.toml", "--out", output][0:],
  )
  assert_eq(response.exit_code, 0)
  assert_eq(response.stdout, "wrote \{output}")
  assert_eq(response.stderr, "")
  assert_true(@miniio.is_file(output) catch { _ => false })
  @miniio.remove_file(output) catch {
    _ => ()
  }
}

///|
test "compile command defaults output path" {
  let response = dispatch(["examples/minimal/deck.pptz.toml"][0:])
  assert_eq(response.exit_code, 0)
  assert_eq(response.stdout, "wrote output.pptx")
  assert_true(@miniio.is_file("output.pptx") catch { _ => false })
  @miniio.remove_file("output.pptx") catch {
    _ => ()
  }
}

///|
test "compile command reports writer capability errors" {
  let output = "examples/testdata/out/unsupported-icon.pptx"
  @miniio.remove_file(output) catch {
    _ => ()
  }
  let response = dispatch(
    ["examples/testdata/unsupported-icon.pptz.toml", "--out", output][0:],
  )
  assert_eq(response.exit_code, 1)
  assert_eq(response.stdout, "")
  assert_true(response.stderr.contains("icon 'fas:dragon'"))
  assert_false(@miniio.exists(output) catch { _ => false })
}
