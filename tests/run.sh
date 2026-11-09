#!/usr/bin/env bash
# 스크립트 회귀 테스트. 임시 git 저장소와 work/를 만들어 work-guard.sh · check-work.sh · change-log.sh · to-webp.sh를 돌린다.
#
# 사용법: tests/run.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/shared/scripts/work-guard.sh"
check="$root/shared/scripts/check-work.sh"
webp="$root/skills/shots/scripts/to-webp.sh"
changes="$root/skills/portfolio/scripts/change-log.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

ok()   { printf '  ✓ %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  ✗ %s\n' "$1"; fail=$((fail + 1)); }
expect_code() { # <설명> <기대 종료 코드> <명령...>
    local name="$1" want="$2"; shift 2
    "$@" >"$tmp/out" 2>&1; local got=$?
    if [ "$got" -eq "$want" ]; then ok "$name"; else bad "$name (종료 코드 $got, 기대 $want)"; sed 's/^/      /' "$tmp/out"; fi
}
expect_out() { # <설명> <찾을 문자열>
    if grep -qF -- "$2" "$tmp/out"; then ok "$1"; else bad "$1 — '$2' 없음"; sed 's/^/      /' "$tmp/out"; fi
}

# 테스트 저장소: 날짜를 고정한 커밋 두 개
repo="$tmp/repo"; mkdir -p "$repo"; cd "$repo" || exit 1
git init -q; git config user.name tester; git config user.email t@example.com
echo a > a.txt; git add a.txt
GIT_AUTHOR_DATE='2026-07-12T10:00:00' GIT_COMMITTER_DATE='2026-07-12T10:00:00' git commit -qm first
c1="$(git rev-parse --short=7 HEAD)"
echo b >> a.txt
GIT_AUTHOR_DATE='2026-07-14T10:00:00' GIT_COMMITTER_DATE='2026-07-14T10:00:00' git commit -qam second
c2="$(git rev-parse --short=7 HEAD)"
w="$repo/work"

echo "work-guard.sh"
expect_code "begin: 빈 work/" 0 "$guard" begin "$w"
expect_out  "begin: 처음 실행 안내" "처음 실행"
[ -f "$w/.gitignore" ] && ok ".gitignore 생성" || bad ".gitignore 생성"
expect_code "work/가 git에서 빠짐" 0 git -C "$repo" check-ignore -q work/profile.md

expect_code "check: 없는 파일은 new" 0 "$guard" check "$w" profile.md
echo v1 > "$w/profile.md"
expect_code "check: 기록 없는 파일은 unknown" 1 "$guard" check "$w" profile.md
expect_out  "check: 대신 쓸 경로" "profile.new.md"
expect_code "record" 0 "$guard" record "$w" profile.md
expect_code "check: 기록 그대로면 clean" 0 "$guard" check "$w" profile.md
echo "사람이 고침" >> "$w/profile.md"
expect_code "check: 고친 파일은 edited" 1 "$guard" check "$w" profile.md
mkdir -p "$w/cases"; echo x > "$w/cases/01-a.md"
expect_code "record: 하위 폴더" 0 "$guard" record "$w" cases/01-a.md
expect_code "check: 하위 폴더 clean" 0 "$guard" check "$w" cases/01-a.md
expect_code "begin: 다시 실행" 0 "$guard" begin "$w"
expect_out  "begin: 고친 파일 표시" "edited   profile.md"
expect_out  "begin: 그대로인 파일 표시" "clean    cases/01-a.md"
ls "$w/.reel/backup/"*/profile.md >/dev/null 2>&1 && ok "begin: md 백업" || bad "begin: md 백업"
expect_code "check: 고친 파일의 대체 경로" 1 "$guard" check "$w" profile.md
expect_out  "대체 경로는 profile.new.md" "edited → profile.new.md"
echo "사람이 고친 대체 원고" > "$w/profile.new.md"
expect_code "check: 대체 원고가 있으면" 1 "$guard" check "$w" profile.md
expect_out  "다음 빈 경로" "edited → profile.new-02.md"
echo x > "$w/profile.new-02.md"
expect_code "check: 그다음 빈 경로" 1 "$guard" check "$w" profile.md
expect_out  "new-03" "profile.new-03.md"
rm "$w/profile.new-02.md"
expect_code "begin: 대체 원고 포함" 0 "$guard" begin "$w"
expect_out  "begin: 대체 원고 상태" "alt      profile.new.md"
b="$(ls -1d "$w/.reel/backup/"* | sort | tail -1)"
[ -f "$b/profile.new.md" ] && ok "begin: 대체 원고도 백업" || bad "begin: 대체 원고도 백업"
rm "$w/profile.new.md"

