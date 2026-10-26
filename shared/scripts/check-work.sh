#!/usr/bin/env bash
# work/ 원고를 기계적으로 점검한다: 인용한 커밋 해시 · 날짜가 실제 이력과 맞는지, 참조한 이미지가 있는지,
# 사례 번호가 이어지는지, 템플릿 자리표시자 · 피해야 할 표현 · 남은 TODO.
#
# 사용법: check-work.sh <work> [저장소 경로=<work>/..]
# 오류(✗)가 있으면 1로 끝난다. 경고(△)는 알려만 준다.
set -euo pipefail

[ $# -ge 1 ] || { sed -n 2,6p "$0"; exit 1; }
work="${1%/}"; repo="${2:-$work/..}"
errors=0; warns=0
err()  { printf '✗ %s\n' "$*"; errors=$((errors + 1)); }
warn() { printf '△ %s\n' "$*"; warns=$((warns + 1)); }
TAB=$'\t'
# 줄마다 나온 결과를 오류 · 경고로 센다(파이프 안 서브셸에서는 카운터가 안 올라가서 한 번 모아 받는다).
each() { local fn="$1" line; while IFS= read -r line; do [ -n "$line" ] && "$fn" "$line"; done; return 0; }

files="$(cd "$work" && find . -path ./.reel -prune -o -type f -name '*.md' -print | sed 's|^\./||' | sort)"
[ -n "$files" ] || { echo "work/에 md 파일이 없습니다."; exit 1; }

# 1. 커밋: `abc1234 · 2026.07.12` 꼴은 해시와 날짜를, 백틱 속 해시만 있는 꼴은 존재만 본다.
if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    refs="$(cd "$work" && while IFS= read -r f; do
        LC_ALL=C grep -oE '[0-9a-f]{7,40} · [0-9]{4}\.[0-9]{2}\.[0-9]{2}' "$f" | sed "s|^|$f$TAB|" || true
        LC_ALL=C grep -oE '`[0-9a-f]{7,12}`' "$f" | tr -d '`' | grep -E '[a-f]' | grep -E '[0-9]' | sed "s|^|$f$TAB|" || true
    done <<< "$files" | sort -u)"
    checked=0
    while IFS=$'\t' read -r f ref; do
        [ -n "$ref" ] || continue
        h="${ref%% *}"
        checked=$((checked + 1))
        if ! git -C "$repo" cat-file -e "$h^{commit}" 2>/dev/null; then
            err "$f: 커밋 $h 가 저장소에 없거나 모호합니다"
            continue
        fi
        case "$ref" in
            *" · "*)
                want="${ref##* }"
                got="$(git -C "$repo" show -s --format=%ad --date=format:%Y.%m.%d "$h")"
                [ "$want" = "$got" ] || err "$f: 커밋 $h 날짜가 $want 로 적혀 있지만 실제는 $got"
                ;;
        esac
    done <<< "$refs"
    echo "커밋 인용 ${checked}건 확인"
else
    warn "git 저장소가 아니어서 커밋 인용을 확인하지 못했습니다: $repo"
fi

# 2. 이미지 경로
hits="$(while IFS= read -r f; do
    LC_ALL=C grep -oE 'images/[A-Za-z0-9._/-]+\.(webp|png|jpe?g|svg|gif)' "$work/$f" | sort -u |
        while IFS= read -r img; do [ -f "$work/$img" ] || echo "$f: 이미지 $img 가 없습니다"; done || true
done <<< "$files")"
each err <<< "$hits"

# 3. 사례 번호는 01부터 빈틈 · 중복 없이
if [ -d "$work/cases" ]; then
    nums="$(cd "$work/cases" && ls -1 | grep -E '^[0-9]{2}-.+\.md$' | grep -v '\.new\.md$' | cut -c1-2 || true)"
    if [ -n "$nums" ]; then
        dup="$(echo "$nums" | uniq -d)"
        [ -z "$dup" ] || err "cases/: 번호 중복 $(echo $dup)"
        expect=1
        for n in $(echo "$nums" | sort -u); do
            [ "$((10#$n))" -eq "$expect" ] || { err "cases/: $(printf '%02d' "$expect")번이 비어 있습니다"; break; }
            expect=$((expect + 1))
        done
    fi
fi

# 4. 남은 템플릿 자리표시자
hits="$(while IFS= read -r f; do
    grep -nE '<(프로젝트명|slug|사례 제목[^>]*|한 줄 소개[^>]*|역할|YYYY[^>]*)>' "$work/$f" | sed "s|^|자리표시자 — $f:|" || true
done <<< "$files")"
each warn <<< "$hits"

# 5. writing-rules.md 5-1에서 피하기로 한 표현 (코드 블록 밖만)
phrases='을 통해|를 통해|에 있어서|되어지|되어졌|하는 것이 가능|성공적으로|효과적으로|혁신적|획기적'
hits="$(while IFS= read -r f; do
    awk -v f="$f" -v re="$phrases" '/^[[:space:]]*```/ { code = !code; next } !code && $0 ~ re { print "표현 — " f ":" NR ": " $0 }' "$work/$f"
done <<< "$files")"
each warn <<< "$hits"

# 6. TODO
todo_total=0
while IFS= read -r f; do
    c="$(grep -c 'TODO' "$work/$f" || true)"
    if [ "$c" -gt 0 ]; then printf '  TODO %3d  %s\n' "$c" "$f"; todo_total=$((todo_total + c)); fi
done <<< "$files"

echo "오류 $errors · 경고 $warns · TODO $todo_total"
[ "$errors" -eq 0 ]
