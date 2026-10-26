---
name: portfolio
description: work/profile.md, work/cases/, work/images/를 바탕으로 포트폴리오 사이트 · 노션 · PDF 포트폴리오에 옮길 원고 work/portfolio.md를 쓴다. 프로젝트 카드(제목 · 한 줄 · 기간 · 역할 · 기술), 배경(context), 접근(approach), 사례(문제/해결/결과 + 수치 + 전/후 코드), 화면 갤러리(이미지 · 이름 · 설명), 링크를 필드 단위로 정리해 사이트 데이터 파일에 그대로 옮길 수 있게 한다. "포트폴리오 만들어줘", "포트폴리오 사이트에 이 프로젝트 추가", "케이스 스터디", "노션 포트폴리오" 요청이나 /reel:cut portfolio 실행 시 사용한다.
---

# 포트폴리오 원고 → work/portfolio.md

먼저 이 스킬 폴더 기준 `../../shared/writing-rules.md`를 읽는다.
입력: `work/profile.md`, `work/cases/*.md`, `work/images/images.md`(있으면).

## 이력서와 무엇이 다른가

이력서는 고르는 문서고, 포트폴리오는 **보여 주는** 문서다. 이력서에서 잘라 낸 과정 · 코드 · 화면이 여기 온다.
그래도 읽는 사람은 바쁘다 — 카드 → 배경 → 사례 순으로, 위에서 멈춰도 핵심이 전달되게 쓴다.

## 필드 단위로 쓰는 이유

사용자의 포트폴리오 사이트는 콘텐츠를 데이터 파일(예: `src/data/projects.ts`)로 관리한다.
원고를 **사이트 데이터의 필드 이름과 같은 단위**로 나눠 두면, 사람이든 Claude든 필드마다 복사해 넣기만 하면 된다.
필드 대응표는 `references/site-fields.md`에 있다 — 사용자가 사이트에 옮겨 달라고 하면 그 파일을 읽는다.
노션 · PDF로 쓸 때도 같은 구조가 그대로 섹션이 된다.

## 출력 형식 — work/portfolio.md

````markdown
# <프로젝트명> — 포트폴리오 원고

## 카드
| 필드 | 값 |
|---|---|
| slug | <slug> |
| title | <프로젝트명> |
| summary | 한 줄 소개 (40자 안팎, 무엇을 하는 서비스인가) |
| year | YYYY |
| period | YYYY.MM — YYYY.MM |
| role | 예: 앱 개발 1인(설계 · 개발) |
| platform | mobile / web |
| tech | React Native, Expo, TypeScript, … |
| thumbnail | images/<slug>-thumb.webp |
| icon | images/<slug>-icon.webp |
| links | demo: … · repo: … |

## 배경 (context)
- 사용자는 누구고 어떤 상황에서 쓰나
- 그래서 어떤 기술 요구가 생겼나
(2~4 문단 또는 bullet. 각 항목은 한 문단)

## 접근 (approach)
- 구조 · 설계에서 내린 큰 결정 2~4개와 그 이유

## 사례 (cases)

### ① <label: 사례 제목>
- **problem**: …
- **approach**: …
- **result**: …
- **metrics**: `라벨: 값` (있을 때만, 최대 3개)
- **changes**:
  - file: `경로` · commit: `해시 · YYYY.MM.DD`
  - before:
    ```ts
    ...
    ```
  - after:
    ```ts
    ...
    ```
  - note: 두 코드가 같은 입력에서 어떻게 다르게 움직였나

(cases/ 순서 그대로 3~6개)

## 화면 (screens)
| # | src | srcAlt | name | note |
|---|---|---|---|---|
| 1 | images/<slug>-screen-01-light.webp | images/<slug>-screen-01-dark.webp | 홈 | 그 화면에서 보이는 기능 한 줄 |

## 보조 이미지 (sheets)
| src | title | note |

## 회고 (선택)
- 다시 한다면 무엇부터 고칠지 1~3개. 근거 있는 것만.
````

## 쓰는 법

- 다 쓴 뒤 `../../shared/writing-rules.md` 5-1의 표로 문장을 한 번 더 고친다. 번역투 · 명사 나열 · 커밋 메시지 말투가 남아 있지 않게.
- 쓰기 전 `check`, 쓴 뒤 `record` — `../../shared/work-layout.md`의 덮어쓰기 규칙. 사용자가 고친 원고면 `*.new.md`에 쓴다.
- 마지막에 `../../shared/scripts/check-work.sh work`를 돌려 오류(✗)를 고친다.

- problem · approach · result는 각각 2~4문장. cases/ 파일의 문제 · 해결 · 결과를 줄이되, 원인이 있던 층은 남긴다.
- changes의 코드는 cases/ 파일의 발췌를 그대로 옮긴다. 여기서 새로 줄이거나 다듬지 않는다.
- 화면 표의 note는 "화면 설명"이 아니라 "그 화면에서 보이는 기술적 포인트"(예: "회전 QR · 캡처 방지").
  `work/images/images.md`가 없으면 profile.md의 화면 목록으로 표를 만들고 src 칸에 `<!-- TODO: 캡처 -->`.
- 다 쓰고 나면 카드와 사례 제목 목록을 사용자에게 보여 준다. 사이트에 바로 옮기길 원하면 `references/site-fields.md`를 따른다.
