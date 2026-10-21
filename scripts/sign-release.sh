#!/bin/zsh
# Signs "All Hours Bar.app" with the self-signed "All Hours Bar" release certificate, inside out as Sparkle
# documents it. Every release signed this way has the same identity, so on top of the EdDSA key Sparkle can
# check an update's code signature too, and no personal details end up in the download. It can't stop macOS
# asking for the login password once after each update: without an Apple Team ID, the Keychain ties the
# app's item to the exact build (its partition is the build's cdhash).
#
# The keys live in $ALLHOURS_RELEASE_DIR (default ~/.config/allhours-bar-release; see its README.txt).
# Exits with status 2, signing nothing, when they aren't there.
#
#   ./scripts/sign-release.sh "build/All Hours Bar.app"
set -euo pipefail

APP=${1:?usage: sign-release.sh <app>}
KEYS=${ALLHOURS_RELEASE_DIR:-$HOME/.config/allhours-bar-release}
KEYCHAIN=$KEYS/signing.keychain-db
[[ -f $KEYCHAIN ]] || exit 2

security unlock-keychain -p "$(<$KEYS/signing.keychain-password)" $KEYCHAIN

# codesign only finds identities in keychains on the search list, so ours is on it just while signing.
original=("${(@f)$(security list-keychains -d user | sed -e 's/^ *"//' -e 's/"$//')}")
trap 'security list-keychains -d user -s "${original[@]}"' EXIT
security list-keychains -d user -s "${original[@]}" $KEYCHAIN

sign() {
  codesign --force --timestamp=none --options runtime --keychain $KEYCHAIN --sign "All Hours Bar" "$@"
}

SPARKLE=$APP/Contents/Frameworks/Sparkle.framework
sign $SPARKLE/Versions/B/XPCServices/Installer.xpc
sign --preserve-metadata=entitlements $SPARKLE/Versions/B/XPCServices/Downloader.xpc
sign $SPARKLE/Versions/B/Autoupdate
sign $SPARKLE/Versions/B/Updater.app
sign $SPARKLE
# The app's own entitlements, not whatever the build signed it with (development signing adds get-task-allow).
sign --entitlements ${0:A:h}/../Config/AllHoursBar.entitlements $APP

codesign --verify --strict --deep $APP
