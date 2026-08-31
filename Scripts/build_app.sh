#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

swift build -c release

OUTPUT_ROOT="$PROJECT_DIR/dist"
APP_DIR="$OUTPUT_ROOT/HanziDeck.app"
if [[ -e "$APP_DIR" ]]; then
    mv "$APP_DIR" "$OUTPUT_ROOT/HanziDeck-previous-$(date +%Y%m%d-%H%M%S).app"
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/.build/release/HanziDeck" "$APP_DIR/Contents/MacOS/HanziDeck"
cp "$PROJECT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE=$(find "$PROJECT_DIR/.build" -path '*release*' -type d -name 'HanziDeck_HanziDeck.bundle' -print -quit)
if [[ -z "$RESOURCE_BUNDLE" ]]; then
    print -u2 "Resource bundle not found."
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

codesign --force --sign - "$APP_DIR"
print "$APP_DIR"
