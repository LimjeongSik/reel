#!/usr/bin/env bash
# 커밋 이력을 변경 기록 재료로 정리한다: 커밋마다 분류(기능 · 개선 · 수정 …), 바뀐 파일 · 줄 수, 테스트 파일,
# 메시지에 적힌 수치, 본문(변경 이유) 유무. 숫자는 여기서 세고, 원고는 이 출력에 있는 값만 쓴다.
#
# 사용법: change-log.sh <저장소> [범위=HEAD] [--author <이메일>]... [-- <경로>...]
#   범위: git log 범위(예: HEAD, abc1234..def5678). 증분이면 실행 시작 때 고정한 <from>..<to>를 넘긴다.
#   --author: 정규식이 아니라 글자 그대로 찾는다(이메일의 . + 도 안전). 여러 번 주면 그중 하나라도 맞는 커밋.
#             "이름 <이메일>" 전체에서 찾으므로 이름보다 이메일을 넘긴다.
#   -- <경로>: 모노레포 하위 폴더처럼 그 경로를 건드린 커밋만, 파일 · 줄 수도 그 경로 안에서만 센다.
set -euo pipefail

[ $# -ge 1 ] || { sed -n 2,10p "$0"; exit 1; }
repo="$1"; shift
range=HEAD
case "${1:-}" in ''|--*) ;; *) range="$1"; shift ;; esac
authors=(); paths=()
while [ $# -gt 0 ]; do
    case "$1" in
        --author) [ $# -ge 2 ] || { echo "--author 뒤에 값이 없습니다"; exit 1; }; authors+=("$2"); shift 2 ;;
        --author=*) authors+=("${1#--author=}"); shift ;;
        --) shift; paths=("$@"); break ;;
        *) echo "알 수 없는 인자: $1"; exit 1 ;;
    esac
done
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "git 저장소가 아닙니다: $repo"; exit 1; }

