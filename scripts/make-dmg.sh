#!/bin/zsh
# Builds a Release app and packages it as dist/AllHoursBar.dmg with a drag-to-install window, plus
# dist/appcast.xml, the Sparkle feed that tells installed copies about it. Attach both to the GitHub release.
#
#   NOTES=notes.md ./scripts/make-dmg.sh   # Markdown release notes for the update window (optional)
#
# With the release keys in ~/.config/allhours-bar-release (see scripts/sign-release.sh), the app is signed
# with the self-signed "All Hours Bar" certificate and the DMG and appcast are signed for Sparkle.
# Without them the app is ad-hoc signed and there's no appcast: fine for your own use, not for publishing.
# Either way no personal certificate details end up in the download. The app is not notarized, so on first
# launch macOS asks users to confirm it in System Settings › Privacy & Security › Open Anyway.
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT=$PWD
WORK=$ROOT/build/dmg
APP_NAME="All Hours Bar"
REPO=https://github.com/adnan-smlatic/allhours-bar

rm -rf "$WORK"
mkdir -p "$WORK/stage" dist

echo "› Building Release"
xcodebuild -project AllHoursBar.xcodeproj -scheme AllHoursBar -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build \
  | grep -E "error:|BUILD" || true

PLIST=build/DerivedData/Build/Products/Release/AllHoursBar.app/Contents/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $PLIST)
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $PLIST)
APP="$WORK/stage/$APP_NAME.app"
ditto build/DerivedData/Build/Products/Release/AllHoursBar.app "$APP"

echo "› Signing"
SIGNED=1
./scripts/sign-release.sh "$APP" > "$WORK/signing.log" 2>&1 || case $? in
  2) SIGNED=0; echo "  no release keys: the app stays ad-hoc signed and no appcast is made" ;;
  *) cat "$WORK/signing.log" >&2; exit 1 ;;
esac

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
rm -f "$OUT" dist/appcast.xml
build/dmg-venv/bin/dmgbuild -s scripts/dmg/settings.py \
  -D app="$APP" \
  -D background="$WORK/background.tiff" \
  -D icon="$WORK/AppIcon.icns" \
  "$APP_NAME" "$OUT" >/dev/null

if (( SIGNED )); then
  echo "› Writing the appcast"
  ./scripts/make-appcast.sh "$OUT" "$VERSION" "$BUILD" "$REPO/releases/download/v$VERSION/AllHoursBar.dmg" \
    dist/appcast.xml "${NOTES:-}" >/dev/null
  echo "✓ $OUT and dist/appcast.xml (v$VERSION, build $BUILD, $(du -h "$OUT" | cut -f1))"
  echo "  gh release create v$VERSION $OUT dist/appcast.xml --title \"$APP_NAME $VERSION\" --notes-file <notes>"
else
  echo "✓ $OUT (v$VERSION, $(du -h "$OUT" | cut -f1), ad-hoc signed)"
fi
