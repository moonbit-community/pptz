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
  let output = "examples/testdata/out/unsupported-gradient.pptx"
  @miniio.remove_file(output) catch {
    _ => ()
  }
  let response = dispatch(
    ["examples/testdata/unsupported-gradient.pptz.toml", "--out", output][0:],
  )
  assert_eq(response.exit_code, 1)
  assert_eq(response.stdout, "")
  assert_true(response.stderr.contains("gradient backgrounds"))
  assert_false(@miniio.exists(output) catch { _ => false })
}
