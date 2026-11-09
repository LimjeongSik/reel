#!/usr/bin/env bash
# work/ 원고를 덮어쓰기 전에 사람이 고친 파일을 가려내고, 단계마다 어느 커밋까지 반영했는지 기억한다.
#
# 사용법:
#   work-guard.sh begin  <work>               # 실행 시작: work/ · .gitignore 준비, 기존 md 백업, 파일별 상태 · 단계별 커밋 출력, 이번 실행 목록 비움
#   work-guard.sh check  <work> <파일>        # 덮어써도 되면 0, 사람이 고쳤으면 1 + 대신 쓸 경로(비어 있는 *.new*.md) 출력
#   work-guard.sh record <work> <파일>...     # reel이 방금 쓴 파일을 이번 실행 목록에 올린다. 정식 원고는 해시도 기록
#   work-guard.sh run    <work>               # 이번 실행에서 쓴 파일: <단계> <canon|alt|changed> <파일>
#   work-guard.sh adopt  <work> <대체> <정식> # 대체 원고를 정식 경로로 옮기고 기록. 덮이는 정식 원고는 backup에 남김
#   work-guard.sh mark   <work> <단계> [해시] # 단계(profile · cases · images · resume · portfolio)가 반영한 커밋 읽기 / 기록
#   work-guard.sh head   <work> [해시]        # mark <work> profile 과 같다(이전 버전 호환)
#
# <파일>은 work/ 기준 상대 경로(예: profile.md, cases/01-token.md).
# 상태는 work/.reel/에 둔다(manifest · marks · run · backup/). work/.gitignore가 `*`라 함께 커밋에서 빠진다.
# clean은 "reel이 마지막으로 쓴 뒤 바뀌지 않음"이다 — 지난 실행 파일도 clean이다. "이번 실행에서 썼나"는 run으로 본다.
set -euo pipefail

usage() { sed -n 2,15p "$0"; exit 1; }
[ $# -ge 2 ] || usage
cmd="$1"; work="${2%/}"; shift 2
state="$work/.reel"; manifest="$state/manifest"; marks="$state/marks"; runlist="$state/run"

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

# 대체 경로도 사람이 고쳤을 수 있으므로 덮어쓰지 않는다: resume.new.md가 있으면 resume.new-02.md, -03 …
alt_path() {
    local rel="$1" base ext="" cand n=2
    case "$rel" in
        *.*) base="${rel%.*}"; ext=".${rel##*.}" ;;
        *) base="$rel" ;;
    esac
    cand="$base.new$ext"
    while [ -e "$work/$cand" ]; do
        cand="$base.new-$(printf '%02d' "$n")$ext"; n=$((n + 1))
    done
    echo "$cand"
}

is_alt() { case "$1" in *.new.md|*.new-[0-9][0-9].md) return 0 ;; esac; return 1; }

# 백업은 대체 원고(*.new*.md)까지 포함한다.
md_files() {
    (cd "$work" && find . -path ./.reel -prune -o -type f -name '*.md' -print) | sed 's|^\./||' | sort
}

stage_of() {
    case "$1" in
        profile*) echo profile ;;
        cases/*) echo cases ;;
        images/*) echo images ;;
        resume*) echo resume ;;
        portfolio*) echo portfolio ;;
        *) echo - ;;
    esac
}

read_mark() {
    local m=""
    [ ! -f "$marks" ] || m="$(awk -F'\t' -v s="$1" '$1 == s { h = $2 } END { if (h) print h }' "$marks")"
    # 0.4.0은 profile의 커밋만 .reel/head에 남겼다.
    if [ -z "$m" ] && [ "$1" = profile ] && [ -f "$state/head" ]; then m="$(cat "$state/head")"; fi
    [ -n "$m" ] && echo "$m"
}

write_mark() {
    mkdir -p "$state"; touch "$marks"
    awk -F'\t' -v s="$1" '$1 != s' "$marks" > "$marks.tmp"
    printf '%s\t%s\n' "$1" "$2" >> "$marks.tmp"
    mv "$marks.tmp" "$marks"
}

case "$cmd" in
    begin)
        mkdir -p "$state"
        : > "$runlist"
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
                if is_alt "$rel"; then st=alt; else st="$(status_of "$rel")"; fi
                printf '%-8s %s\n' "$st" "$rel"
            done <<< "$files"
        else
            echo "work/ 비어 있음 — 처음 실행"
        fi
        for stage in profile cases images resume portfolio; do
            if m="$(read_mark "$stage")"; then echo "mark: $stage $m"; fi
        done
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
        touch "$runlist"
        for rel in "$@"; do
            [ -f "$work/$rel" ] || { echo "없는 파일: $rel" >&2; exit 1; }
            h="$(hash_of "$work/$rel")"
            # 대체 원고는 manifest에 올리지 않는다(올리면 다음 실행에서 clean으로 보고 덮어쓴다).
            if ! is_alt "$rel"; then
                awk -F'\t' -v p="$rel" '$2 != p' "$manifest" > "$manifest.tmp"
                printf '%s\t%s\n' "$h" "$rel" >> "$manifest.tmp"
                mv "$manifest.tmp" "$manifest"
            fi
            awk -F'\t' -v p="$rel" '$2 != p' "$runlist" > "$runlist.tmp"
            printf '%s\t%s\n' "$h" "$rel" >> "$runlist.tmp"
            mv "$runlist.tmp" "$runlist"
        done
        ;;
    adopt)
        [ $# -ge 2 ] || usage
        from="$1"; to="$2"
        is_alt "$from" || { echo "대체 원고가 아닙니다: $from" >&2; exit 1; }
        ! is_alt "$to" || { echo "정식 경로가 아닙니다: $to" >&2; exit 1; }
        [ -f "$work/$from" ] || { echo "없는 파일: $from" >&2; exit 1; }
        if [ -f "$work/$to" ]; then
            # begin 백업 뒤에 고쳐졌을 수도 있으니 덮기 직전 판을 따로 남긴다.
            keep="$state/backup/$(date +%Y%m%d-%H%M%S)-adopt"
            mkdir -p "$keep/$(dirname "$to")"
            cp -p "$work/$to" "$keep/$to"
            echo "backup: $keep/$to"
        fi
        mkdir -p "$work/$(dirname "$to")"
        mv "$work/$from" "$work/$to"
        touch "$runlist"
        awk -F'\t' -v p="$from" '$2 != p' "$runlist" > "$runlist.tmp" && mv "$runlist.tmp" "$runlist"
        "$0" record "$work" "$to"
        echo "adopted: $from → $to"
        ;;
    run)
        [ -f "$runlist" ] || exit 0
        while IFS=$'\t' read -r h rel; do
            [ -n "$rel" ] || continue
            if [ ! -f "$work/$rel" ] || [ "$(hash_of "$work/$rel")" != "$h" ]; then kind=changed
            elif is_alt "$rel"; then kind=alt
            else kind=canon; fi
            printf '%-9s %-7s %s\n' "$(stage_of "$rel")" "$kind" "$rel"
        done < "$runlist"
        ;;
    mark|head)
        if [ "$cmd" = head ]; then stage=profile; else [ $# -ge 1 ] || usage; stage="$1"; shift; fi
        if [ $# -ge 1 ]; then write_mark "$stage" "$1"
        else read_mark "$stage" || exit 1; fi
        ;;
    *) usage ;;
esac
