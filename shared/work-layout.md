# work/ 폴더 구조 (모든 스킬 공통)

결과물은 **분석 대상 프로젝트의 루트**에 `work/`를 만들어 담는다. 원본 코드는 건드리지 않는다.

```
work/
├── .gitignore           # 내용은 `*` 한 줄 — work/ 전체를 git에서 뺀다 (work/를 만들 때 항상)
├── .reel/               # reel 상태: manifest(쓴 파일 해시) · head(분석한 커밋) · backup/(실행 전 md 백업, 최근 5개)
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
$G check  work resume.md       # 0이면 그 경로에 쓴다. 1이면 출력된 경로(resume.new.md)에 쓴다
$G record work resume.md       # 쓴 직후 반드시. 기록이 없으면 다음 실행에서 "사람이 고친 파일"로 취급된다
```

- 상태: `new`(없음) · `clean`(reel이 쓴 그대로) → 덮어쓴다. `edited`(reel이 쓴 뒤 고쳐짐) · `unknown`(reel 기록 없음) → `*.new.md`로 쓴다.
- `*.new.md`를 썼으면 사용자에게 원래 파일과 무엇이 다른지 짧게 알리고, 합칠지 바꿀지 묻는다.
  사용자가 바꾸라고 하면 원래 경로에 쓰고 `record`한다. `*.new.md`는 `record`하지 않는다.
- 이미지(webp)는 다시 찍으면 되므로 이 규칙 밖이다. `images/images.md`는 원고라 규칙을 따른다.
- 되돌려야 하면 `work/.reel/backup/<시각>/`에 실행 직전 md가 있다.

## 마무리 점검

원고를 다 쓰면 `shared/scripts/check-work.sh work`를 돌린다. 인용한 커밋 해시 · 날짜가 실제 이력과 맞는지,
참조한 이미지가 있는지, 사례 번호가 이어지는지, 템플릿 자리표시자 · 피할 표현 · TODO 개수를 본다.
오류(✗)는 고친 뒤 다시 돌린다 — 없는 커밋이나 틀린 날짜는 원고가 근거를 지어냈다는 신호다. 경고(△)는 읽고 판단한다.
