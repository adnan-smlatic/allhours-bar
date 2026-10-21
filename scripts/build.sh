#!/bin/zsh
# Builds a Release copy into "build/All Hours Bar.app".
# Pass --install to also copy it to /Applications and launch it.
# With the release keys (see scripts/sign-release.sh) it's signed like a published release, so switching
# between your own builds and auto-updates doesn't make macOS ask about the Keychain again.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="All Hours Bar.app"

xcodebuild -project AllHoursBar.xcodeproj -scheme AllHoursBar -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath build/DerivedData build | grep -E "error:|BUILD" || true

rm -rf "build/$APP"
ditto build/DerivedData/Build/Products/Release/AllHoursBar.app "build/$APP"
if ./scripts/sign-release.sh "build/$APP" > build/signing.log 2>&1; then
  echo "Signed with the release certificate"
elif [[ $? != 2 ]]; then
  cat build/signing.log >&2
  exit 1
fi
echo "Built build/$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x AllHoursBar 2>/dev/null || true
  rm -rf "/Applications/$APP"
  ditto "build/$APP" "/Applications/$APP"
  open "/Applications/$APP"
  echo "Installed to /Applications and launched"
fi
