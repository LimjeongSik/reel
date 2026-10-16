---
description: 하이라이트 릴 한 편 뽑기 — 현재 프로젝트를 분석해 work/ 폴더에 이력서 · 포트폴리오 원고(md)와 화면 이미지를 만듭니다
argument-hint: "[all|resume|portfolio|images] [대상 경로]"
---

사용자 인자: $ARGUMENTS

인자에서 모드(기본 `all`)와 대상 경로(기본 현재 디렉터리)를 읽는다. 결과는 모두 `<대상 경로>/work/`에 쓴다.

1. **scout** 스킬 → `work/profile.md`. 끝나면 "확인 필요" 목록을 사용자에게 묻고, 답을 반영한 뒤 진행한다
   (사용자가 "나중에"라고 하면 `TODO`로 남기고 진행).
2. 모드별로:
   - `all`: clips → shots → resume → portfolio
   - `resume`: clips → resume
   - `portfolio`: clips → shots → portfolio
   - `images`: shots만
   이미 `work/cases/`가 있으면 다시 뽑을지 물어본다.
3. `work/README.md`를 갱신한다: 만들어진 파일과 각각의 쓰임(어느 지원서 칸 · 사이트 필드에 쓰는지),
   모든 파일의 `TODO` 모음(`grep -rn TODO work/`), 찍지 못한 화면.
4. 사용자에게는 짧게 보고한다: 만든 파일 목록, 사례 제목들, 채워야 할 TODO 개수. 원고 전문을 대화에 붙여 넣지 않는다.
