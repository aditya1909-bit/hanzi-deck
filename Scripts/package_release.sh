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

if [[ -n "${NOTARY_KEY_PATH:-}" || -n "${NOTARY_KEY_ID:-}" || -n "${NOTARY_ISSUER_ID:-}" ]]; then
    if [[ -z "${HANZI_DECK_SIGNING_IDENTITY:-}" || -z "${NOTARY_KEY_PATH:-}" || -z "${NOTARY_KEY_ID:-}" || -z "${NOTARY_ISSUER_ID:-}" ]]; then
        print -u2 "Notarization requires a signing identity, key path, key ID, and issuer ID."
        exit 1
    fi

    NOTARY_ARCHIVE="$STAGING_DIR/HanziDeck-notarization.zip"
    ditto -c -k --sequesterRsrc --keepParent \
        "$PROJECT_DIR/dist/HanziDeck.app" \
        "$NOTARY_ARCHIVE"
    xcrun notarytool submit "$NOTARY_ARCHIVE" \
        --key "$NOTARY_KEY_PATH" \
        --key-id "$NOTARY_KEY_ID" \
        --issuer "$NOTARY_ISSUER_ID" \
        --wait
    xcrun stapler staple "$PROJECT_DIR/dist/HanziDeck.app"
    xcrun stapler validate "$PROJECT_DIR/dist/HanziDeck.app"
fi

ditto "$PROJECT_DIR/dist/HanziDeck.app" "$STAGING_DIR/HanziDeck.app"
ln -s /Applications "$STAGING_DIR/Applications"

diskutil image create from \
    --volumeName "Hanzi Deck" \
    --format UDZO \
    "$STAGING_DIR" \
    "$DMG_PATH"

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    codesign --force --timestamp --sign "$HANZI_DECK_SIGNING_IDENTITY" "$DMG_PATH"
    xcrun notarytool submit "$DMG_PATH" \
        --key "$NOTARY_KEY_PATH" \
        --key-id "$NOTARY_KEY_ID" \
        --issuer "$NOTARY_ISSUER_ID" \
        --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

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
