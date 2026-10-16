#!/usr/bin/env bash
# raw PNG/JPG를 표시 크기에 맞춘 webp로 바꾼다. 원본은 그대로 둔다.
#
# 사용법:
#   to-webp.sh <입력 파일 또는 폴더> <출력 폴더> [최대 폭(px)=1080] [품질=82]
#
# 폭 기준: 모바일 화면 캡처 1080 · 데스크톱 캡처 1600 · 아이콘 192 · 썸네일 960.
# 원본보다 크게 늘리지 않는다.
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n 2,9p "$0"
    exit 1
fi

src="$1"; dest="$2"; max_w="${3:-1080}"; quality="${4:-82}"
mkdir -p "$dest"

if ! command -v cwebp >/dev/null; then
    echo "cwebp가 없습니다: brew install webp" >&2
    exit 1
fi

convert_one() {
    local in="$1"
    local name; name="$(basename "${in%.*}")"
    local out="$dest/$name.webp"
    local w; w="$(sips -g pixelWidth "$in" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    local resize=()
    if [ -n "$w" ] && [ "$w" -gt "$max_w" ]; then
        resize=(-resize "$max_w" 0)
    fi
    cwebp -quiet -q "$quality" ${resize[@]+"${resize[@]}"} "$in" -o "$out"
    printf '%s  %s → %s\n' "$(du -h "$out" | cut -f1)" "$in" "$out"
}

if [ -d "$src" ]; then
    find "$src" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort |
        while read -r f; do convert_one "$f"; done
else
    convert_one "$src"
fi
