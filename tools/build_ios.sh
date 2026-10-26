#!/bin/bash
# Export and compile an unsigned iPhone/iPad app. Signing is done in Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
GODOT_BIN="${GODOT_BIN:-godot}"
expected=$(python3 -c 'import json; print(json.load(open("docs/toolchain.json"))["godot_version"])')
actual=$("$GODOT_BIN" --headless --version)
if [[ "$actual" != "${expected/-/.}"* ]]; then
  echo "Expected Godot $expected; found $actual" >&2
  exit 1
fi
xcodebuild -version
mkdir -p build/ios
touch build/.gdignore
"$GODOT_BIN" --headless --path . --import --quit
"$GODOT_BIN" --headless --path . --export-release iOS build/ios/uniloop.xcodeproj
tools/prepare_ios_simulator.sh
xcodebuild -project build/ios/uniloop.xcodeproj -scheme uniloop \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios/DerivedData CODE_SIGNING_ALLOWED=NO build
test -s build/ios/DerivedData/Build/Products/Release-iphoneos/uniloop.app/uniloop

xcodebuild -project build/ios/uniloop.xcodeproj -scheme uniloop \
  -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios/DerivedData CODE_SIGNING_ALLOWED=NO build
test -s build/ios/DerivedData/Build/Products/Release-iphonesimulator/uniloop.app/uniloop
