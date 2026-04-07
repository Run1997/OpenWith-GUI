#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OpenWithGUI"
BUILD_CONFIGURATION="debug"
SHOULD_OPEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            BUILD_CONFIGURATION="release"
            shift
            ;;
        --open)
            SHOULD_OPEN=1
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: ./scripts/package-macos-app.sh [--release] [--open]" >&2
            exit 1
            ;;
    esac
done

cd "$ROOT_DIR"

echo "Building $APP_NAME ($BUILD_CONFIGURATION)..."
swift build -c "$BUILD_CONFIGURATION"

BIN_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
BINARY_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "Built binary not found at: $BINARY_PATH" >&2
    exit 1
fi

APP_BUNDLE_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_SOURCE_PATH="$ROOT_DIR/Assets/AppIcon.icns"
ICON_TARGET_NAME="AppIcon.icns"

if [[ ! -f "$ICON_SOURCE_PATH" ]]; then
    echo "App icon not found at: $ICON_SOURCE_PATH" >&2
    echo "Run: swift scripts/generate-app-icon.swift" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ICON_SOURCE_PATH" "$RESOURCES_DIR/$ICON_TARGET_NAME"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.openwithgui.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --deep -s - "$APP_BUNDLE_DIR"

echo "Packaged app bundle:"
echo "  $APP_BUNDLE_DIR"

if [[ "$SHOULD_OPEN" -eq 1 ]]; then
    echo "Opening app bundle..."
    open "$APP_BUNDLE_DIR"
fi
