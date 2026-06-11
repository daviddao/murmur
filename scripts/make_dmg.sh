#!/usr/bin/env bash
# Builds a drag-and-drop Murmur.dmg into ./build
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build_app.sh

STAGE=build/dmg-stage
VOLUME="/Volumes/Murmur"
rm -rf "$STAGE" build/Murmur-rw.dmg build/Murmur.dmg
mkdir -p "$STAGE/.background"

cp -R build/Murmur.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "Generating DMG background…"
swift scripts/make_dmg_bg.swift build
tiffutil -cathidpicheck build/dmg-bg.png build/dmg-bg@2x.png \
  -out "$STAGE/.background/bg.tiff" 2>/dev/null

# Detach a stale volume if present.
if [ -d "$VOLUME" ]; then hdiutil detach "$VOLUME" -quiet || true; fi

hdiutil create -srcfolder "$STAGE" -volname "Murmur" -fs HFS+ \
  -format UDRW -size 64m build/Murmur-rw.dmg -ov -quiet
hdiutil attach build/Murmur-rw.dmg -noautoopen -quiet
sleep 1

if osascript scripts/dmg_layout.applescript >/dev/null 2>&1; then
  echo "Finder layout applied."
else
  echo "warning: Finder layout failed (automation permission?) — default layout used."
fi

sync
hdiutil detach "$VOLUME" -quiet
hdiutil convert build/Murmur-rw.dmg -format UDZO -imagekey zlib-level=9 \
  -o build/Murmur.dmg -quiet
rm -rf build/Murmur-rw.dmg "$STAGE"

codesign --force --sign - build/Murmur.dmg

echo
echo "✓ Built build/Murmur.dmg ($(du -h build/Murmur.dmg | cut -f1 | tr -d ' '))"
