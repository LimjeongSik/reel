#!/usr/bin/env bash
# work/ 원고를 덮어쓰기 전에 사람이 고친 파일을 가려내고, 단계마다 어느 커밋까지 반영했는지 기억한다.
#
# 사용법:
#   work-guard.sh begin  <work> [--force]     # 실행 시작: work/ · .gitignore 준비, 기존 md 백업, 파일별 상태 · 단계별 커밋 · 입력이 바뀐 단계 출력, 이번 실행 목록 비움
#                                             # 다른 실행이 진행 중이면(6시간 안에 begin 후 end 없음) 3으로 끝난다. 확인 후 --force
#   work-guard.sh end    <work>               # 실행 끝: 진행 중 표시를 지운다
#   work-guard.sh check  <work> <파일>        # 덮어써도 되면 0, 사람이 고쳤으면 1 + 대신 쓸 경로(비어 있는 *.new*.md) 출력
#   work-guard.sh record <work> <파일>...     # reel이 방금 쓴 파일을 이번 실행 목록에 올린다. 정식 원고는 해시도 기록
#   work-guard.sh run    <work>               # 이번 실행에서 쓴 파일: <단계> <canon|alt|changed> <파일>
#   work-guard.sh adopt  <work> <대체> <정식> # 대체 원고를 정식 경로로 옮기고 기록. 덮이는 정식 원고는 backup에 남김
#   work-guard.sh snap   <work> <단계>        # 단계가 입력 원고를 읽기 직전에: 읽는 원고의 해시와 reel 버전을 잡아 둔다
#   work-guard.sh mark   <work> <단계> [해시] # 단계(profile · cases · images · resume · portfolio)가 반영한 커밋 읽기 / 기록
#                                             # 기록할 때는 snap 때의 입력 해시를 남긴다. snap 뒤 입력이 바뀌었으면 기록하지 않고 1
#                                             # (profile은 입력 원고가 없어 snap 없이도 된다)
#   work-guard.sh stale  <work> <단계>        # 기록 뒤 입력 원고나 reel 버전이 바뀌었으면 0 + 이유, 그대로면 1
#   work-guard.sh head   <work> [해시]        # mark <work> profile 과 같다(이전 버전 호환)
#
# <파일>은 work/ 기준 상대 경로(예: profile.md, cases/01-token.md).
# 상태는 work/.reel/에 둔다(manifest · marks · inputs · reading · run · active · backup/). work/.gitignore가 `*`라 함께 커밋에서 빠진다.
# 상태 파일을 바꾸는 명령은 work/.reel/lock으로 한 번에 하나만 돈다.
# clean은 "reel이 마지막으로 쓴 뒤 바뀌지 않음"이다 — 지난 실행 파일도 clean이다. "이번 실행에서 썼나"는 run으로 본다.
set -euo pipefail

