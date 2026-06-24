#!/bin/bash
# Builds GitSwitch.app from the SwiftPM release binary and installs it.
#   ./make-app.sh            -> builds ./GitSwitch.app
#   ./make-app.sh --install  -> also copies it into /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="GitSwitch.app"
BIN_NAME="GitSwitch"   # SwiftPM product name
BUILD="$(date +%Y.%m.%d.%H%M)"   # visible build stamp, shown in the footer

echo "==> Generating app icon"
swift make-icon.swift
iconutil -c icns GitSwitch.iconset -o AppIcon.icns
rm -rf GitSwitch.iconset

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN_NAME" "$APP/Contents/MacOS/GitSwitch"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>GitSwitch</string>
    <key>CFBundleDisplayName</key>        <string>GitSwitch</string>
    <key>CFBundleIdentifier</key>         <string>com.highnet.gitswitch</string>
    <key>CFBundleVersion</key>            <string>${BUILD}</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleExecutable</key>         <string>GitSwitch</string>
    <key>CFBundleIconFile</key>           <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Ad-hoc codesign so macOS runs it without Gatekeeper prompts.
codesign --force --deep --sign - "$APP" 2>/dev/null || true

if [[ "${1:-}" == "--install" ]]; then
    DEST="/Applications/$APP"
    echo "==> Installing to $DEST (in place)"
    # Update contents in place so the bundle keeps the same path AND inode.
    # This keeps the Dock's pinned reference resolving to the latest build.
    mkdir -p "$DEST"
    rsync -a --delete "$APP/" "$DEST/"
    codesign --force --deep --sign - "$DEST" 2>/dev/null || true
    # Remove the project-folder build artifact so Spotlight/Dock can never
    # resolve GitSwitch to a stale copy; /Applications is the only one.
    rm -rf "$APP"
    # Refresh the Dock so the pinned tile shows this build immediately.
    killall Dock 2>/dev/null || true
    echo "Installed $DEST (build $BUILD)"
else
    echo "Built $APP (build $BUILD). Install with: ./make-app.sh --install"
fi
