#!/bin/bash
# Build a universal Mac app and preserve its bundle/signature in a zip.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
expected=$(python3 -c 'import json; print(json.load(open("docs/toolchain.json"))["godot_version"])')
actual=$("$GODOT_BIN" --headless --version)
if [[ "$actual" != "${expected/-/.}"* ]]; then
  echo "Expected Godot $expected; found $actual" >&2
  exit 1
fi
mkdir -p build/macos
touch build/.gdignore
"$GODOT_BIN" --headless --path . --import --quit
"$GODOT_BIN" --headless --path . --export-release macOS build/macos/Uniloop.app
app=build/macos/Uniloop.app
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
test -x "$app/Contents/MacOS/$executable"
lipo "$app/Contents/MacOS/$executable" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" build/macos/uniloop-macos.zip
echo "Built $app and build/macos/uniloop-macos.zip"
