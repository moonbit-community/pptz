#!/usr/bin/env bash
set -euo pipefail

deck="${1:-deck.pptz.toml}"
out="${2:-}"
coord="${PPTZ_COORD:-Milky2018/pptz}"

if [[ ! -f "$deck" ]]; then
  echo "pptz_build: deck file not found: $deck" >&2
  exit 2
fi

if [[ -z "$out" ]]; then
  out="$(python3 - "$deck" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
print(data.get("output", {}).get("path", ""))
PY
)"
fi

if [[ -z "$out" ]]; then
  echo "pptz_build: output path missing; pass it as arg 2 or set [output].path" >&2
  exit 2
fi

mkdir -p "$(dirname "$out")"

run_pptz() {
  local output
  output="$(moon runwasm "$coord" "$@" 2>&1)"
  printf '%s\n' "$output"
  if grep -Eq '(^Error:|RuntimeError|RUNTIME ERROR|not implemented)' <<<"$output"; then
    return 1
  fi
}

run_pptz check "$deck"
run_pptz build "$deck" --out "$out"

if [[ ! -f "$out" ]]; then
  echo "pptz_build: expected output was not created: $out" >&2
  exit 1
fi

echo "pptz_build: wrote $out"
