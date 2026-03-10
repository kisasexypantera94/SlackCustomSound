#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Slack Custom Sound"
EXEC_NAME="SlackCustomSound"
BUNDLE_ID="com.example.slack-custom-sound"
VERSION="1.0"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"

echo "==> Building Swift package"
swift build -c release

echo "==> Creating app bundle"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "${BUILD_DIR}/${EXEC_NAME}" "$APP_DIR/Contents/MacOS/${EXEC_NAME}"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>

    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>

    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>

    <key>CFBundleExecutable</key>
    <string>${EXEC_NAME}</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleVersion</key>
    <string>${VERSION}</string>

    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>

    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Codesign ad-hoc"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Creating zip"
rm -f "dist/${APP_NAME}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "dist/${APP_NAME}.zip"

echo "==> Done"
echo "App bundle: $APP_DIR"
echo "Zip archive: dist/${APP_NAME}.zip"
