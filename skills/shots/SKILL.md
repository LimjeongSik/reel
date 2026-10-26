---
name: shots
description: 프로젝트의 실제 화면 스크린샷과 포트폴리오에 쓸 이미지(앱 아이콘, 로고, 썸네일, 디자인 시트)를 모아 work/images/에 webp로 정리하고, 화면 이름 · 설명 목록 images.md를 만든다. 웹은 dev 서버나 배포 URL을 Playwright로 찍고(라이트/다크, 데스크톱/모바일), 앱은 iOS 시뮬레이터 · Android 기기 화면을 찍거나 저장소에 이미 있는 이미지를 모은다. "스크린샷 찍어줘", "포트폴리오용 이미지 뽑아줘", "화면 캡처", "썸네일 만들어줘" 요청이나 /reel:cut 실행 시 사용한다.
---

# 화면 · 이미지 수집 → work/images/

먼저 이 스킬 폴더 기준 `../../shared/work-layout.md`를 읽는다(파일 이름 규칙).
입력은 `work/profile.md`의 slug와 "화면 목록"이다. 없으면 scout를 먼저 실행한다.

포트폴리오에서 사람들이 가장 먼저 보는 것은 화면이다. 그래서 "있는 화면 아무거나"가 아니라
**사례를 보여 주는 화면**을 우선한다 — 사례에 나온 기능(예: 긴급 알림, 오류 목록, 다크 테마)이 보이는 화면이 먼저다.

## 1. 저장소에 이미 있는 이미지부터

찍기 전에 이미 있는 것을 모은다. 다시 찍는 것보다 정확하고, 앱은 직접 찍기 어려운 경우가 많다.

- 앱 아이콘: `assets/icon*`, `app.json`의 `icon`, `ios/**/AppIcon.appiconset`, `android/**/mipmap-xxxhdpi/ic_launcher*`
- 로고 · 스플래시 · 브랜드 이미지, `docs/` · `screenshots/` · `README`에 걸린 이미지, 스토어 등록용 이미지
- 디자인 토큰(색 팔레트) · 아키텍처 그림이 있으면 sheet 후보

찾은 원본은 `work/images/raw/`에 복사(원본은 옮기지 않는다)하고 규칙에 맞는 이름을 붙인다.

**있는 이미지가 지금 화면인지 확인한다.** `git log -1 --format=%ad -- <이미지>`(추가된 날)와 그 뒤의 UI 커밋
(`git log --since=<그 날> --oneline -- src/app src/components` 등)을 비교한다. 그 뒤로 화면이 크게 바뀌었으면
(데이터 출처 교체, 새 화면 추가) images.md 머리에 "몇 월 며칠 화면 — 지금과 다름"을 적고 다시 찍기를 권한다.
이미지를 직접 열어 화면 속 표시도 본다(예: "절차적 모델 15만 점"처럼 가짜 데이터임을 알리는 글자).

## 2. 웹 화면 찍기

1. 배포 URL이 있으면 그것을, 없으면 dev 서버를 띄운다(`package.json`의 `dev` 스크립트, 백그라운드 실행).
   로그인이 필요한 화면이 있으면 사용자에게 테스트 계정이나 로그인 상태 저장을 부탁한다 — 계정을 지어내거나 실제 고객 데이터가 보이는 화면을 그대로 쓰지 않는다.
2. 화면 목록 순서대로 `scripts/capture-web.sh`로 찍는다.
   ```bash
   S=<이 스킬 폴더>/scripts
   $S/capture-web.sh http://localhost:5173/ work/images/raw/<slug>-screen-01.png
   $S/capture-web.sh http://localhost:5173/ work/images/raw/<slug>-screen-01-dark.png --color-scheme dark
   $S/capture-web.sh http://localhost:5173/ work/images/raw/<slug>-screen-01-mobile.png --viewport-size 390,844
   ```
   다크 테마를 지원하면 모든 화면을 `-light`/`-dark` 두 벌로. 반응형이면 대표 화면 2~3개는 모바일 크기도.
3. 긴 랜딩 페이지는 `--full-page` 한 장을 `<slug>-home-full.png`로 따로 남긴다.

## 3. 앱 화면 찍기

시뮬레이터 · 기기를 띄우고 앱을 실행하는 일은 시간이 오래 걸리고 환경마다 다르다. 이미 실행 중인지 먼저 확인하고
(`xcrun simctl list devices booted`, `adb devices`), 없으면 사용자에게 띄워 달라고 하거나 1장에서 모은 이미지로 대신한다.

```bash
$S/capture-device.sh ios work/images/raw/<slug>-screen-01.png
$S/capture-device.sh android work/images/raw/<slug>-screen-01.png
```

화면 이동은 딥링크(스크립트 상단 주석 참고)로 하거나 사용자에게 부탁한다. 한 장 찍을 때마다 어떤 화면인지 확인한다.

## 4. 변환과 정리

```bash
$S/to-webp.sh work/images/raw work/images 1080      # 모바일 화면
$S/to-webp.sh work/images/raw/<slug>-icon.png work/images 192
```

데스크톱 캡처는 폭 1600, 썸네일은 960. 찍은 이미지는 직접 열어 보고(Read 도구로 이미지 확인) 다음을 걸러 낸다:
로딩 스피너 · 빈 화면 · 에러 오버레이 · 개발용 배너(Next.js 개발 표시 "N" 아이콘, Vite 오류 오버레이 등 — dev 서버로 찍었다는 표시),
**실명 · 전화번호 · 이메일 같은 개인정보**(있으면 사용자에게 알리고 그 이미지는 쓰지 않는다).
dev 서버로 찍을 수밖에 없으면 프로덕션 빌드(`build` → `start`)로 찍거나, 개발 표시를 끄는 설정(Next.js `devIndicators: false`)을
임시로 넣는다 — 원본 수정이므로 사용자에게 먼저 묻는다.

썸네일(`<slug>-thumb.webp`)은 가장 대표적인 화면 하나를 골라 정한다. 따로 합성하지 않는다.

## 5. 출력: work/images/images.md

```markdown
# <프로젝트명> — 이미지 목록

| 파일 | 다른 한 벌 | 화면 이름 | 한 줄 설명 | 관련 사례 |
|---|---|---|---|---|
| <slug>-screen-01-light.webp | <slug>-screen-01-dark.webp | 홈 | 근무 상태 · 관제실 수신 시각 · 지도 | ③ |

## 보조 이미지
| 파일 | 제목 | 설명 |

## 찍지 못한 화면
- 화면 이름 — 이유(로그인 필요 / 기기 없음 / …)
```

images.md도 덮어쓰기 규칙(`check` → 쓰기 → `record`)을 따른다.

"한 줄 설명"은 화면이 무엇인지가 아니라 **그 화면에서 보이는 기술적 포인트**를 쓴다(예: "회전 QR · 캡처 방지").
portfolio가 이 표를 화면 갤러리로 그대로 쓴다.

마지막으로 dev 서버를 띄웠다면 종료한다.
