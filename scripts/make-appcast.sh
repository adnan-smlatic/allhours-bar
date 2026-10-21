#!/bin/zsh
# Writes the Sparkle appcast (update feed) for one DMG, and signs the DMG and the feed with the update key
# from $ALLHOURS_RELEASE_DIR (default ~/.config/allhours-bar-release). Installed copies only accept an update
# when both signatures check out against the SUPublicEDKey they ship with.
#
#   ./scripts/make-appcast.sh <dmg> <version> <build> <download-url> <out.xml> [release-notes.md]
#
# Release notes are Markdown; Sparkle shows them in its update window.
set -euo pipefail
cd "$(dirname "$0")/.."

DMG=$1 VERSION=$2 BUILD=$3 URL=$4 OUT=$5 NOTES=${6:-}
KEY=${ALLHOURS_RELEASE_DIR:-$HOME/.config/allhours-bar-release}/sparkle-ed25519.key
SIGN_UPDATE=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
[[ -f $KEY ]] || { echo "No update key at $KEY" >&2; exit 1; }
[[ -x $SIGN_UPDATE ]] || { echo "sign_update not found; build the app once so Xcode fetches Sparkle" >&2; exit 1; }

# → sparkle:edSignature="…" length="…"
ENCLOSURE_SIGNATURE=$($SIGN_UPDATE --ed-key-file $KEY $DMG)
MIN_OS=$(sed -n 's/.*MACOSX_DEPLOYMENT_TARGET = \(.*\);/\1/p' AllHoursBar.xcodeproj/project.pbxproj | head -1)

DESCRIPTION=""
if [[ -n $NOTES ]]; then
  DESCRIPTION="      <description sparkle:format=\"markdown\"><![CDATA[
$(<$NOTES)
]]></description>"
fi

cat > $OUT <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>All Hours Bar</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
$DESCRIPTION
      <enclosure url="$URL" $ENCLOSURE_SIGNATURE type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

# Embeds the feed's signature in the XML (SURequireSignedFeed), then checks both signatures.
$SIGN_UPDATE --ed-key-file $KEY $OUT
$SIGN_UPDATE --verify --ed-key-file $KEY $OUT
$SIGN_UPDATE --verify --ed-key-file $KEY $DMG "$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' <<<$ENCLOSURE_SIGNATURE)"
