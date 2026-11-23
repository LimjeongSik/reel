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
#   --wait-for-selector "main h1"  핵심 요소가 보일 때까지 기다린다(데이터 · 폰트로 늦게 그려지는 화면은 이것을 먼저)
#   --wait-for-timeout 1500    고정 대기(ms). 안 주면 1200. 셀렉터 대기 뒤 애니메이션이 끝나길 기다리는 용도
#   --load-storage auth.json   로그인 상태 (먼저 `npx playwright@VER open --save-storage auth.json <url>`로 저장)
# 찍은 조건은 <out 폴더>/capture-log.tsv에 한 줄 남긴다(촬영 시각 · URL · 화면 크기 · 테마 · 파일 · 옵션).
# 배포 버전(어느 커밋이 배포됐나)은 스크립트가 알 수 없으니 shots 스킬이 images.md에 따로 적는다.
set -euo pipefail

# 1.64.1은 Chromium r1248을 쓴다. 처음 한 번은 `npx playwright@1.64.1 install chromium-headless-shell`이 필요할 수 있다.
PW_VERSION="${PW_VERSION:-1.64.1}"

if [ $# -lt 2 ]; then
    sed -n 2,16p "$0"
    exit 1
fi

url="$1"; out="$2"; shift 2
mkdir -p "$(dirname "$out")"
log="$(dirname "$out")/capture-log.tsv"

args=("$@")
# 기기 에뮬레이션이나 크기를 따로 주지 않았으면 데스크톱 크기로 찍는다.
if [[ " ${args[*]-} " != *"--device"* && " ${args[*]-} " != *"--viewport-size"* ]]; then
    args+=(--viewport-size "1440,900")
fi
if [[ " ${args[*]-} " != *"--wait-for-timeout"* ]]; then
    args+=(--wait-for-timeout 1200)
fi

npx -y "playwright@${PW_VERSION}" screenshot "${args[@]}" "$url" "$out"

# 기록용으로 크기 · 테마를 옵션에서 읽는다.
size=-; theme=light; i=0
while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
        --viewport-size) size="${args[$((i + 1))]/,/x}" ;;
        --device) size="device:${args[$((i + 1))]}" ;;
        --color-scheme) theme="${args[$((i + 1))]}" ;;
    esac
    i=$((i + 1))
done
[ -f "$log" ] || printf '촬영 시각\t대상\t기기\t화면 크기\t테마\t파일\t옵션\n' > "$log"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$url" "chromium" "$size" "$theme" "$(basename "$out")" "${args[*]}" >> "$log"
echo "saved: $out"