args=(--no-merges --reverse --format=%h)
if [ ${#authors[@]} -gt 0 ]; then
    args+=(--fixed-strings)
    for a in "${authors[@]}"; do args+=("--author=$a"); done
fi
# bash 3.2에서 빈 배열을 set -u로 펼치면 멈추므로 ${a[@]+...} 꼴로 넘긴다.
hashes="$(git -C "$repo" log "${args[@]}" "$range" -- ${paths[@]+"${paths[@]}"})"
[ -n "$hashes" ] || { echo "범위 $range 에 커밋이 없습니다."; exit 1; }

# 분류: Conventional Commits 접두사를 먼저 보고, 없으면 메시지 낱말로 짐작한다.
# 개선(perf · refactor)과 수정(fix)을 기능(feat)과 나눠야 "무엇이 나아졌나"를 따로 모을 수 있다.
classify() {
    local s="$1" low
    low="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
    case "$low" in
        revert*) echo revert; return ;;
    esac
    local p
    p="$(printf '%s' "$low" | LC_ALL=C sed -nE 's/^(feat|fix|perf|refactor|test|docs|chore|build|ci|style)(\([^)]*\))?!?:.*/\1/p')"
    if [ -n "$p" ]; then echo "$p"; return; fi
    if printf '%s' "$low" | grep -qE '성능|최적화|빠르게|속도|느린|지연|perf|optimi|faster|speed'; then echo perf
    elif printf '%s' "$low" | grep -qE '버그|오류|에러|수정|고침|고쳐|안 되|안되|깨지|crash|fix|bug'; then echo fix
    elif printf '%s' "$low" | grep -qE '리팩터|리팩토링|정리|분리|개선|단순화|refactor|cleanup|clean up|simplif|improve'; then echo refactor
    elif printf '%s' "$low" | grep -qE '문서|readme|docs?([^a-z]|$)'; then echo docs
    elif printf '%s' "$low" | grep -qE '테스트|test'; then echo test
    elif printf '%s' "$low" | grep -qE '추가|구현|도입|지원|새 |add|implement|support|introduce'; then echo feat
    else echo etc; fi
}

# 메시지에 적힌 수치: 단위가 붙은 숫자와 "a → b" 꼴. 지어낸 값이 아니라 작성자가 남긴 값만 뽑는다.
numbers_in() {
    printf '%s\n' "$1" | LC_ALL=C grep -oE '[0-9][0-9,.]*[ ]?(ms|초|분|%|KB|kB|MB|GB|fps|배|x)?[ ]?(→|->)[ ]?[0-9][0-9,.]*[ ]?(ms|초|분|%|KB|kB|MB|GB|fps|배|x)?|[0-9][0-9,.]*[ ]?(ms|초|%|KB|kB|MB|GB|fps|배)' |
        sort -u | paste -sd ',' - | sed 's/,/, /g' || true
}

is_test() { printf '%s' "$1" | grep -qE '(^|/)(__tests__|tests?|spec)/|\.(test|spec)\.|_test\.'; }

total=0
rows=""
sums=""   # 분류<TAB>파일<TAB>+<TAB>-
for h in $hashes; do
    subject="$(git -C "$repo" show -s --format=%s "$h")"
    body="$(git -C "$repo" show -s --format=%b "$h" | grep -vE '^(Co-Authored-By|Signed-off-by):' | sed '/^[[:space:]]*$/d' || true)"
    date="$(git -C "$repo" show -s --format=%ad --date=format:%Y.%m.%d "$h")"
    type="$(classify "$subject")"
    files=0; add=0; del=0; tests=0
    while IFS=$'\t' read -r a d path; do
        [ -n "${path:-}" ] || continue
        files=$((files + 1))
        [ "$a" = "-" ] || add=$((add + a))
        [ "$d" = "-" ] || del=$((del + d))
        if is_test "$path"; then tests=$((tests + 1)); fi
    done <<< "$(git -C "$repo" show --numstat --format= "$h" -- ${paths[@]+"${paths[@]}"})"
    nums="$(numbers_in "$subject
$body")"
    blines=0; [ -z "$body" ] || blines="$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
    pr="$(printf '%s' "$subject" | LC_ALL=C grep -oE '\(#[0-9]+\)' | tr -d '()' | head -1 || true)"
    reason="없음"; [ "$blines" -eq 0 ] || reason="${blines}줄"
    [ -z "$pr" ] || reason="$reason · PR $pr"
    esc="$(printf '%s' "$subject" | sed 's/|/\\|/g')"
    rows="$rows| \`$h · $date\` | $type | $esc | $files | +$add/-$del | $tests | ${nums:--} | $reason |
"
    sums="$sums$type	$files	$add	$del
"
    total=$((total + 1))
done

echo "# 변경 기록 재료"
echo
who="전체"; [ ${#authors[@]} -eq 0 ] || who="$(printf '%s, ' "${authors[@]}" | sed 's/, $//')"
where="전체"; [ ${#paths[@]} -eq 0 ] || where="$(printf '%s, ' "${paths[@]}" | sed 's/, $//')"
echo "범위: \`$range\` · 작성자: $who · 경로: $where · 커밋 ${total}개(병합 제외)"
echo
echo "## 분류별"
echo
echo "| 분류 | 묶음 | 커밋 | 파일 | +줄 | -줄 |"
echo "|---|---|---|---|---|---|"
printf '%s' "$sums" | awk -F'\t' '
    NF { c[$1]++; f[$1] += $2; a[$1] += $3; d[$1] += $4 }
    END {
        n = split("feat perf refactor fix revert test docs build ci chore style etc", order, " ")
        g["feat"] = "기능"; g["perf"] = "개선"; g["refactor"] = "개선"; g["fix"] = "수정"; g["revert"] = "수정"
        for (i = 1; i <= n; i++) { t = order[i]; if (t in c)
            printf "| %s | %s | %d | %d | %d | %d |\n", t, (t in g ? g[t] : "기타"), c[t], f[t], a[t], d[t] }
    }'
echo
echo "## 커밋 (오래된 순)"
echo
echo "| 커밋 | 분류 | 제목 | 파일 | 줄 | 테스트 파일 | 메시지 속 수치 | 본문(이유) |"
echo "|---|---|---|---|---|---|---|---|"
printf '%s' "$rows"
