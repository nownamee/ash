#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT_BIN:-$PWD/.tools/Godot_v4.4.1-stable_linux.x86_64}"
if [[ ! -x "$godot" ]]; then
  echo 'Run ./scripts/setup-godot.sh first, or set GODOT_BIN to the Godot binary.' >&2
  exit 1
fi
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export XDG_DATA_HOME="$scratch/data"
export GODOT_SILENCE_ROOT_WARNING=1
run_check() {
  local log="$scratch/$1.log"
  shift
  "$godot" --headless --path zombie_game_3d_v3 "$@" >"$log" 2>&1
  cat "$log"
  if grep -Eq 'SCRIPT ERROR|^ERROR:|Parse Error|Compile Error' "$log"; then
    return 1
  fi
}
run_check import --editor --import
run_check data --script res://tests/campaign_data_test.gd
run_check runtime res://tests/campaign_runtime_test.tscn