echo "run: 이번 실행에서 쓴 파일"
expect_code "begin: 새 실행" 0 "$guard" begin "$w"
"$guard" run "$w" >"$tmp/out" 2>&1
[ ! -s "$tmp/out" ] && ok "run: begin 직후 비어 있음" || bad "run: begin 직후 비어 있음"
"$guard" record "$w" cases/01-a.md
echo "대체" > "$w/profile.new.md"
expect_code "record: 대체 원고" 0 "$guard" record "$w" profile.new.md
expect_code "run" 0 "$guard" run "$w"
expect_out  "run: 정식 원고는 canon · 단계" "cases     canon   cases/01-a.md"
expect_out  "run: 대체 원고는 alt · 단계" "profile   alt     profile.new.md"
if grep -qF "profile.new.md" "$w/.reel/manifest"; then bad "record: 대체 원고는 manifest에 안 올림"; else ok "record: 대체 원고는 manifest에 안 올림"; fi
expect_code "check: 대체 원고는 여전히 덮어쓰지 않음" 1 "$guard" check "$w" profile.new.md
echo "사람이 실행 중에 고침" >> "$w/cases/01-a.md"
"$guard" run "$w" >"$tmp/out" 2>&1
expect_out  "run: 쓴 뒤 고쳐지면 changed" "changed cases/01-a.md"
echo "지난 실행 파일" > "$w/resume.md"; "$guard" record "$w" resume.md
expect_code "begin: 다음 실행" 0 "$guard" begin "$w"
expect_code "check: 지난 실행 파일은 clean" 0 "$guard" check "$w" resume.md
"$guard" run "$w" >"$tmp/out" 2>&1
if grep -qF "resume.md" "$tmp/out"; then bad "run: 지난 실행 파일은 목록에 없음"; else ok "run: 지난 실행 파일은 목록에 없음"; fi
rm -f "$w/profile.new.md" "$w/resume.md"

echo "adopt: 대체 원고 작성 → 채택 → 검수 → 완료 기록"
echo "사람이 고친 profile" > "$w/profile.md"            # 기록 없는 정식 원고 → 대체 경로로 비켜 씀
expect_code "begin" 0 "$guard" begin "$w"
expect_code "check: 비켜 쓸 경로" 1 "$guard" check "$w" profile.md
expect_out  "대체 경로" "profile.new.md"
printf '# p\n- 관련 커밋: `%s · 2026.07.12`\n' "$c1" > "$w/profile.new.md"
"$guard" record "$w" profile.new.md
"$guard" run "$w" >"$tmp/out" 2>&1
expect_out  "채택 전엔 alt" "profile   alt     profile.new.md"
expect_code "adopt" 0 "$guard" adopt "$w" profile.new.md profile.md
expect_out  "덮인 정식 원고 백업" "-adopt/profile.md"
[ ! -e "$w/profile.new.md" ] && ok "adopt: 대체 파일은 옮겨짐" || bad "adopt: 대체 파일은 옮겨짐"
grep -qF "$c1" "$w/profile.md" && ok "adopt: 정식 경로에 대체 원고 내용" || bad "adopt: 정식 경로에 대체 원고 내용"
grep -rqF "사람이 고친 profile" "$w/.reel/backup/"*-adopt/profile.md && ok "adopt: 백업에 사람이 고친 판" || bad "adopt: 백업에 사람이 고친 판"
"$guard" run "$w" >"$tmp/out" 2>&1
expect_out  "채택 뒤엔 canon" "profile   canon   profile.md"
if grep -qE 'alt|changed' "$tmp/out"; then bad "채택 뒤 alt · changed 행 없음"; else ok "채택 뒤 alt · changed 행 없음"; fi
expect_code "check: 채택한 정식 원고는 clean" 0 "$guard" check "$w" profile.md
rm -rf "$w/cases" "$w/portfolio.md"
expect_code "검수 통과" 0 "$check" "$w"
"$guard" mark "$w" profile "$c2"
expect_code "완료 기록" 0 "$guard" mark "$w" profile
expect_out  "완료 기록 값" "$c2"
expect_code "adopt: 대체 원고가 아니면 실패" 1 "$guard" adopt "$w" profile.md resume.md
mkdir -p "$w/cases"; echo x > "$w/cases/01-a.md"; "$guard" record "$w" cases/01-a.md
rm -f "$w/.reel/marks"                                   # 아래 mark 테스트는 기록이 없는 상태에서 시작

