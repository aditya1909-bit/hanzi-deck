#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

swift build -c release --arch arm64 --arch x86_64

BUILD_PRODUCTS="$PROJECT_DIR/.build/apple/Products/Release"

OUTPUT_ROOT="$PROJECT_DIR/dist"
APP_DIR="$OUTPUT_ROOT/HanziDeck.app"
if [[ -e "$APP_DIR" ]]; then
    mv "$APP_DIR" "$OUTPUT_ROOT/HanziDeck-previous-$(date +%Y%m%d-%H%M%S).app"
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_PRODUCTS/HanziDeck" "$APP_DIR/Contents/MacOS/HanziDeck"
cp "$PROJECT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"

RESOURCE_BUNDLE="$BUILD_PRODUCTS/HanziDeck_HanziDeck.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    print -u2 "Resource bundle not found."
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

xcrun actool "$PROJECT_DIR/AppSources/HanziDeck/Assets.xcassets" \
    --compile "$APP_DIR/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon MacAppIcon \
    --output-partial-info-plist "$OUTPUT_ROOT/MacAppIcon-Info.plist" \
    >/dev/null

SIGNING_IDENTITY="${HANZI_DECK_SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_DIR"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
fi
print "$APP_DIR"
