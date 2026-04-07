#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BirdSTT"
BUILD_DIR="$PROJECT_DIR/.build/release"
BUNDLE_DIR="$PROJECT_DIR/build/$APP_NAME.app"

cd "$PROJECT_DIR"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"
cp "$PROJECT_DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/"

echo "Signing app bundle..."
codesign --force --sign - "$BUNDLE_DIR"

echo "Bundle created at: $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