expect_code "mark: 기록 전엔 1" 1 "$guard" mark "$w" portfolio
expect_code "head: 기록 전엔 1" 1 "$guard" head "$w"
echo "$c1" > "$w/.reel/head"
expect_code "head: 0.4.0의 .reel/head를 profile 기준으로" 0 "$guard" mark "$w" profile
expect_out  "옛 기록 값" "$c1"
"$guard" head "$w" "$c2"
expect_code "head: 읽기" 0 "$guard" head "$w"
expect_out  "head: 기록한 값" "$c2"
"$guard" mark "$w" resume "$c1"
expect_code "mark: 단계별로 따로" 0 "$guard" mark "$w" resume
expect_out  "resume 기준" "$c1"
expect_code "mark: 다른 단계는 그대로 없음" 1 "$guard" mark "$w" portfolio
"$guard" mark "$w" resume "$c2"
"$guard" mark "$w" resume >"$tmp/out" 2>&1
expect_out  "mark: 덮어씀" "$c2"
expect_code "begin: 단계별 기준 출력" 0 "$guard" begin "$w"
expect_out  "begin: mark 출력" "mark: resume $c2"

echo "check-work.sh"
rm -rf "$w/cases" "$w/profile.md"; mkdir -p "$w/cases" "$w/images"
cat > "$w/cases/01-ok.md" <<EOF
# ① 정상 사례
- 관련 커밋: \`$c1 · 2026.07.12\`, \`$c2 · 2026.07.14\`
EOF
expect_code "정상 원고는 통과" 0 "$check" "$w"
expect_out  "커밋 인용 수" "커밋 인용 2건"

cat > "$w/cases/02-bad.md" <<EOF
# ② <사례 제목>
- 관련 커밋: \`$c1 · 2026.08.01\`, \`abc1234 · 2026.07.12\`
- 전 → 후 (\`def5678\`)
이 문제를 캐시를 통해 해결했습니다. <!-- TODO: 수치 -->
\`\`\`ts
// 코드 안의 "를 통해"는 표현 검사에서 뺀다
\`\`\`
EOF
cat > "$w/portfolio.md" <<'EOF'
| thumbnail | images/demo-thumb.webp |
| icon | images/demo-icon.webp |
EOF
touch "$w/images/demo-icon.webp"
echo x > "$w/cases/04-gap.md"
expect_code "문제 있는 원고는 실패" 1 "$check" "$w"
expect_out  "날짜 불일치" "날짜가 2026.08.01 로 적혀 있지만 실제는 2026.07.12"
expect_out  "없는 커밋" "커밋 abc1234 가 저장소에 없거나"
expect_out  "백틱 속 해시만 있는 꼴" "커밋 def5678 가 저장소에 없거나"
expect_out  "없는 이미지" "images/demo-thumb.webp 가 없습니다"
if grep -qF "demo-icon.webp" "$tmp/out"; then bad "있는 이미지는 통과"; else ok "있는 이미지는 통과"; fi
expect_out  "사례 번호 빈틈" "03번이 비어 있습니다"
expect_out  "자리표시자" "<사례 제목>"
expect_out  "피할 표현" "캐시를 통해"
if grep -qF '코드 안의' "$tmp/out"; then bad "코드 블록은 표현 검사 제외"; else ok "코드 블록은 표현 검사 제외"; fi
expect_out  "TODO 집계" "TODO 1 · 대체 원고 TODO 0"
printf '<!-- TODO: a -->\n<!-- TODO: b -->\n' > "$w/portfolio.new-02.md"
echo x > "$w/cases/03-alt.new.md"
"$check" "$w" >"$tmp/out" 2>&1
expect_out  "대체 원고 TODO 따로" "대체 원고 TODO 2"
expect_out  "대체 원고 표시" "portfolio.new-02.md (대체 원고)"
expect_out  "대체 사례 파일은 번호에서 제외" "03번이 비어 있습니다"
mkdir -p "$w/.reel/backup/x"; echo "TODO" > "$w/.reel/backup/x/old.md"
"$check" "$w" >"$tmp/out" 2>&1
if grep -qF "old.md" "$tmp/out"; then bad "백업은 TODO에서 제외"; else ok "백업은 TODO에서 제외"; fi
rm -f "$w/portfolio.new-02.md" "$w/cases/03-alt.new.md"

echo "change-log.sh"
mkdir -p "$repo/src/__tests__"
echo 'it("a")' > "$repo/src/__tests__/a.test.ts"; echo x > "$repo/src/list.ts"; git -C "$repo" add src
GIT_AUTHOR_DATE='2026-07-20T10:00:00' GIT_COMMITTER_DATE='2026-07-20T10:00:00' \
    git -C "$repo" commit -qm 'perf(list): 목록 렌더링을 가상화 (#12)' -m '렌더링 1300ms → 32ms (프로파일러 측정)'
c3="$(git -C "$repo" rev-parse --short=7 HEAD)"
GIT_AUTHOR_DATE='2026-07-21T10:00:00' GIT_COMMITTER_DATE='2026-07-21T10:00:00' \
    git -C "$repo" commit -q --allow-empty -m '로그인 후 빈 화면이 뜨는 버그 수정'
expect_code "전체 범위" 0 "$changes" "$repo"
expect_out  "커밋 수" "커밋 4개"
expect_out  "오래된 순 · 해시와 날짜" "| \`$c1 · 2026.07.12\` |"
expect_out  "접두사로 분류 · 파일 · 줄 · 테스트 파일" "| perf | perf(list): 목록 렌더링을 가상화 (#12) | 2 | +2/-0 | 1 |"
expect_out  "메시지 속 수치" "1300ms → 32ms"
expect_out  "본문 · PR 번호" "1줄 · PR #12"
expect_out  "낱말로 분류" "| fix | 로그인 후 빈 화면이 뜨는 버그 수정 |"
expect_out  "개선 묶음" "| perf | 개선 | 1 |"
expect_code "증분 범위" 0 "$changes" "$repo" "$c3..HEAD"
expect_out  "증분 커밋 수" "커밋 1개"
expect_code "작성자가 없으면 실패" 1 "$changes" "$repo" HEAD --author nobody@example.com
expect_out  "커밋 없음 안내" "커밋이 없습니다"
GIT_AUTHOR_DATE='2026-07-22T10:00:00' GIT_COMMITTER_DATE='2026-07-22T10:00:00' \
    git -C "$repo" -c user.name=other -c user.email='o.k+1@example.com' commit -q --allow-empty -m 'feat: 다른 사람 기능 추가'
expect_code "작성자 여러 명은 OR · 특수문자는 글자 그대로" 0 "$changes" "$repo" --author t@example.com --author 'o.k+1@example.com'
expect_out  "두 작성자 커밋 수" "커밋 5개"
expect_code "작성자 하나" 0 "$changes" "$repo" HEAD --author 'o.k+1@example.com'
expect_out  "한 사람 커밋 수" "커밋 1개"
expect_code "점은 아무 글자가 아님" 1 "$changes" "$repo" HEAD --author 'oXk+1@example.com'
expect_code "경로로 거르기" 0 "$changes" "$repo" HEAD -- src
expect_out  "경로 커밋 수" "커밋 1개"
expect_out  "경로 표시" "경로: src"
expect_code "알 수 없는 인자" 1 "$changes" "$repo" HEAD nobody

echo "to-webp.sh"
if command -v cwebp >/dev/null && command -v python3 >/dev/null; then
    # 2000x10 PNG를 만들어 1080으로 줄어드는지 본다.
    python3 - "$tmp/wide.png" <<'PY'
import sys, zlib, struct
w, h = 2000, 10
raw = b''.join(b'\x00' + b'\xff\x00\x00' * w for _ in range(h))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                              + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
PY
    expect_code "변환" 0 "$webp" "$tmp/wide.png" "$tmp/out-webp" 1080
    if command -v webpinfo >/dev/null; then
        webpinfo "$tmp/out-webp/wide.webp" >"$tmp/out" 2>&1
        expect_out "폭을 1080으로 줄임" "Width: 1080"
    fi
else
    echo "  - cwebp 또는 python3가 없어 건너뜀"
fi

echo
echo "통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ]
