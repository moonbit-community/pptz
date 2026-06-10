///|
test "help exits successfully" {
  let response = dispatch(["--help"][0:])
  assert_eq(response.exit_code, 0)
  assert_true(
    response.stdout.contains("pptz <project-dir> --out <output.pptx>"),
  )
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
  let response = dispatch(["examples/minimal"][0:])
  assert_eq(response.exit_code, 2)
  assert_true(
    response.stderr.contains("pptz <project-dir> --out <output.pptx>"),
  )
}

///|
test "compile command is reserved but not implemented" {
  let response = dispatch(["examples/minimal", "--out", "dist/demo.pptx"][0:])
  assert_eq(response.exit_code, 1)
  assert_true(response.stderr.contains("not implemented"))
}
