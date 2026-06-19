#!/bin/bash
set -euo pipefail

APP_NAME="Caffeine"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc signature so SMAppService and the status item work on modern macOS.
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
