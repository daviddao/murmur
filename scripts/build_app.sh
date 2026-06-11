#!/usr/bin/env bash
# Builds Murmur.app into ./build
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/Murmur.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Murmur "$APP/Contents/MacOS/Murmur"
cp scripts/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  echo "Generating app icon…"
  swift scripts/make_icon.swift build
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"

echo
echo "✓ Built $APP"
echo "  Run:     open $APP"
echo "  Install: cp -r $APP /Applications/"
