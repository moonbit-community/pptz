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
test "compile command is reserved but not implemented" {
  let response = dispatch(
    ["examples/minimal/deck.pptz.toml", "--out", "dist/demo.pptx"][0:],
  )
  assert_eq(response.exit_code, 1)
  assert_true(response.stderr.contains("writer is not implemented"))
}

///|
test "compile command defaults output path" {
  let response = dispatch(["examples/minimal/deck.pptz.toml"][0:])
  assert_eq(response.exit_code, 1)
  assert_true(response.stderr.contains("-> output.pptx"))
}
