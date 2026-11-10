#!/bin/bash
# 릴리스 뒤 실행: dist/thebestdisplay.rb를 hungryZoo/homebrew-tap의 Casks에 올림. (SRS-UPD-003)
# 전제: 저장소가 공개 상태이고 해당 버전의 릴리스에 DMG가 올라가 있음. 로컬 gh 로그인 사용.
# 사용: scripts/publish_cask.sh
set -euo pipefail

cd "$(dirname "$0")/.."
CASK="dist/thebestdisplay.rb"
[ -f "$CASK" ] || { echo "cask 파일 없음: scripts/build_dmg.sh를 먼저 실행" >&2; exit 1; }

VISIBILITY="$(gh repo view hungryZoo/TheBestDisplay --json visibility --jq .visibility)"
[ "$VISIBILITY" = "PUBLIC" ] || { echo "저장소가 공개 상태가 아님 ($VISIBILITY). 공개 전환 뒤 실행" >&2; exit 1; }

VERSION="$(sed -n 's/^  version "\(.*\)"/\1/p' "$CASK")"
SHA="$(sed -n 's/^  sha256 "\(.*\)"/\1/p' "$CASK")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 릴리스에 올라간 DMG의 체크섬이 cask 값과 같은지 확인.
gh release download "v$VERSION" --repo hungryZoo/TheBestDisplay --pattern "TheBestDisplay-$VERSION.dmg" --dir "$WORK/asset"
ACTUAL="$(shasum -a 256 "$WORK/asset/TheBestDisplay-$VERSION.dmg" | awk '{print $1}')"
[ "$ACTUAL" = "$SHA" ] || { echo "체크섬 불일치: 릴리스 $ACTUAL, cask $SHA" >&2; exit 1; }

gh repo clone hungryZoo/homebrew-tap "$WORK/tap" -- -q
cp "$CASK" "$WORK/tap/Casks/thebestdisplay.rb"
ROW='| [thebestdisplay](Casks/thebestdisplay.rb) | macOS 디스플레이 설정과 연결 진단 앱 — https://github.com/hungryZoo/TheBestDisplay |'
if ! grep -q 'Casks/thebestdisplay.rb' "$WORK/tap/README.md"; then
    awk -v row="$ROW" '{print} /Casks\/everydock.rb/ {print row}' "$WORK/tap/README.md" > "$WORK/README.new"
    mv "$WORK/README.new" "$WORK/tap/README.md"
fi
git -C "$WORK/tap" add Casks/thebestdisplay.rb README.md
if git -C "$WORK/tap" diff --cached --quiet; then
    echo "변경 없음: tap에 같은 내용이 이미 있음"
    exit 0
fi
git -C "$WORK/tap" commit -q -m "thebestdisplay $VERSION"
git -C "$WORK/tap" push -q
echo "cask 등록 완료: hungryZoo/tap/thebestdisplay $VERSION"
echo "확인: brew fetch hungryZoo/tap/thebestdisplay"
