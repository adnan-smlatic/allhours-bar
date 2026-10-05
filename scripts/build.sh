#!/bin/zsh
# Builds a Release copy into "build/All Hours Bar.app".
# Pass --install to also copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="All Hours Bar.app"

xcodebuild -project AllHoursBar.xcodeproj -scheme AllHoursBar -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath build/DerivedData build | grep -E "error:|BUILD" || true

rm -rf "build/$APP"
ditto build/DerivedData/Build/Products/Release/AllHoursBar.app "build/$APP"
echo "Built build/$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x AllHoursBar 2>/dev/null || true
  rm -rf "/Applications/$APP"
  ditto "build/$APP" "/Applications/$APP"
  open "/Applications/$APP"
  echo "Installed to /Applications and launched"
fi
