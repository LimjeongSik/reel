# work/ 폴더 구조 (모든 스킬 공통)

결과물은 **분석 대상 프로젝트의 루트**에 `work/`를 만들어 담는다. 원본 코드는 건드리지 않는다.

```
work/
├── .gitignore           # 내용은 `*` 한 줄 — work/ 전체를 git에서 뺀다 (work/를 만들 때 항상)
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
- 이미 `work/`가 있으면 덮어쓰기 전에 무엇이 있는지 확인한다. 사용자가 손으로 고친 내용이 있을 수 있다.
  고친 흔적이 보이면 새 파일을 `*.new.md`로 쓰고 차이를 알려 준다.
- `work/`는 지원 서류 원고라 커밋하지 않는다. work/를 처음 만들 때 그 안에 `.gitignore`를 만들고 아래 두 줄을 쓴다.
  대상 저장소의 `.gitignore`는 건드리지 않으므로 묻지 않아도 된다.
  ```
  # 지원 서류 원고 — 커밋하지 않습니다
  *
  ```
  만든 뒤 `git check-ignore -q work/profile.md`로 실제로 빠졌는지 확인한다(저장소 밖이면 건너뛴다).
