#!/bin/zsh
# Builds a Release app and packages it as dist/AllHoursBar.dmg with a drag-to-install window.
#
# The app is ad-hoc signed on purpose so no personal certificate details end up in a public download.
# It is not notarized, so on first launch macOS asks users to confirm it in
# System Settings › Privacy & Security › Open Anyway.
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT=$PWD
WORK=$ROOT/build/dmg
APP_NAME="All Hours Bar"

rm -rf "$WORK"
mkdir -p "$WORK/stage" dist

echo "› Building Release (ad-hoc signed)"
xcodebuild -project AllHoursBar.xcodeproj -scheme AllHoursBar -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build \
  | grep -E "error:|BUILD" || true

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  build/DerivedData/Build/Products/Release/AllHoursBar.app/Contents/Info.plist)
ditto build/DerivedData/Build/Products/Release/AllHoursBar.app "$WORK/stage/$APP_NAME.app"

echo "› Rendering background"
swift scripts/dmg/background.swift "$WORK" >/dev/null
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/background.tiff" 2>/dev/null

echo "› Making volume icon"
ICONSET="$WORK/AppIcon.iconset"
SRC=AllHoursBar/Assets.xcassets/AppIcon.appiconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  cp "$SRC/icon_$size.png" "$ICONSET/icon_${size}x${size}.png"
  double=$((size * 2))
  [[ -f "$SRC/icon_$double.png" ]] && cp "$SRC/icon_$double.png" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$WORK/AppIcon.icns"

echo "› Preparing dmgbuild"
if [[ ! -x build/dmg-venv/bin/dmgbuild ]]; then
  python3 -m venv build/dmg-venv
  build/dmg-venv/bin/pip install --quiet dmgbuild
fi

OUT="dist/AllHoursBar.dmg"
rm -f "$OUT"
build/dmg-venv/bin/dmgbuild -s scripts/dmg/settings.py \
  -D app="$WORK/stage/$APP_NAME.app" \
  -D background="$WORK/background.tiff" \
  -D icon="$WORK/AppIcon.icns" \
  "$APP_NAME" "$OUT" >/dev/null

echo "✓ $OUT (v$VERSION, $(du -h "$OUT" | cut -f1))"
