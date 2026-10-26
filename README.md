<p align="center">
  <img src="assets/banner.svg" alt="커밋이 이어진 필름 스트립에서 명장면 세 컷을 골라 cases/01~03으로 잘라 내고, 정찰 · 장면 고르기 · 촬영 · 편집 순서로 이력서와 포트폴리오를 만드는 흐름" width="100%">
</p>

이력서에 프로젝트를 쓰려고 하면 커밋 수백 개를 다시 뒤지게 됩니다. 무엇을 했는지는 기억나도, 어떤 문제를 어떻게 풀었는지, 그 전후 코드가 어땠는지는 흐려져 있습니다. reel은 그 일을 대신합니다. 프로젝트 저장소의 코드와 git 이력, 문서를 읽고, 이야기할 만한 장면만 골라 이력서 · 경력기술서 · 포트폴리오 원고로 편집합니다.

결과는 그 프로젝트 루트의 `work/` 폴더에 Markdown 원고와 화면 이미지로 남습니다. 모든 문장에는 근거가 붙고, 확인하지 못한 수치는 지어내지 않고 `TODO`로 비워 둡니다.

## 설치

```
/plugin marketplace add LimjeongSik/reel
/plugin install reel@reel
```

설치한 뒤 Claude Code를 재시작하거나 `/reload-plugins`를 실행하면 `/reel:cut`을 쓸 수 있습니다.

## 쓰는 법

분석할 프로젝트 폴더에서 실행합니다.

```
/reel:cut
```

인자 없이 실행하면 `all` 모드로 끝까지 진행합니다. 필요한 것만 뽑으려면 모드를 붙이고, 다른 폴더를 분석하려면 경로를 붙입니다.

| 명령 | 만드는 것 |
|---|---|
| `/reel:cut all` | 사례, 이미지, 이력서 원고, 포트폴리오 원고 전부 |
| `/reel:cut resume` | 사례와 이력서 원고 |
| `/reel:cut portfolio` | 사례, 이미지, 포트폴리오 원고 |
| `/reel:cut images` | 화면 이미지만 |
| `/reel:cut all ~/work/my-app` | 지정한 경로의 프로젝트를 분석 |
| `/reel:cut all --full` | 지난 분석 기록을 무시하고 처음부터 다시 분석 |

다시 실행하면 지난번에 분석한 커밋 이후의 변경만 읽고, 새 사례 후보만 추가합니다. 바뀐 커밋이 없으면 분석을 건너뜁니다. rebase로 이력이 바뀌었으면 알아서 처음부터 다시 분석합니다.

처음에 저장소를 훑고 나면, 코드만으로 알 수 없는 것(어느 커밋이 내 것인지, 직접 판단하고 검증한 부분 등)을 먼저 묻습니다. "나중에"라고 답하면 `TODO`로 남겨 두고 계속 진행합니다. 슬래시 명령 대신 "이 프로젝트로 이력서 원고 만들어줘"처럼 말해도 됩니다.

## 결과물

```
work/
├── profile.md      사실 정리. 스택 · 기간 · 내 기여 · 화면 목록 · 사례 후보 · 실측값
├── cases/
│   ├── 01-*.md     기술 사례 하나당 파일 하나
│   └── ...
├── resume.md       이력서 · 경력기술서 원고
├── portfolio.md    포트폴리오 원고
├── images/         화면 이미지와 설명 파일 images.md
├── README.md       만든 파일과 쓰임, 남은 TODO, 찍지 못한 화면
└── .reel/          쓴 파일의 해시, 분석한 커밋, 실행 전 백업
```

직접 고친 원고는 덮어쓰지 않습니다. reel이 쓴 뒤 바뀐 파일은 해시로 가려내서 새 원고를 `*.new.md`로 따로 쓰고, 실행할 때마다 원고를 `.reel/backup/`에 백업합니다. 다 쓰고 나면 원고에 인용한 커밋 해시와 날짜가 실제 이력과 맞는지, 참조한 이미지가 있는지 스크립트로 확인합니다.

