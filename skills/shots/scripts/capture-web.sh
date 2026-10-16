#!/usr/bin/env bash
# 웹 화면 한 장을 PNG로 찍는다 (Playwright CLI).
#
# 사용법:
#   capture-web.sh <url> <out.png> [옵션...]
# 옵션은 Playwright `screenshot` 옵션을 그대로 넘긴다. 자주 쓰는 것:
#   --color-scheme dark        다크 테마
#   --viewport-size 390,844    모바일 화면 (--device "iPhone 15"는 WebKit을 따로 받아야 해서 기본으로 쓰지 않는다)
#   --viewport-size 1440,900   데스크톱 크기 (아무것도 안 주면 이 값)
#   --full-page                스크롤 전체
#   --wait-for-timeout 1500    애니메이션 · 로딩 대기(ms)
#   --load-storage auth.json   로그인 상태 (먼저 `npx playwright@VER open --save-storage auth.json <url>`로 저장)
set -euo pipefail

# 1.64.1은 Chromium r1248을 쓴다. 처음 한 번은 `npx playwright@1.64.1 install chromium-headless-shell`이 필요할 수 있다.
PW_VERSION="${PW_VERSION:-1.64.1}"

if [ $# -lt 2 ]; then
    sed -n 2,12p "$0"
    exit 1
fi

url="$1"; out="$2"; shift 2
mkdir -p "$(dirname "$out")"

args=("$@")
# 기기 에뮬레이션이나 크기를 따로 주지 않았으면 데스크톱 크기로 찍는다.
if [[ " ${args[*]-} " != *"--device"* && " ${args[*]-} " != *"--viewport-size"* ]]; then
    args+=(--viewport-size "1440,900")
fi
if [[ " ${args[*]-} " != *"--wait-for-timeout"* ]]; then
    args+=(--wait-for-timeout 1200)
fi

npx -y "playwright@${PW_VERSION}" screenshot "${args[@]}" "$url" "$out"
echo "saved: $out"
