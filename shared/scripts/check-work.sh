#!/usr/bin/env bash
# work/ 원고를 기계적으로 점검한다: 인용한 커밋 해시 · 날짜가 실제 이력과 맞는지, 그 커밋이 profile의 작성자 것인지,
# 전 → 후 코드 발췌가 그 커밋의 실제 코드와 같은지, 참조한 이미지가 있는지, 사례 번호가 이어지는지,
# 템플릿 자리표시자 · 피해야 할 표현 · 남은 TODO.
#
# 사용법: check-work.sh <work> [저장소 경로=<work>/..] [--public [파일...]]
#   --public: 제출본 검사를 더한다. 대상(기본 resume.md · portfolio.md)에 TODO · HTML 주석 · 로컬 경로 ·
#             localhost · 사설 IP가 남았으면 오류, 이메일은 경고(연락처면 그대로 둔다).
# 오류(✗)가 있으면 1로 끝난다. 경고(△)는 알려만 준다.
set -euo pipefail

[ $# -ge 1 ] || { sed -n 2,10p "$0"; exit 1; }
work="${1%/}"; shift
repo="$work/.."
case "${1:-}" in ''|--*) ;; *) repo="$1"; shift ;; esac
public=0; public_files=()
if [ "${1:-}" = --public ]; then
    public=1; shift
    public_files=("$@")
    [ ${#public_files[@]} -gt 0 ] || public_files=(resume.md portfolio.md)
elif [ $# -gt 0 ]; then
    echo "알 수 없는 인자: $1"; exit 1
fi
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
    # profile 머리말의 `작성자: a@x.com, b@y.com` — 인용한 커밋이 그 사람 것인지 본다.
    authors=""
    [ ! -f "$work/profile.md" ] || authors="$(grep -m1 -E '작성자:' "$work/profile.md" |
        grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+' | tr 'A-Z' 'a-z' || true)"
    checked=0; others=""
    while IFS=$'\t' read -r f ref; do
        [ -n "$ref" ] || continue
        h="${ref%% *}"
        checked=$((checked + 1))
        if ! git -C "$repo" cat-file -e "$h^{commit}" 2>/dev/null; then
            err "$f: 커밋 $h 가 저장소에 없거나 모호합니다"
            continue
        fi
        if [ -n "$authors" ]; then
            ae="$(git -C "$repo" show -s --format=%ae "$h" | tr 'A-Z' 'a-z')"
            printf '%s\n' "$authors" | grep -qxF -- "$ae" || others="$others$f: 커밋 $h 작성자 $ae 는 profile의 작성자가 아닙니다 — 내 기여인지 확인$TAB"
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
    each warn <<< "$(printf '%s' "$others" | tr '\t' '\n' | sort -u)"
else
    warn "git 저장소가 아니어서 커밋 인용을 확인하지 못했습니다: $repo"
fi

# 1-1. 전 → 후 코드 발췌가 그 커밋의 실제 코드에 있는지.
#   cases: `### \`경로\` · \`해시 · 날짜\`` 아래 **전** / **후** 코드 블록
#   portfolio: `- file: \`경로\` · commit: \`해시 · 날짜\`` 아래 before: / after: 코드 블록
#   전은 <해시>^:<경로>, 후는 <해시>:<경로>와 줄 단위로(앞뒤 공백 무시) 대조한다.
#   `// ...` 같은 줄임 줄, 빈 줄, <redacted>가 든 줄은 건너뛴다. 줄 순서까지는 보지 않는다.
if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    cache="$(mktemp -d)"; trap 'rm -rf "$cache"' EXIT
    blocks="$(while IFS= read -r f; do
        LC_ALL=C awk -v f="$f" '
            function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t\r]+$/, "", x); return x }
            # 한 줄의 백틱 조각에서 경로와 해시를 고른다.
            function source(line,   n, parts, i, p, h) {
                path = ""; hash = ""
                n = split(line, parts, "`")
                for (i = 2; i <= n; i += 2) {
                    p = parts[i]; h = p; sub(/ .*/, "", h)
                    if (hash == "" && h ~ /^[0-9a-f]+$/ && length(h) >= 7 && length(h) <= 40) hash = h
                    else if (path == "" && p !~ / / && p ~ /[\/.]/) path = p
                }
                if (path == "" || hash == "") { path = ""; hash = "" }
            }
            {
                t = trim($0)
                if (t ~ /^```/) {
                    if (inblock) { inblock = 0; side = ""; next }
                    if (path != "" && side != "") { inblock = 1; start = NR }
                    else skip = !skip
                    next
                }
                if (skip) next
                if (inblock) {
                    if (t == "" || t ~ /<redacted>/) next
                    if (t ~ /^[^A-Za-z0-9]*\.\.\.[^A-Za-z0-9]*$/) next
                    print f "\t" start "\t" path "\t" hash "\t" side "\t" t
                    next
                }
                if (t ~ /^#/ || t ~ /^- *(\*\*)?file(\*\*)?:/) { source(t); side = ""; next }
                if (t ~ /^\*\*전\*\*/ || t ~ /^- *(\*\*)?before(\*\*)?:/) { side = "before"; next }
                if (t ~ /^\*\*후\*\*/ || t ~ /^- *(\*\*)?after(\*\*)?:/) { side = "after"; next }
            }' "$work/$f"
    done <<< "$files")"
    excerpts=0; bad_blocks=""
    prev_key=""; dead_key=""; miss=0; first_miss=""
    flush() {
        [ -n "$prev_key" ] || return 0
        excerpts=$((excerpts + 1))
        if [ "$miss" -gt 0 ]; then
            bad_blocks="$bad_blocks$prev_msg ${miss}줄이 다릅니다 — 첫 줄: $first_miss$TAB"
        fi
        return 0
    }
    while IFS=$'\t' read -r f start path h side text; do
        [ -n "$f" ] || continue
        key="$f:$start"
        [ "$key" != "$dead_key" ] || continue         # 출처가 없는 블록의 나머지 줄
        if [ "$key" != "$prev_key" ]; then
            flush
            prev_key="$key"; miss=0; first_miss=""
            if [ "$side" = before ]; then rev="$h^"; label="전"; else rev="$h"; label="후"; fi
            prev_msg="$f:$start: $label 코드가 $rev:$path 와"
            # 캐시 키는 "<전체 커밋 해시>:<경로>"의 해시. 경로 글자를 바꿔 만든 키는 a/b.ts와 a_b.ts처럼 겹친다.
            full="$(git -C "$repo" rev-parse --verify -q "$rev^{commit}" 2>/dev/null || echo "$rev")"
            src="$cache/$(printf '%s:%s' "$full" "$path" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-64)"
            if [ ! -f "$src" ]; then
                if git -C "$repo" show "$rev:$path" 2>/dev/null |
                    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' > "$src"; then :; else
                    rm -f "$src"
                fi
            fi
            if [ ! -f "$src" ]; then
                bad_blocks="$bad_blocks$f:$start: $label 코드의 출처 $rev:$path 가 저장소에 없습니다(그 커밋 시점의 경로인지 확인)$TAB"
                prev_key=""; dead_key="$key"; continue
            fi
        fi
        grep -qxF -e "$text" "$src" || { miss=$((miss + 1)); [ -n "$first_miss" ] || first_miss="$text"; }
    done <<< "$blocks"
    flush
    each err <<< "$(printf '%s' "$bad_blocks" | tr '\t' '\n')"
    echo "코드 발췌 ${excerpts}개 대조"
fi

# 2. 이미지 경로
hits="$(while IFS= read -r f; do
    LC_ALL=C grep -oE 'images/[A-Za-z0-9._/-]+\.(webp|png|jpe?g|svg|gif)' "$work/$f" | sort -u |
        while IFS= read -r img; do [ -f "$work/$img" ] || echo "$f: 이미지 $img 가 없습니다"; done || true
done <<< "$files")"
each err <<< "$hits"

# 3. 사례 번호는 01부터 빈틈 · 중복 없이
if [ -d "$work/cases" ]; then
    nums="$(cd "$work/cases" && ls -1 | grep -E '^[0-9]{2}-.+\.md$' | grep -vE '\.new(-[0-9]{2})?\.md$' | cut -c1-2 || true)"
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

# 6. TODO — 정식 원고와 대체 원고(*.new.md · *.new-NN.md)를 나눠 센다. .reel/backup은 위 파일 목록에서 이미 빠진다.
todo_total=0; todo_alt=0
while IFS= read -r f; do
    c="$(grep -c 'TODO' "$work/$f" || true)"
    [ "$c" -gt 0 ] || continue
    if printf '%s' "$f" | grep -qE '\.new(-[0-9]{2})?\.md$'; then
        printf '  TODO %3d  %s (대체 원고)\n' "$c" "$f"; todo_alt=$((todo_alt + c))
    else
        printf '  TODO %3d  %s\n' "$c" "$f"; todo_total=$((todo_total + c))
    fi
done <<< "$files"

# 7. 제출본 검사(--public): 지원서에 붙일 원고에 내부 흔적이 남지 않았는지. TODO 말고는 코드 블록 밖만 본다
if [ "$public" -eq 1 ]; then
    for f in "${public_files[@]}"; do
        if [ ! -f "$work/$f" ]; then warn "제출본 $f 가 없습니다"; continue; fi
        hits="$(awk -v f="$f" '
            /TODO/ { print f ":" NR ": TODO가 남았습니다"; next }
            /^[[:space:]]*```/ { code = !code; next }
            code { next }
            /<!--/ { print f ":" NR ": HTML 주석이 남았습니다(렌더링하면 안 보여도 복사하면 따라갑니다)"; next }
            /(\/Users\/|\/home\/|[A-Za-z]:\\|~\/)/ { print f ":" NR ": 로컬 경로가 남았습니다" ; next }
            /(localhost|127\.0\.0\.1|0\.0\.0\.0|192\.168\.|(^|[^0-9.])10\.[0-9]+\.[0-9]+\.[0-9]+|(^|[^0-9.])172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|\.local([^A-Za-z]|$)|\.internal([^A-Za-z]|$))/ {
                print f ":" NR ": 내부 주소가 남았습니다"; next }
            /\.reel\// { print f ":" NR ": reel 상태 경로가 남았습니다" }
        ' "$work/$f")"
        each err <<< "$hits"
        hits="$(grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$work/$f" | cut -d: -f1 |
            sed "s|^|$f:|; s|$|: 이메일 — 연락처가 아니면 빼세요|" || true)"
        each warn <<< "$hits"
    done
    echo "제출본 검사: ${public_files[*]}"
fi

echo "오류 $errors · 경고 $warns · TODO $todo_total · 대체 원고 TODO $todo_alt"
[ "$errors" -eq 0 ]
