#!/bin/bash
# Builds Islet.app (universal: Apple silicon + Intel, macOS 14+). Needs Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build dist
mkdir -p build dist
SDK=$(xcrun --sdk macosx --show-sdk-path)
SWIFT_FLAGS=(-O -wmo -swift-version 5 -sdk "$SDK" -module-name Islet)
for arch in arm64 x86_64; do
  echo "== Swift ($arch)"
  xcrun swiftc "${SWIFT_FLAGS[@]}" -target "$arch-apple-macos14.0" Sources/*.swift -o "build/Islet-$arch"
done
lipo -create build/Islet-arm64 build/Islet-x86_64 -output build/Islet
echo "== Now Playing bridge"
xcrun clang -dynamiclib -fobjc-arc -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -isysroot "$SDK" \
  -framework Foundation Adapter/IsletMediaRemote.m -o build/libIsletMediaRemote.dylib
echo "== Bundle"
APP=dist/Islet.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Islet "$APP/Contents/MacOS/Islet"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/libIsletMediaRemote.dylib Adapter/mediaremote.pl "$APP/Contents/Resources/"
iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP/Contents/Resources/libIsletMediaRemote.dylib"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "signature ok (ad-hoc)"
(cd dist && ditto -c -k --keepParent Islet.app Islet.zip)
ls -la dist
