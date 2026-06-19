#!/bin/bash
set -euo pipefail

APP_NAME="Caffeine"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
ICON_SRC="Resources/AppIcon.png"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Generate AppIcon.icns (all required sizes) from the 1024x1024 source PNG.
ICONSET_PARENT="$(mktemp -d)"
ICONSET="$ICONSET_PARENT/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in \
  "16:icon_16x16" "32:icon_16x16@2x" \
  "32:icon_32x32" "64:icon_32x32@2x" \
  "128:icon_128x128" "256:icon_128x128@2x" \
  "256:icon_256x256" "512:icon_256x256@2x" \
  "512:icon_512x512" "1024:icon_512x512@2x"; do
  size="${spec%%:*}"
  name="${spec##*:}"
  sips -z "$size" "$size" "$ICON_SRC" --out "$ICONSET/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_PARENT"

# Ad-hoc signature so SMAppService and the status item work on modern macOS.
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
