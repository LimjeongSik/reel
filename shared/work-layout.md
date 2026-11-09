# work/ 폴더 구조 (모든 스킬 공통)

결과물은 **분석 대상 프로젝트의 루트**에 `work/`를 만들어 담는다. 원본 코드는 건드리지 않는다.

```
work/
├── .gitignore           # 내용은 `*` 한 줄 — work/ 전체를 git에서 뺀다 (work/를 만들 때 항상)
├── .reel/               # reel 상태: manifest(쓴 파일 해시) · marks(단계별 반영한 커밋) · run(이번 실행에서 쓴 파일) · backup/(실행 전 md 백업, 최근 5개)
├── README.md            # 목차 · 각 파일의 쓰임 · 채워야 할 TODO 모음  (/reel:cut 커맨드가 마지막에 갱신)
├── profile.md           # 프로젝트 사실 정리와 근거          (scout)
├── cases/
│   ├── 01-<slug>.md     # 기술 사례 하나 = 파일 하나        (clips)
│   └── ...
├── resume.md            # 이력서 · 경력기술서용 원고         (resume)
├── portfolio.md         # 포트폴리오 사이트 · 문서용 원고     (portfolio)
└── images/
    ├── images.md        # 이미지 목록: 파일 · 화면 이름 · 한 줄 설명 (shots)
    ├── raw/             # 원본 PNG (변환 전)
    ├── <slug>-icon.webp
    ├── <slug>-thumb.webp
    ├── <slug>-screen-01.webp          # 화면 순서대로 번호
    ├── <slug>-screen-01-dark.webp     # 테마가 두 벌이면 -light / -dark
    └── <slug>-sheet-<topic>.webp      # 팔레트 · 아이콘 · 구조도 같은 보조 이미지
```

- `<slug>`는 프로젝트를 가리키는 짧은 영문 소문자 이름(예: `safeops`, `sms`, `imug`). `profile.md` 맨 위에 정해 두고 모든 스킬이 같은 값을 쓴다.
- `work/`는 지원 서류 원고라 커밋하지 않는다. 아래 `begin`이 `work/.gitignore`(`*`)를 만들고 git에서 빠졌는지 확인한다.
  대상 저장소의 `.gitignore`는 건드리지 않으므로 묻지 않아도 된다.

## 덮어쓰기 규칙 — 판단하지 말고 스크립트로

사용자가 손으로 고친 원고를 덮어쓰면 되돌릴 수 없다. "고친 흔적이 보이는지"를 눈으로 판단하지 않고
`shared/scripts/work-guard.sh`(스킬 폴더 기준 `../../shared/scripts/work-guard.sh`)로 정한다.

```bash
G=<플러그인 폴더>/shared/scripts/work-guard.sh
$G begin  work                 # 스킬을 따로 부를 때도 첫 쓰기 전에 한 번. md를 .reel/backup/에 백업하고 파일별 상태를 보여 준다
$G check  work resume.md       # 0이면 그 경로에 쓴다. 1이면 출력된 경로(resume.new.md, 이미 있으면 resume.new-02.md …)에 쓴다
$G record work resume.md       # 쓴 직후 반드시(대체 원고도). 기록이 없으면 다음 실행에서 "사람이 고친 파일"로 취급된다
$G run    work                 # 이번 실행에서 쓴 파일: <단계> <canon|alt|changed> <파일>
$G adopt  work profile.new.md profile.md   # 대체 원고 채택: 옮기고 record, 실행 목록의 대체 행은 지움, 덮인 원고는 backup
```

- 상태: `new`(없음) · `clean`(reel이 마지막으로 쓴 뒤 바뀌지 않음) → 덮어쓴다. `edited`(reel이 쓴 뒤 고쳐짐) · `unknown`(reel 기록 없음) → `*.new.md`로 쓴다.
- `clean`은 지난 실행에서 쓴 파일도 포함한다. **이번 실행에서 썼는지는 `run`으로 본다** — `begin`이 목록을 비우고 `record`가 올린다.
  `canon`은 정식 원고, `alt`는 대체 원고, `changed`는 이번 실행에서 쓴 뒤 누군가 고친 파일이다.
- 대체 원고도 사람이 고쳤을 수 있다. 그래서 `check`는 이미 있는 `*.new.md`를 덮지 않고 `*.new-02.md`, `-03` … 비어 있는 경로를 준다.
  `begin`은 대체 원고도 백업하고 상태를 `alt`로 보여 준다.
- `*.new.md`를 썼으면 사용자에게 원래 파일과 무엇이 다른지 짧게 알리고, 합칠지 바꿀지 묻는다.
  사용자가 바꾸라고 하면 `adopt`로 옮긴다(손으로 옮기고 `record`하면 실행 목록에 대체 행이 남아 완료 기록을 막는다). 대체 원고의 `record`는 이번 실행 목록에만 올리고 manifest에는 올리지 않는다
  (올리면 다음 실행이 `clean`으로 보고 덮어쓴다).
- 이미지(webp)는 다시 찍으면 되므로 이 규칙 밖이다. `images/images.md`는 원고라 규칙을 따른다.
- 되돌려야 하면 `work/.reel/backup/<시각>/`에 실행 직전 md가 있다.

