---
description: 하이라이트 릴 한 편 뽑기 — 현재 프로젝트를 분석해 work/ 폴더에 이력서 · 포트폴리오 원고(md)와 화면 이미지를 만듭니다
argument-hint: "[all|resume|portfolio|images] [대상 경로] [--full]"
---

사용자 인자: $ARGUMENTS

인자에서 모드(기본 `all`), 대상 경로(기본 현재 디렉터리), `--full`(처음부터 다시 분석) 여부를 읽는다.
결과는 모두 `<대상 경로>/work/`에 쓴다. 스크립트는 플러그인 폴더의 `shared/scripts/`에 있다(scout 스킬 폴더 기준 `../../shared/scripts/`).

0. **준비.** `work-guard.sh begin <대상 경로>/work`. 출력된 파일별 상태(`edited` · `unknown` · `alt`)를 기억해 둔다 —
   이후 모든 쓰기는 `shared/work-layout.md`의 덮어쓰기 규칙(check → 쓰기 → record, 대체 원고도 record)을 따른다.
   `begin`이 이번 실행 목록을 비우므로, 이후 "이번 실행에서 쓴 파일"은 `work-guard.sh run work`로 본다.
   **범위를 고정한다**(`shared/work-layout.md` "단계별 기준 커밋"): `TO`는 지금 HEAD, 이번 모드가 지나는 단계마다
   `FROM`은 `work-guard.sh mark work <단계>`(`--full`이면 모두 비움). 각 스킬에 그 단계의 `FROM`/`TO`를 넘기고,
   스킬은 `HEAD`가 아니라 이 범위로 읽는다. 단계 이름: scout=`profile` · clips=`cases` · shots=`images` · `resume` · `portfolio`.
1. **scout** 스킬 → `work/profile.md`. scout가 FROM/TO를 보고 전체 분석 · 증분 분석 · 건너뛰기를 정한다.
   끝나면 "확인 필요" 목록을 사용자에게 한 번에 묻고, 답을 반영한 뒤 진행한다(사용자가 "나중에"라고 하면 `TODO`로 남기고 진행).
   이번 모드의 모든 단계가 이미 `TO`까지 반영됐고(`mark`가 모두 `TO`) 작업 트리가 깨끗하면, 다시 쓸지 묻고 아니라면 4번(검수)으로 간다.
2. 모드별로:
   - `all`: clips → shots → resume → portfolio
   - `resume`: clips → resume
   - `portfolio`: clips → shots → portfolio
   - `images`: shots만
   이미 `work/cases/`가 있으면 clips는 새 사례 후보만 추가한다(clips 스킬 0장). 기존 사례를 다시 뽑는 건 `--full`이거나 사용자가 원할 때만.
   **단계가 끝날 때마다 `run`을 본다.** 그 단계의 줄에 `alt`가 있으면 그 원고를 읽는 뒤 단계로 넘어가기 전에
   `shared/work-layout.md` "입력"대로 채택(`work-guard.sh adopt`) · 이번만 대체 원고로 · 기존 원고 유지를 묻는다(1번의 profile도 같다).
   "이번만 대체 원고로"를 고르면 뒤 스킬에 읽을 입력 경로를 명시해 넘긴다. 답을 받을 수 없으면 뒤 단계를 보류한다.
   여기서는 `mark`를 남기지 않는다 — 5번에서 검수 결과를 보고 남긴다.

   **이 커맨드 안에서 부른 스킬은 각자 마무리하지 않는다.** 스킬 문서의 마지막 질문(사례 목록 확인, 이유가 빈 묶음,
   이력서 확인 필요 등)과 `check-work.sh`는 건너뛰고, 쓴 파일 · 질문할 항목만 돌려준다. 질문은 3번에서 한 번에 묻는다.
   예외: "어느 커밋이 내 것인가"처럼 답이 없으면 다음 단계가 남의 작업을 쓰게 되는 질문은 그 자리에서 묻는다.
3. **모아서 묻는다.** 2번의 스킬들이 돌려준 질문을 단계별로 묶어 한 번에 묻는다. 답은 `run`에 `canon` · `alt`로 나온 파일에만
   반영하고 `record`한다. 그 밖의 파일(지난 실행 파일, 사람이 고친 원고)에 반영할 내용은 `check`가 준 대체 경로에 쓴다.
4. **검수.** `check-work.sh <대상 경로>/work`. 오류(✗)는 `shared/work-layout.md` "마무리 점검"대로 고친다 —
   `run`에 `canon` · `alt`로 나온 파일은 고치고 다시 `record`, 그 밖의 파일은 고치지 않고 보고한다. 고쳤으면 다시 돌린다.
5. **완료 기록.** 이번 모드가 지난 단계마다 `shared/work-layout.md` "완료 기록"의 조건(그 단계 파일이 모두 `canon`,
   그 단계 파일에 남은 ✗ 없음, 입력이 모두 정식 원고)을 확인하고, 만족하는 단계만 `work-guard.sh mark work <단계> <TO>`.
6. `work/README.md`를 갱신한다(덮어쓰기 규칙을 따른다): 만들어진 파일과 각각의 쓰임(어느 지원서 칸 · 사이트 필드에 쓰는지),
   `TODO` 모음(4번 출력의 파일별 TODO — `grep -r`은 `.reel/backup/`까지 잡으므로 쓰지 않는다. 정식 원고와 대체 원고를 나눠 적는다),
   찍지 못한 화면, 이번에 생긴 `*.new*.md`, 단계별 반영한 커밋(`begin` 출력의 `mark`와 5번에서 남긴 값), 보류한 단계.
   README도 `record`한다(단계에는 속하지 않는다).
7. 사용자에게는 짧게 보고한다: 만든 파일 목록, 사례 제목들, 채워야 할 TODO 개수(정식 · 대체), 점검 결과(오류 · 경고 수),
   `*.new*.md`로 비켜 쓴 파일, 완료 기록을 남기지 않은 단계와 이유(대체 원고 · 남은 오류 · 대체 입력), 보류한 단계.
   원고 전문을 대화에 붙여 넣지 않는다.
