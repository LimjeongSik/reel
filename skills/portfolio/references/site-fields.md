# portfolio.md → 포트폴리오 사이트 데이터 대응표

사용자의 포트폴리오 사이트(예: `~/Desktop/Portfolio`)는 React + Vite이고, 콘텐츠를 `src/data/projects.ts`의
`Project` 객체로 관리한다(타입은 `src/types/content.ts`). 사이트에 옮기기 전에 **반드시 그 저장소의 타입 파일을 다시 읽는다** —
필드는 바뀔 수 있고, 이 표는 2026.10 기준이다.

| portfolio.md | Project 필드 | 메모 |
|---|---|---|
| 카드.slug | `slug` | URL과 이미지 파일명 접두사 |
| 카드.title / summary / year / period / role | 같은 이름 | |
| 카드.platform | `platform: "mobile" \| "web"` | |
| 카드.tech | `tech: string[]` | |
| 카드.thumbnail / icon | `thumbnail` / `icon` | 이미지는 `src/assets/`로 복사 후 `import x from "@/assets/..."` |
| 카드.links | `links: { demo?, repo? }` | |
| 배경 | `context: string[]` | bullet 하나 = 배열 원소 하나 |
| 접근 | `approach: string[]` | |
| 사례 ①… | `cases: ProjectCase[]` | `{ label, problem, approach, result, metrics?, changes? }` |
| 사례.metrics | `metrics: { label, value }[]` | |
| 사례.changes | `changes: { file, commit?, before?, after, note }[]` | `commit` 형식 "짧은 해시 · YYYY.MM.DD". before가 없으면 생략 |
| 화면 | `screens: { src, srcAlt?, name, note, path? }[]` | 웹이면 `path`에 경로. 모든 화면이 srcAlt를 가지면 `screenModes: { labels, note }` 추가 |
| 보조 이미지 | `sheets: { src, title, note }[]` | |

## 옮기는 순서

1. `work/images/*.webp`를 사이트의 `src/assets/`로 복사(파일명 그대로 — 이미 `<slug>-screen-NN` 규칙)
2. `projects.ts` 상단에 import 추가, 기존 프로젝트와 같은 순서 규칙으로 객체 추가
3. 사이트 저장소의 `CLAUDE.md` 규약을 따른다(Biome 4칸 들여쓰기 · 큰따옴표, 끝나면 `bun run check:fix`,
   콘텐츠를 고쳤으면 `bun run knowledge`로 AI 안내자 지식 재생성)
4. `theme`(브랜드 색)과 프로젝트별 시그니처 그림(`anatomy` · `pipeline` 등)은 원고에 없다 — 사용자에게 묻는다

## 이력서(resume/content.js)로 옮길 때

`resume/content.js`의 프로젝트 항목에는 `work/resume.md` 1장(짧은 버전)을 쓴다. 기간은 `"YYYY.MM — YYYY.MM"` 꼴,
모르는 값은 `"TODO ..."` 문자열(화면에만 보이고 PDF에서는 숨겨진다).