usage() { sed -n 2,23p "$0"; exit 1; }
[ $# -ge 2 ] || usage
cmd="$1"; work="${2%/}"; shift 2
state="$work/.reel"; manifest="$state/manifest"; marks="$state/marks"; runlist="$state/run"
inputs="$state/inputs"; reading="$state/reading"; active="$state/active"
ACTIVE_TTL=21600   # 6시간. 그보다 오래된 진행 중 표시는 비정상 종료로 보고 무시한다

# reel 버전(작성 규칙 버전). 규칙이 바뀌면 같은 커밋이라도 원고를 다시 볼 이유가 된다.
reel_version() {
    local pj; pj="$(cd "$(dirname "$0")/../.." && pwd)/.claude-plugin/plugin.json"
    if [ -f "$pj" ]; then sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pj" | head -1
    else echo unknown; fi
}

# 상태 파일 잠금. 두 세션이 같은 work/에서 돌아도 manifest · run · marks를 서로 덮지 않게 한다.
lock() {
    mkdir -p "$state"
    local i=0 holder
    while ! mkdir "$state/lock" 2>/dev/null; do
        holder="$(cat "$state/lock/pid" 2>/dev/null || true)"
        if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then rm -rf "$state/lock"; continue; fi
        i=$((i + 1))
        [ "$i" -lt 100 ] || { echo "잠금을 얻지 못했습니다: $state/lock (다른 reel 명령이 도는 중)" >&2; exit 1; }
        sleep 0.1
    done
    echo $$ > "$state/lock/pid"
    trap 'rm -rf "$state/lock"' EXIT
}

# 실행마다 고유한 임시 파일. 고정된 .tmp 경로를 두 명령이 함께 쓰지 않게 한다.
tmp_for() { mktemp "$1.XXXXXX"; }

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

# <단계>\t<경로>\t<해시> 꼴 파일에서 한 단계의 지문만 "<경로>\t<해시>"로 꺼낸다.
sig_of() { awk -F'\t' -v s="$1" '$1 == s { print $2 "\t" $3 }' "$2" 2>/dev/null || true; }

# 한 단계의 지문을 <단계>\t… 꼴 파일에 바꿔 쓴다.
put_sig() { # <단계> <파일> <지문>
    mkdir -p "$state"; touch "$2"
    local t; t="$(tmp_for "$2")"
    awk -F'\t' -v s="$1" '$1 != s' "$2" > "$t"
    [ -z "$3" ] || printf '%s\n' "$3" | sed "s|^|$1\t|" >> "$t"
    mv "$t" "$2"
}

# 기록할 지문은 "읽을 때" 잡아 둔 것(snap)이다. mark 시점의 해시를 쓰면, 읽은 뒤에 바뀐 입력이
# 반영된 것처럼 기록돼 다음 실행이 옛 원고를 최신으로 본다.
write_mark() {
    local stage="$1" read_sig now_sig diff t
    read_sig="$(sig_of "$stage" "$reading")"
    now_sig="$(input_sig "$stage")"
    if [ -z "$read_sig" ]; then
        if [ -n "$(stage_inputs "$stage")" ]; then
            echo "✗ $stage: 입력을 읽은 기록(snap)이 없어 완료로 남기지 않습니다. 입력을 읽기 전에 snap work $stage" >&2
            exit 1
        fi
        read_sig="$now_sig"                 # profile: 입력 원고가 없다
    fi
    diff="$(sig_diff "$read_sig" "$now_sig")"
    if [ -n "$diff" ]; then
        echo "✗ $stage: 읽은 뒤 입력이 바뀌어 완료로 남기지 않습니다 — $(printf '%s' "$diff" | paste -sd, - | sed 's/,/, /g')" >&2
        echo "  바뀐 입력을 원고에 반영한 뒤 snap work $stage → (다시 읽고 고침) → 검수 → mark" >&2
        exit 1
    fi
    mkdir -p "$state"; touch "$marks"
    t="$(tmp_for "$marks")"
    awk -F'\t' -v s="$stage" '$1 != s' "$marks" > "$t"
    printf '%s\t%s\n' "$stage" "$2" >> "$t"
    mv "$t" "$marks"
    put_sig "$stage" "$inputs" "$read_sig"
}

# 단계가 읽는 정식 원고(work-layout.md "입력" 표). 대체 원고는 넣지 않는다.
stage_inputs() {
    case "$1" in
        cases|images) echo profile.md ;;
        resume) echo profile.md; md_files | grep -E '^cases/[^/]+\.md$' | grep -vE '\.new(-[0-9]{2})?\.md$' || true ;;
        portfolio) echo profile.md; md_files | grep -E '^cases/[^/]+\.md$' | grep -vE '\.new(-[0-9]{2})?\.md$' || true
                   echo images/images.md ;;
    esac
}

# 입력 지문: "<경로>\t<해시>" 줄들 + reel 버전. 없는 입력은 해시 자리에 '-'.
input_sig() {
    local rel
    printf '@reel\t%s\n' "$(reel_version)"
    stage_inputs "$1" | while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if [ -f "$work/$rel" ]; then printf '%s\t%s\n' "$rel" "$(hash_of "$work/$rel")"
        else printf '%s\t-\n' "$rel"; fi
    done
}

