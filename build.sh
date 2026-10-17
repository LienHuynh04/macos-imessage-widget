#!/bin/sh
# Build "Messenger Mini.app" with Apple's local swiftc. No network, no dependencies.
set -e

APP_NAME="Messenger Mini"
APP="dist/${APP_NAME}.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc Sources/main.swift \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  -framework Cocoa \
  -O

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.local.messenger-mini</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo "Built at $APP"
