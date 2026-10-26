#!/bin/bash
# Work around Godot 4.7.2's missing arm64 simulator archive.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIM_LIBRARY="build/ios/uniloop.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
if [[ "$(uname -m)" != arm64 ]]; then
  exit 0
fi
if xcrun lipo "$SIM_LIBRARY" -verify_arch arm64 2>/dev/null; then
  exit 0
fi
VERSION=$(python3 -c 'import json; print(json.load(open("docs/toolchain.json"))["godot_version"])')
if [[ "$VERSION" != 4.7.2-stable ]]; then
  echo "Recheck the simulator workaround for Godot $VERSION before compiling." >&2
  exit 1
fi
SOURCE="$PWD/build/toolchain/godot-$VERSION"
PYTHON="$PWD/build/toolchain/python/bin/python"
mkdir -p build/toolchain
touch build/.gdignore
if [[ ! -f "$SOURCE/SConstruct" ]]; then
  curl -fL --retry 2 -o build/toolchain/godot-source.tar.gz \
    "https://github.com/godotengine/godot/archive/refs/tags/$VERSION.tar.gz"
  tar -xzf build/toolchain/godot-source.tar.gz -C build/toolchain
fi
if [[ ! -x "$PYTHON" ]]; then
  python3 -m venv build/toolchain/python
fi
if ! "$PYTHON" -c 'import SCons' 2>/dev/null; then
  "$PYTHON" -m pip install 'scons==4.11.1'
fi
# Simulator templates only support OpenGL. Select it at startup so launching
# from the simulator home screen works as well as launching through Xcode.
"$PYTHON" - "$SOURCE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1]) / 'drivers/apple_embedded/app_delegate_service.mm'
source = path.read_text()
marker = '\tNSArray *arguments = [[NSProcessInfo processInfo] arguments];'
addition = '''
#if TARGET_OS_SIMULATOR
	arguments = [arguments arrayByAddingObjectsFromArray:@[@"--rendering-method", @"gl_compatibility"]];
#endif'''
if addition not in source:
    if source.count(marker) != 1:
        raise SystemExit('Godot simulator startup changed; review the renderer workaround.')
    path.write_text(source.replace(marker, marker + addition))
# Avoid rasterizing a 3x Retina framebuffer in Apple's CPU-only GL driver.
# Keep display coordinates and touch scaling consistent with that framebuffer.
for relative, marker in [
    ('drivers/apple_embedded/godot_view_apple_embedded.mm', '\tself.contentScaleFactor = [UIScreen mainScreen].scale;'),
    ('platform/ios/display_server_ios.mm', '\treturn [UIScreen mainScreen].scale;'),
]:
    path = Path(sys.argv[1]) / relative
    source = path.read_text()
    replacement = ('#if TARGET_OS_SIMULATOR\n' + marker.replace('[UIScreen mainScreen].scale', '1.0')
                   + '\n#else\n' + marker + '\n#endif')
    if replacement not in source:
        if source.count(marker) != 1:
            raise SystemExit('Godot display scale changed; review simulator workaround.')
        path.write_text(source.replace(marker, replacement))
PY
(
  cd "$SOURCE"
  "$PYTHON" -m SCons platform=ios arch=arm64 simulator=yes \
    target=template_release production=yes lto=none optimize=size debug_symbols=no \
    -j"${IOS_BUILD_JOBS:-12}"
)
ARM_LIBRARY="$SOURCE/bin/libgodot.ios.template_release.arm64.simulator.a"
xcrun lipo -create "$SIM_LIBRARY" "$ARM_LIBRARY" -output "$SIM_LIBRARY.fixed"
mv "$SIM_LIBRARY.fixed" "$SIM_LIBRARY"
xcrun lipo "$SIM_LIBRARY" -verify_arch arm64
xcrun lipo "$SIM_LIBRARY" -verify_arch x86_64