# 두 지문 사이에 달라진 입력을 한 줄씩: "<경로> 바뀜" · "<경로> 새로 생김" · "<경로> 없어짐" · "reel a → b"
sig_diff() {
    awk -F'\t' '
        NR == FNR { old[$1] = $2; next }
        { new[$1] = $2 }
        END {
            for (p in new) {
                if (!(p in old)) print p " 새로 생김"
                else if (old[p] != new[p]) {
                    if (p == "@reel") print "reel " old[p] " → " new[p]
                    else if (new[p] == "-") print p " 없어짐"
                    else if (old[p] == "-") print p " 새로 생김"
                    else print p " 바뀜"
                }
            }
            for (p in old) if (!(p in new)) print p " 없어짐"
        }' <(printf '%s\n' "$1") <(printf '%s\n' "$2") | sort
}

# 완료 기록 뒤 달라진 입력
stale_reasons() {
    local saved; saved="$(sig_of "$1" "$inputs")"
    if [ -z "$saved" ]; then echo "입력 기록 없음(0.5.0까지의 기록)"; return; fi
    sig_diff "$saved" "$(input_sig "$1")"
}

do_record() {
    mkdir -p "$state"; touch "$manifest" "$runlist"
    local rel h t
    for rel in "$@"; do
        [ -f "$work/$rel" ] || { echo "없는 파일: $rel" >&2; exit 1; }
        h="$(hash_of "$work/$rel")"
        # 대체 원고는 manifest에 올리지 않는다(올리면 다음 실행에서 clean으로 보고 덮어쓴다).
        if ! is_alt "$rel"; then
            t="$(tmp_for "$manifest")"
            awk -F'\t' -v p="$rel" '$2 != p' "$manifest" > "$t"
            printf '%s\t%s\n' "$h" "$rel" >> "$t"
            mv "$t" "$manifest"
        fi
        t="$(tmp_for "$runlist")"
        awk -F'\t' -v p="$rel" '$2 != p' "$runlist" > "$t"
        printf '%s\t%s\n' "$h" "$rel" >> "$t"
        mv "$t" "$runlist"
    done
}

case "$cmd" in
    begin)
        force=0; [ "${1:-}" = --force ] && force=1
        lock
        now="$(date +%s)"
        if [ -f "$active" ] && [ "$force" -eq 0 ]; then
            started="$(cut -f1 "$active" 2>/dev/null || echo 0)"
            case "$started" in ''|*[!0-9]*) started=0 ;; esac
            if [ $((now - started)) -lt "$ACTIVE_TTL" ]; then
                echo "△ 다른 reel 실행이 진행 중입니다($(cut -f2 "$active") 시작, end 기록 없음)." >&2
                echo "  같은 work/를 두 세션이 함께 쓰면 실행 목록과 원고가 섞입니다. 다른 실행이 없다면 begin --force" >&2
                exit 3
            fi
        fi
        printf '%s\t%s\n' "$now" "$(date '+%Y-%m-%d %H:%M:%S')" > "$active"
        : > "$runlist"
        rm -f "$reading"                    # 지난 실행에서 읽은 기록은 이번 실행의 근거가 아니다
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
            if m="$(read_mark "$stage")"; then
                echo "mark: $stage $m"
                why="$(stale_reasons "$stage" | paste -sd, - | sed 's/,/, /g')"
                [ -z "$why" ] || echo "stale: $stage — $why"
            fi
        done
        ;;
    snap)
        [ $# -ge 1 ] || usage
        case "$1" in profile|cases|images|resume|portfolio) ;; *) echo "알 수 없는 단계: $1" >&2; exit 1 ;; esac
        lock
        put_sig "$1" "$reading" "$(input_sig "$1")"
        ;;
    end)
        lock
        rm -f "$active"
        ;;
    stale)
        [ $# -ge 1 ] || usage
        read_mark "$1" >/dev/null || { echo "기록 없음"; exit 0; }
        why="$(stale_reasons "$1")"
        [ -n "$why" ] || exit 1
        echo "$why"
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
        lock
        do_record "$@"
        ;;
    adopt)
        [ $# -ge 2 ] || usage
        lock
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
        t="$(tmp_for "$runlist")"
        awk -F'\t' -v p="$from" '$2 != p' "$runlist" > "$t" && mv "$t" "$runlist"
        do_record "$to"
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
        if [ $# -ge 1 ]; then lock; write_mark "$stage" "$1"
        else read_mark "$stage" || exit 1; fi
        ;;
    *) usage ;;
esac
