///|
test "help exits successfully" {
  let response = dispatch(["--help"][0:])
  assert_eq(response.exit_code, 0)
  assert_true(response.stdout.contains("pptz check"))
  assert_eq(response.stderr, "")
}

///|
test "version exits successfully" {
  let response = dispatch(["--version"][0:])
  assert_eq(response.exit_code, 0)
  assert_eq(response.stdout, version())
}

///|
test "check command validates arguments before implementation" {
  let response = dispatch(["check"][0:])
  assert_eq(response.exit_code, 2)
  assert_true(response.stderr.contains("pptz check"))
}

///|
test "check command is reserved but not implemented" {
  let response = dispatch(["check", "deck.pptz.toml"][0:])
  assert_eq(response.exit_code, 1)
  assert_true(response.stderr.contains("not implemented"))
}
