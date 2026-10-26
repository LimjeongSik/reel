#!/usr/bin/env bash
# 스크립트 회귀 테스트. 임시 git 저장소와 work/를 만들어 work-guard.sh · check-work.sh · to-webp.sh를 돌린다.
#
# 사용법: tests/run.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/shared/scripts/work-guard.sh"
check="$root/shared/scripts/check-work.sh"
webp="$root/skills/shots/scripts/to-webp.sh"
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
expect_code "head: 기록 전엔 1" 1 "$guard" head "$w"
"$guard" head "$w" "$c2"
expect_code "head: 읽기" 0 "$guard" head "$w"
expect_out  "head: 기록한 값" "$c2"

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
expect_out  "TODO 집계" "TODO 1"

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
