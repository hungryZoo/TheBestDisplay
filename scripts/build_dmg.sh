#!/bin/bash
# 배포물 생성: 릴리스 빌드 앱을 DMG로 묶고 체크섬과 Homebrew cask 파일을 만듦. (SRS-UPD-003)
# 사용: scripts/build_dmg.sh
# 결과: dist/TheBestDisplay-<버전>.dmg, dist/TheBestDisplay-<버전>.dmg.sha256, dist/thebestdisplay.rb
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build_app.sh release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/TheBestDisplay.app/Contents/Info.plist)"
DIST="dist"
STAGING="$DIST/dmg-staging"
DMG="$DIST/TheBestDisplay-$VERSION.dmg"
CASK="$DIST/thebestdisplay.rb"

mkdir -p "$DIST"
rm -rf "$STAGING"
rm -f "$DMG" "$DMG.sha256" "$CASK"
mkdir -p "$STAGING"
ditto build/TheBestDisplay.app "$STAGING/TheBestDisplay.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "TheBestDisplay" -srcfolder "$STAGING" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$STAGING"

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "$SHA  $(basename "$DMG")" > "$DMG.sha256"

cat > "$CASK" <<CASK
cask "thebestdisplay" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/hungryZoo/TheBestDisplay/releases/download/v#{version}/TheBestDisplay-#{version}.dmg"
  name "TheBestDisplay"
  desc "Display settings and connection diagnostics in one window"
  homepage "https://github.com/hungryZoo/TheBestDisplay"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "TheBestDisplay.app"
  binary "#{appdir}/TheBestDisplay.app/Contents/MacOS/tbdctl"

  zap trash: [
    "~/Library/Application Support/TheBestDisplay",
    "~/Library/Caches/TheBestDisplay",
    "~/Library/Preferences/dev.thebestdisplay.app.plist",
  ]

  caveats <<~EOS
    TheBestDisplay is ad-hoc signed and not notarized, so macOS Gatekeeper will
    block the first launch. After installing, either run:
      xattr -dr com.apple.quarantine "#{appdir}/TheBestDisplay.app"
    or open System Settings > Privacy & Security and click "Open Anyway".
  EOS
end
CASK

echo "DMG: $DMG"
echo "SHA-256: $SHA"
echo "Cask: $CASK"
