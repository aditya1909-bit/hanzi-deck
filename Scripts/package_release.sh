#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
RELEASE_DIR="$PROJECT_DIR/dist/release"
DMG_PATH="$RELEASE_DIR/HanziDeck-macOS.dmg"
ZIP_PATH="$RELEASE_DIR/HanziDeck-macOS.zip"
CHECKSUM_PATH="$RELEASE_DIR/SHA256SUMS.txt"

"$PROJECT_DIR/Scripts/build_app.sh"
mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"

STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/hanzi-deck-release.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$PROJECT_DIR/dist/HanziDeck.app" "$STAGING_DIR/HanziDeck.app"
ln -s /Applications "$STAGING_DIR/Applications"

diskutil image create from \
    --volumeName "Hanzi Deck" \
    --format UDZO \
    "$STAGING_DIR" \
    "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent \
    "$PROJECT_DIR/dist/HanziDeck.app" \
    "$ZIP_PATH"

(
    cd "$RELEASE_DIR"
    shasum -a 256 "${DMG_PATH:t}" "${ZIP_PATH:t}" > "${CHECKSUM_PATH:t}"
)

print "$DMG_PATH"
print "$ZIP_PATH"
print "$CHECKSUM_PATH"
