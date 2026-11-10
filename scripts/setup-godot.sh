#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.4.1
binary=".tools/Godot_v${version}-stable_linux.x86_64"
if [[ ! -x "$binary" ]]; then
  mkdir -p .tools
  archive=$(mktemp)
  trap 'rm -f "$archive"' EXIT
  curl -fL --retry 2 "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip" -o "$archive"
  python3 - "$archive" <<'PY'
import pathlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall('.tools')
for binary in pathlib.Path('.tools').glob('Godot_*_linux.x86_64'):
    binary.chmod(0o755)
PY
fi
"$binary" --headless --path zombie_game_3d_v3 --editor --import