| 파일 | 담는 내용 | 쓰는 곳 |
|---|---|---|
| `cases/NN-*.md` | 문제 → 해결 → 전/후 코드(커밋) → 결과 → 면접 포인트 | 모든 원고의 원재료 |
| `resume.md` | 요약 3줄, 경력 bullet, 경력기술서 상세, 길이별 자기소개, 예상 면접 질문 | 이력서 PDF, 지원서 입력 칸 |
| `portfolio.md` | 카드, 배경, 접근 방식, 사례(코드 포함), 화면 표를 사이트 필드 단위로 | 포트폴리오 사이트, 노션, PDF |
| `images/` | `<slug>-screen-NN.webp`(다크 모드는 `-dark`), `-icon`, `-thumb`, `-sheet-*` | 사이트 갤러리, 이력서 아이콘 |

<details>
<summary>사례 파일 하나는 이렇게 생겼습니다</summary>

사례는 "무엇을 만들었다"가 아니라 "무엇이 문제였고 어떻게 풀었는가"를 담습니다. 겉으로 보인 증상보다 원인이 한 겹 아래 있던 문제를 우선 고릅니다.

| 항목 | 내용 |
|---|---|
| 제목 | 사용자가 겪은 현상이 보이는 한 줄 |
| 확인 수준 | 실기기 확인 / 테스트로 고정 / 정적 검증만 / 미확인 |
| 문제 | 현상과 원인. 어느 층에서 왜 생겼는지까지 |
| 해결 | 바꾼 방식 |
| 전 → 후 | git 이력에서 그대로 발췌한 코드와 파일 경로, 커밋 해시, 날짜. 줄일 때는 `// ...`만 씀 |
| 결과 | 저장소에 기록된 실측값. 없으면 `<!-- TODO -->` |
| 한 줄 요약 | 이력서 칸에 바로 옮길 수 있는 문장 |
| 면접 포인트 | 받을 만한 질문. 저장소에 답의 근거가 없으면 지어내지 않고 직접 정리하도록 `TODO`로 남김 |

</details>

## 단계

`/reel:cut`은 아래 스킬을 순서대로 부릅니다. 스킬을 하나씩 직접 불러도 됩니다.

| 단계 | 스킬 | 입력 | 출력 | 하는 일 |
|---|---|---|---|---|
| 정찰 | [scout](skills/scout) | 저장소 | `profile.md` | 어떤 커밋이 내 것인지 정하고, 숫자는 실제 명령을 돌려서 셈 |
| 장면 고르기 | [clips](skills/clips) | profile | `cases/` | 기술 사례를 골라 전/후 코드를 git에서 그대로 잘라 냄 |
| 촬영 | [shots](skills/shots) | profile의 화면 목록 | `images/` | 있는 이미지를 먼저 쓰고, 웹은 Playwright로, 앱은 시뮬레이터나 adb로 찍음 |
| 편집 | [resume](skills/resume) | profile, cases | `resume.md` | 칸 길이에 맞춰 미리 잘라 둔 원고. 경력에는 역할과 영향, 프로젝트에는 기술 문제 |
| 편집 | [portfolio](skills/portfolio) | profile, cases, images | `portfolio.md` | 포트폴리오 사이트의 `Project` 타입과 같은 필드 단위로 씀 |
| 검수 | [check-work.sh](shared/scripts/check-work.sh) | work/ | 점검 결과 | 인용한 커밋 해시 · 날짜, 이미지 경로, 사례 번호를 실제와 대조. 틀린 곳은 고친 뒤 다시 점검 |

모드에 따라 지나가는 단계가 다릅니다.

```
all        scout → clips → shots → resume → portfolio → 검수
resume     scout → clips → resume → 검수
portfolio  scout → clips → shots → portfolio → 검수
images     scout → shots → 검수
```

모든 단계는 시작할 때 [work-guard.sh](shared/scripts/work-guard.sh)로 원고를 백업하고, 파일을 쓸 때마다 사람이 고친 원고인지 확인합니다.

