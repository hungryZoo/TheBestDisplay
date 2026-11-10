#!/bin/bash
# 앱 번들 조립: 릴리스 빌드, Info.plist 생성, ad-hoc 서명. (SRS-ARC-003)
# 사용: scripts/build_app.sh [debug|release]
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
VERSION="${TBD_VERSION:-0.1.0}"
APP="build/TheBestDisplay.app"

swift build -c "$CONFIG" --product TheBestDisplay
swift build -c "$CONFIG" --product tbdctl
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/TheBestDisplay" "$APP/Contents/MacOS/TheBestDisplay"
cp "$BIN/tbdctl" "$APP/Contents/MacOS/tbdctl"

# LSUIElement 미설정: Dock과 앱 전환기에 표시되는 일반 창 앱.
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>CFBundleExecutable</key><string>TheBestDisplay</string>
    <key>CFBundleIdentifier</key><string>dev.thebestdisplay.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>TheBestDisplay</string>
    <key>CFBundleDisplayName</key><string>TheBestDisplay</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP/Contents/MacOS/tbdctl"
codesign --force --sign - "$APP"
echo "$APP"
