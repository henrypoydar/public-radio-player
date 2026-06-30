#!/bin/bash
set -e

# Configuration
APP_NAME="PublicRadioPlayer"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean and create directories
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile Swift files (universal: Apple Silicon + Intel)
SDK_PATH=$(xcrun --show-sdk-path)
ARCHS=(arm64 x86_64)
SLICES=()
for arch in "${ARCHS[@]}"; do
    echo "Compiling ($arch)..."
    swiftc \
        -o "$MACOS_DIR/$APP_NAME-$arch" \
        -target "$arch-apple-macosx13.0" \
        -sdk "$SDK_PATH" \
        -framework AppKit \
        -framework AVFoundation \
        -framework AVKit \
        -framework SwiftUI \
        PublicRadioPlayer/*.swift
    SLICES+=("$MACOS_DIR/$APP_NAME-$arch")
done

# Combine slices into a single universal binary
lipo -create -output "$MACOS_DIR/$APP_NAME" "${SLICES[@]}"
rm -f "${SLICES[@]}"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PublicRadioPlayer</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.publicradioplayer</string>
    <key>CFBundleName</key>
    <string>Public Radio Player</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign so the app runs on Apple Silicon. This is NOT notarization — a
# downloaded copy is still quarantined by Gatekeeper (see README install notes).
echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
echo "To install: cp -r $APP_BUNDLE /Applications/"
