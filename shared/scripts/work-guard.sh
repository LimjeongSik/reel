#!/usr/bin/env bash
# work/ 원고를 덮어쓰기 전에 사람이 고친 파일을 가려내고, 마지막으로 분석한 커밋을 기억한다.
#
# 사용법:
#   work-guard.sh begin  <work>            # 실행 시작: work/ · .gitignore 준비, 기존 md 백업, 파일별 상태 출력
#   work-guard.sh check  <work> <파일>     # 덮어써도 되면 0, 사람이 고쳤으면 1 + 대신 쓸 경로 출력
#   work-guard.sh record <work> <파일>...  # reel이 방금 쓴 파일의 해시를 기록
#   work-guard.sh head   <work> [해시]     # 마지막으로 분석한 커밋 읽기 / 기록
#
# <파일>은 work/ 기준 상대 경로(예: profile.md, cases/01-token.md).
# 상태는 work/.reel/에 둔다(manifest · head · backup/). work/.gitignore가 `*`라 함께 커밋에서 빠진다.
set -euo pipefail

usage() { sed -n 2,11p "$0"; exit 1; }
[ $# -ge 2 ] || usage
cmd="$1"; work="${2%/}"; shift 2
state="$work/.reel"; manifest="$state/manifest"

hash_of() {
    if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

recorded_hash() {
    [ -f "$manifest" ] || return 0
    awk -F'\t' -v p="$1" '$2 == p { h = $1 } END { if (h) print h }' "$manifest"
}

# new: 아직 없음 · clean: reel이 쓴 그대로 · edited: reel이 쓴 뒤 고쳐짐 · unknown: reel 기록이 없는 파일
status_of() {
    local rel="$1"
    [ -f "$work/$rel" ] || { echo new; return; }
    local rec; rec="$(recorded_hash "$rel")"
    if [ -z "$rec" ]; then echo unknown
    elif [ "$rec" = "$(hash_of "$work/$rel")" ]; then echo clean
    else echo edited; fi
}

alt_path() {
    local rel="$1"
    case "$rel" in
        *.*) echo "${rel%.*}.new.${rel##*.}" ;;
        *) echo "$rel.new" ;;
    esac
}

md_files() {
    (cd "$work" && find . -path ./.reel -prune -o -type f -name '*.md' ! -name '*.new.md' -print) | sed 's|^\./||' | sort
}

case "$cmd" in
    begin)
        mkdir -p "$state"
        if [ ! -f "$work/.gitignore" ]; then
            printf '# 지원 서류 원고 — 커밋하지 않습니다\n*\n' > "$work/.gitignore"
        fi
        if git -C "$work" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
            ! git -C "$work" check-ignore -q -- profile.md; then
            echo "△ work/가 git에서 빠지지 않았습니다. work/.gitignore를 확인하세요." >&2
        fi

        files="$(md_files)"
        if [ -n "$files" ]; then
            backup="$state/backup/$(date +%Y%m%d-%H%M%S)"
            while IFS= read -r rel; do
                mkdir -p "$backup/$(dirname "$rel")"
                cp -p "$work/$rel" "$backup/$rel"
            done <<< "$files"
            # 백업은 최근 5개만 남긴다.
            ls -1 "$state/backup" | sort -r | tail -n +6 | while IFS= read -r old; do
                rm -rf "$state/backup/$old"
            done
            echo "backup: $backup"
            while IFS= read -r rel; do
                printf '%-8s %s\n' "$(status_of "$rel")" "$rel"
            done <<< "$files"
        else
            echo "work/ 비어 있음 — 처음 실행"
        fi
        if [ -f "$state/head" ]; then echo "head: $(cat "$state/head")"; fi
        ;;
    check)
        [ $# -ge 1 ] || usage
        s="$(status_of "$1")"
        case "$s" in
            new|clean) echo "$s"; exit 0 ;;
            *) echo "$s → $(alt_path "$1")"; exit 1 ;;
        esac
        ;;
    record)
        [ $# -ge 1 ] || usage
        mkdir -p "$state"; touch "$manifest"
        for rel in "$@"; do
            [ -f "$work/$rel" ] || { echo "없는 파일: $rel" >&2; exit 1; }
            awk -F'\t' -v p="$rel" '$2 != p' "$manifest" > "$manifest.tmp"
            printf '%s\t%s\n' "$(hash_of "$work/$rel")" "$rel" >> "$manifest.tmp"
            mv "$manifest.tmp" "$manifest"
        done
        ;;
    head)
        if [ $# -ge 1 ]; then
            mkdir -p "$state"; echo "$1" > "$state/head"
        elif [ -f "$state/head" ]; then
            cat "$state/head"
        else
            exit 1
        fi
        ;;
    *) usage ;;
esac
