---
description: 하이라이트 릴 한 편 뽑기 — 현재 프로젝트를 분석해 work/ 폴더에 이력서 · 포트폴리오 원고(md)와 화면 이미지를 만듭니다
argument-hint: "[all|resume|portfolio|images] [대상 경로] [--full]"
---

사용자 인자: $ARGUMENTS

인자에서 모드(기본 `all`), 대상 경로(기본 현재 디렉터리), `--full`(처음부터 다시 분석) 여부를 읽는다.
결과는 모두 `<대상 경로>/work/`에 쓴다. 스크립트는 플러그인 폴더의 `shared/scripts/`에 있다(scout 스킬 폴더 기준 `../../shared/scripts/`).

0. `work-guard.sh begin <대상 경로>/work`. 출력된 파일별 상태(`edited` · `unknown`)를 기억해 둔다 —
   이후 모든 쓰기는 `shared/work-layout.md`의 덮어쓰기 규칙(check → 쓰기 → record)을 따른다.
1. **scout** 스킬 → `work/profile.md`. scout가 `head` 기록을 보고 전체 분석 · 증분 분석 · 건너뛰기를 정한다(`--full`이면 전체).
   끝나면 "확인 필요" 목록을 사용자에게 묻고, 답을 반영한 뒤 진행한다(사용자가 "나중에"라고 하면 `TODO`로 남기고 진행).
   scout가 "변경 없음"으로 건너뛰었고 이번 모드의 결과 파일이 이미 다 있으면, 다시 쓸지 묻고 아니라면 4번으로 간다.
2. 모드별로:
   - `all`: clips → shots → resume → portfolio
   - `resume`: clips → resume
   - `portfolio`: clips → shots → portfolio
   - `images`: shots만
   이미 `work/cases/`가 있으면 clips는 새 사례 후보만 추가한다(clips 스킬 0장). 기존 사례를 다시 뽑는 건 `--full`이거나 사용자가 원할 때만.
3. `work/README.md`를 갱신한다: 만들어진 파일과 각각의 쓰임(어느 지원서 칸 · 사이트 필드에 쓰는지),
   모든 파일의 `TODO` 모음(`grep -rn TODO work/`), 찍지 못한 화면, 이번에 생긴 `*.new.md`.
4. `check-work.sh <대상 경로>/work`. 오류(✗)가 있으면 해당 원고를 고치고 다시 돌린다. 끝까지 남는 오류는 보고에 적는다.
5. 사용자에게는 짧게 보고한다: 만든 파일 목록, 사례 제목들, 채워야 할 TODO 개수, 점검 결과(오류 · 경고 수),
   `*.new.md`로 비켜 쓴 파일. 원고 전문을 대화에 붙여 넣지 않는다.