## 단계별 기준 커밋 — 실행을 시작할 때 고정한다

다시 실행할 때 어느 커밋부터 읽을지는 **단계마다 따로** 정한다. 단계 이름은 `profile`(scout) · `cases`(clips) ·
`images`(shots) · `resume` · `portfolio`. resume 모드로 돌린 뒤 나중에 portfolio를 돌리면 portfolio는 자기 기준부터 다시 읽는다.

```bash
TO=$(git -C <대상> rev-parse --short HEAD)    # 실행 시작 때 한 번. 실행 중에 커밋이 생겨도 범위는 그대로
FROM=$($G mark work <단계>)                   # 그 단계가 지난번에 반영한 커밋. 없으면(종료 코드 1) 전체
$G mark work <단계> "$TO"                      # 검수까지 끝난 뒤에만(아래 "완료 기록")
```

- 그 단계의 git 명령은 모두 `FROM..TO`(전체면 `TO`)로 쓴다. `HEAD`를 다시 읽지 않는다.
- FROM이 TO의 조상이 아니면(`git merge-base --is-ancestor FROM TO` 실패 — rebase · 브랜치 이동) 전체로 본다.
- `/reel:cut`은 시작할 때 TO와 단계별 FROM을 정해 각 단계에 넘긴다. 스킬을 따로 부를 때는 그 스킬이 같은 방식으로 정한다.
- 0.4.0이 남긴 `.reel/head`는 `profile`의 기준으로 읽는다. 다른 단계는 기록이 없으므로 첫 실행에서 전체로 본다.

### 입력 — 대체 원고가 생기면 뒤 단계를 멈춘다

| 단계 | 읽는 원고 |
|---|---|
| cases | profile |
| images | profile |
| resume | profile, cases |
| portfolio | profile, cases, images(있으면) |

한 단계가 끝나면 `run`에서 그 단계의 줄을 본다. `alt`가 있으면(새 분석이 대체 원고에만 있으면) 그 원고를 읽는 뒤 단계로 넘어가기 전에 사용자에게 묻는다.
그대로 진행하면 뒤 단계가 옛 정식 원고를 읽어 새 분석과 섞인다.
1. **채택** — `adopt work <대체> <정식>`. 대체 원고를 정식 경로로 옮기고 기록하며, 실행 목록에서 대체 행을 지워 그 단계가 `canon`만 남는다.
   덮인 정식 원고(사람이 고친 판)는 `.reel/backup/<시각>-adopt/`에 남는다. 이후는 평소대로
2. **이번만 대체 원고로** — 뒤 단계에 입력 경로를 명시해 넘긴다(예: "profile은 `profile.new.md`를 읽는다"). 이 입력으로 만든 단계는 완료 기록을 남기지 않는다
3. **기존 원고 유지** — 새 분석을 버리고 정식 원고로 진행한다. 대체 원고를 만든 단계는 완료 기록을 남기지 않는다
답을 받을 수 없으면(사용자가 "묻지 말고 끝까지") 그 원고를 읽는 뒤 단계는 **보류**하고, 보류한 단계와 이유를 보고에 적는다.

### 완료 기록 — 검수를 통과한 뒤에

`mark`는 쓴 직후가 아니라 **마무리 점검 뒤에** 남긴다. 단계마다 아래를 모두 만족할 때만 `mark work <단계> <TO>`:
- `run`에서 그 단계의 줄이 모두 `canon`이다(`alt` · `changed`가 없다). 쓴 파일이 없는 단계(건너뛴 단계)는 기존 기록을 그대로 둔다
- `check-work.sh` 결과에 그 단계 파일(위 `run`의 단계 열과 같은 대응: `profile.md` · `cases/` · `images/images.md` · `resume.md` · `portfolio.md`)의 오류(✗)가 없다
- 읽은 입력이 모두 정식 원고였다(위 2번으로 대체 원고를 읽지 않았다)

하나라도 아니면 남기지 않는다 — 다음 실행이 같은 범위를 다시 본다. 사용자가 나중에 대체 원고를 채택하면 그때 `adopt`, 검수, `mark` 순서로 한다.

## 마무리 점검

원고를 다 쓰면 `shared/scripts/check-work.sh work`를 돌린다. 인용한 커밋 해시 · 날짜가 실제 이력과 맞는지,
참조한 이미지가 있는지, 사례 번호가 이어지는지, 템플릿 자리표시자 · 피할 표현 · TODO 개수를 본다.
오류(✗)는 고친 뒤 다시 돌린다 — 없는 커밋이나 틀린 날짜는 원고가 근거를 지어냈다는 신호다. 경고(△)는 읽고 판단한다.

고칠 때(질문 답을 반영할 때도) 기준은 `run`이다.
- `run`에 `canon` · `alt`로 나온 파일(이번 실행에서 쓰고 아무도 고치지 않음)은 고치고 다시 `record`한다.
- 그 밖의 파일 — 지난 실행 파일(`clean`이어도), 사람이 고친 원고, 지난 실행의 대체 원고, `changed` — 는 **손대지 않는다.**
  오류를 보고하고, 사용자가 원하면 고친 판을 `check`가 준 대체 경로에 쓴다.