저장소가 크면 scout가 하위 영역 조사를 [scout-analyst](agents/scout-analyst.md) 에이전트에 나눠 맡기기도 합니다. 이 에이전트는 읽기만 하고 아무것도 고치지 않습니다.

## 편집 원칙

이력서는 고르는 문서이고, 포트폴리오는 보여 주는 문서입니다. 두 원고 모두 아래 원칙을 지킵니다. 자세한 내용은 [shared/writing-rules.md](shared/writing-rules.md)에 있습니다.

- **수치는 실측값만 씁니다.** 저장소에 기록된 숫자만 쓰고, 모르는 값은 `<!-- TODO -->`로 남깁니다.
- **코드는 고치지 않고 발췌합니다.** git 이력에 있는 그대로 옮기고, 줄일 때는 `// ...`만 씁니다.
- **인용한 근거는 기계로 대조합니다.** 원고에 적은 커밋 해시와 날짜가 실제 이력에 없으면 오류로 보고 고칩니다.
- **어디까지 확인했는지 밝힙니다.** 실기기에서 확인했는지, 테스트로 고정했는지, 정적 검증만 했는지 구분합니다.
- **조건이 있으면 조건을 붙입니다.** OS나 기기에 따라 달라지는 내용은 그 조건을 함께 적습니다.
- **같은 이야기를 두 번 하지 않습니다.** 경력 bullet과 프로젝트 사례가 같은 내용을 반복하지 않도록 나눕니다.

## 필요한 것

- Claude Code
- 분석할 프로젝트. git 저장소여야 전/후 코드와 커밋 근거를 뽑을 수 있습니다. git이 아니어도 동작하지만 결과가 얕아집니다.
- 웹 화면 캡처: Node.js(`npx`). Playwright 1.64.1을 쓰고, 브라우저가 없으면 `npx playwright@1.64.1 install chromium-headless-shell`로 받습니다.
- 이미지 변환: `cwebp` (`brew install webp`, Linux는 `apt install webp`)
- 앱 화면 캡처: Xcode 시뮬레이터(`xcrun simctl`) 또는 Android `adb`. 앱 프로젝트일 때만 필요합니다.

## 개발

```
.claude-plugin/          plugin.json · marketplace.json
commands/cut.md          /reel:cut
agents/scout-analyst.md  큰 저장소 하위 영역 조사용 (읽기 전용)
shared/                  writing-rules.md · work-layout.md
└── scripts/             work-guard.sh(덮어쓰기 보호 · 분석 커밋 기록) · check-work.sh(원고 점검)
tests/run.sh             스크립트 회귀 테스트
skills/
├── scout/
├── clips/
├── resume/
├── portfolio/           references/site-fields.md (사이트 필드 대응표)
└── shots/               scripts/capture-web.sh · capture-device.sh · to-webp.sh
```

스크립트를 고쳤으면 `tests/run.sh`를 돌립니다. 저장소를 받아 고친 뒤에는 `--plugin-dir`로 실제 프로젝트에서 써 봅니다. 설치한 reel과 함께 쓰면 같은 플러그인이 두 번 잡히니, 먼저 `/plugin`에서 설치한 쪽을 꺼 두세요.

```bash
git clone https://github.com/LimjeongSik/reel.git
cd <분석할 프로젝트>
claude --plugin-dir <reel을 받은 경로>
```

## 앞으로

- [ ] 영문 이력서 원고
- [ ] 여러 프로젝트의 결과를 모아 이력서 한 부를 통째로 만드는 스킬
- [ ] 종류가 다른 샘플 저장소(웹 · 앱 · 모노레포)로 끝까지 돌리는 E2E 테스트
- [ ] 전 → 후 코드 발췌가 해당 커밋의 실제 코드와 같은지 대조
- [ ] 로그인이 필요한 화면까지 자동으로 찍는 라우트 탐색

## 라이선스

MIT
