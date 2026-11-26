# Changelog

## [Unreleased] — Capture Studio, Seasons

### Added
- **Capture Studio** (Developer → Capture Studio…): 홍보 영상 촬영 전용 창. Ambient Mode와 별개이고, Demo 상태만 씁니다(저장 안 됨).
  - 테두리·UI 없음, 창 위에서 포인터 숨김, 모든 조작은 단축키.
  - 정수 배율 2×/3×/4×(화면에 맞게 자동 선택)와 클로즈업 1–4×. 화면비 9:16·1:1·16:9.
  - 기기 픽셀에 스냅하는 따라가기 카메라.
  - 배경: 시간대를 따라가는 하늘, 키 컬러 #FF00FF, 스튜디오.
  - 프리셋 5종(마을, 주민, 밤, 장식, 다 자란 마을). 레벨·시간·주민 행동·이벤트·장식 세트·활동 시설을 키 하나로 전환.
  - 촬영 가이드: [docs/CAPTURE.md](docs/CAPTURE.md).
- 밤 조명: 문 앞·가로등·랜턴 아래 땅 조명, 달무리, 반딧불이.
- `CaptureLayout`·`CapturePreset` 테스트 10개 (총 80개).
- **계절** (설계: [docs/DESIGN-SEASONS-JOURNAL.md](docs/DESIGN-SEASONS-JOURNAL.md) 4a): 실제 달력의 기상학적 계절을 따릅니다.
  - 봄: 분홍 꽃 핀 나무, 새싹색 풀. 가을: 단풍, 마른 풀. 겨울: 눈 덮인 땅, 지붕·굴뚝·나무·우물·울타리 위 2px 눈, 상록수 색.
  - 팔레트 교체와 생성된 눈 덮개(`PixelArt.snowCapped`)라 같은 ASCII 아트에서 나옵니다. 텍스처는 계절별로 캐시하고, 계절이 바뀔 때 텍스처만 바꿉니다.
  - PNG 오버라이드: `<이름>@<계절>.png`. 여름은 기존 이름 그대로입니다.
  - 반구는 시간대로 추정하고, Settings → Seasons(Follow the calendar / Northern / Southern / Off)로 바꿀 수 있습니다. `settings.json`에 `seasons` 필드가 추가되고, 없으면 자동입니다(스키마 버전 유지).
  - 계절이 Town Status, Town Mode 패널, 설정에 표시됩니다.
  - Demo: Season 메뉴. Capture Studio: **E** 키 계절 순환, 프리셋 6 "Winter night".
  - 계절 프리뷰: `scripts/render-art-preview.py … docs/season-preview.png`.
  - 계절 테스트 8개 (총 88개): 월 경계, 남반구, 현지 자정 기준 경계, 시간대 추정, 설정, 스냅샷, 관대한 디코딩, 프리셋.
- **로그인 시 열기** (Settings → Startup, 메뉴 "Open at Login"): `SMAppService.mainApp`을 씁니다.
  - 상태는 시스템이 관리하므로 `settings.json`에 저장하지 않고, 매번 시스템에서 읽습니다. 시스템 설정에서 바꿔도 앱으로 돌아오면 반영됩니다.
  - macOS 승인이 필요하면 안내 후 시스템 설정 → 로그인 항목을 엽니다.
  - `.app` 번들로 실행할 때만 켤 수 있습니다(`swift run`에서는 비활성).
- **동작 줄이기 존중**: 시스템 설정 → 손쉬운 사용 → 디스플레이 → 동작 줄이기를 따릅니다. 실행 중 변경도 바로 반영됩니다.
  - 켜져 있으면 끝없이 반복되는 장식 움직임을 멈춥니다: 구름, 나무 흔들림, 굴뚝 연기, 축제 깃발, 별 반짝임, 반딧불이, 선택 화살표.
  - 새 시설은 아래에서 올라오지 않고 제자리에서 나타납니다.
  - 주민·방문자의 움직임과 낮밤 페이드는 그대로입니다(마을의 생활 자체). 완전히 멈추려면 Pause Animation을 씁니다.
  - Capture Studio는 움직임을 녹화하는 도구라 이 설정을 따르지 않습니다.
- **CI** (`.github/workflows/ci.yml`): 푸시·PR마다 macOS에서 앱 타깃까지 빌드하고 `swift test`, `.app` 번들링, 스모크 실행을 합니다. Linux(`swift:6.0`)에서는 코어 테스트를 돌립니다.
  - Swift 컴파일러 경고를 PR에 주석으로 달고 요약에 개수를 적습니다(빌드는 실패시키지 않음).
  - 빌드한 `.app`(zip), 스모크 로그, 리소스 샘플을 아티팩트로 14일 보관합니다.
- `scripts/smoke-run.sh`: 번들 앱을 실행해 계속 살아 있는지 확인하고, CPU·메모리를 샘플링한 뒤 SIGTERM으로 끄고 `town.json`이 저장됐는지 확인합니다.
- `scripts/measure-resources.sh`: 실행 중인 앱의 CPU(누적 CPU 시간 기준 실제 평균)와 메모리(RSS, macOS에서는 Activity Monitor와 같은 physical footprint)를 CSV로 기록합니다. `--max-cpu`/`--max-mem`으로 목표 미달을 판정합니다.

### Fixed
- SIGTERM(`kill`, launchd, 스크립트)으로 종료하면 `applicationWillTerminate`를 건너뛰어 마지막 저장이 빠지던 문제. 이제 SIGTERM은 일반 종료(`NSApp.terminate`)로 처리합니다.
- `TownScene.buildDecorSlots`의 사용하지 않는 변수 경고.

### Changed
- 주민에게 1px 외곽선과 눈을 추가했습니다. Pip 셔츠는 세이지 → 청록, Juno 셔츠는 모래 → 자두색으로 바꿨습니다(잔디·길과 구분되지 않던 문제).
- 땅: 길 가장자리 자국과 잔디 하이라이트.

### Verified (2026-11-26, CI run 45816224203, macOS 15 · Xcode 16.4 · Swift 6.1.2)
- Capture Studio를 포함한 앱 타깃이 Mac에서 수정 없이 빌드됩니다. Swift 컴파일러 경고 0개.
- `swift test` 80개 통과 (macOS, Linux `swift:6.0` 모두).
- 스모크 실행(일반·`--dev` 각 60초): 실행 유지, SIGTERM으로 정상 종료, `town.json` 저장 확인.
  - GitHub VM 수치(참고용): 평균 CPU 약 2.0%, physical footprint 13 MB, 60초 동안 증가 +0.2 MB 이하.

### Not verified
- Capture Studio 화면과 단축키 동작, 실기기 성능 수치(위 수치는 GPU가 없는 VM 기준).

## [0.2.0-alpha] — 2026-10-21 — Ambient Living World

### Added
- **Town Mode**: 6× 마을을 보여주는 별도 창.
  - 패널: 레벨과 진행률, 선택 정보(주민의 현재 행동, 시설 내력, 장식 자리), 장식 배치, 장식 기능 표시 여부, Back to Ambient(Esc).
  - 여는 방법: 메뉴 또는 Ambient 마을 더블클릭.
  - 열려 있는 동안 Ambient 마을은 숨고 렌더링을 멈춥니다. 닫으면 장면과 렌더러를 해제합니다.
- **장식 슬롯 4개**와 장식 8종(벤치, 화분, 표지판, 묘목, 랜턴, 새 물통, 호박밭, 버섯).
  - 장식마다 레벨 잠금이 있습니다.
  - 벤치는 주민이 앉는 자리가 되고, 랜턴은 밤에 빛납니다.
  - 어린 나무, 울타리, 들꽃, 가로등, 축제 깃발은 숨길 수 있습니다.
- **주민 행동 시스템** (`TownLife`, `ResidentBehaviorRules`).
  - 행동 9종: 산책, 둘러보기, 앉기, 일하기, 대화, 귀가, 독서, 꽃 구경, 축하.
  - 가중치 기반 결정에 시간대별 규칙, 최소 지속 시간, 연속 반복 방지가 들어 있습니다.
  - 행동이 끝날 때만 결정합니다.
- **활동 → 주민 생활 연결**: 공방에서 일하기, 꽃밭 구경, 도서관 독서, 축제 축하. 공방이 없으면 집 앞에서 일합니다.
- **세 번째 주민**(Juno, Level 3, 파란 집). 주민마다 다른 색입니다.
- **작은 이벤트 3종** (`EventScheduler`): 길고양이, 여행자(주민이 인사), 이웃 모임(축제 깃발이 있으면 축하).
  - 한 번에 하나만 일어나고, 끝난 뒤 최소 25분은 쉽니다.
  - 밤이나 마을이 보이지 않을 때는 시작하지 않습니다.
- **아트**:
  - 오두막에 굴뚝, 기와 무늬, 창가 화분, 문고리.
  - 파란 집에 다락 창과 덧창.
  - 창가 불빛 후광, 주민 프레임 11종, 고양이, 여행자, 작은 "…" 말풍선.
- **Demo Mode**:
  - 이벤트 3종과 주민 행동 8종을 즉시 실행할 수 있습니다.
  - Town Mode에서도 동작하고, Demo 중의 장식 변경은 저장하지 않습니다.
  - 화면에 `DEMO` 표시, 개발자 모드 시간 가속 중에는 `DEV ×60` 표시가 붙습니다.
- 테스트 34개 추가 (총 70개): 주민 행동, 이벤트, 장식, v0.1 데이터 마이그레이션, 두 모드의 스냅샷 일치.

### Changed
- **Ambient 기본 크기 420×180 → 280×120** (2배 정수 배율). 크기 설정은 2×~6× 정수 단계로만 바꿀 수 있습니다.
- Ambient 렌더링 15 → 12 FPS.
- 텍스처를 공유 캐시에서 한 번만 생성합니다 (`TownArt.cached`).
- `TownState` 스키마 v2(`decor` 추가), `AppSettings` 스키마 v2.
- 마을 초기화(Reset Town) 시 장식 배치는 유지합니다.

### Migration
- v0.1 `town.json`은 그대로 읽힙니다. 기본 장식(벤치, 화분)이 추가되고, 다음 저장 때 v2로 기록됩니다.
- v0.1 `settings.json`의 너비가 v0.1 기본값 420이면 280으로 바뀝니다. 다른 너비는 가장 가까운 정수 배율로 맞춰지고, 나머지 설정은 그대로 유지됩니다.

### Fixed
- (테스트로 발견) 대화 상대가 없을 때 "대화"를 고르면 `idle`로 대체되면서 연속 반복 방지 규칙을 우회하던 문제.

### Not yet verified
- **v0.2 macOS 앱 타깃의 컴파일과 실행** (Linux에서 작성됨).
- Mac에서의 `swift test`, 수동 시나리오 7개, CPU·메모리 측정.

## [0.1.0-alpha] — 2026-10-21

### Fixed
- macOS에서 `CGRect` 기하 속성(`minX` 등)을 찾지 못하던 문제: `OverlayLayout`에 `import CoreGraphics` 추가 (Linux Foundation과의 차이).
- Demo 낮·밤 순환 토글의 배타적 접근(Exclusivity) 위반 컴파일 오류.
- Command Line Tools 환경에서 `swift test`가 XCTest를 찾지 못하던 문제: 테스트를 Swift Testing으로 이전.

### Verified
- Apple Silicon Mac (Command Line Tools, macOS 27 SDK)에서 `swift run OddlyTown` 빌드 및 실행.
- 같은 환경에서 `swift test` 36개 통과 (7개 스위트).

### Added
- Swift Package: `OddlyTownCore` (Foundation 전용) + `OddlyTown` macOS 앱 타깃(macOS에서만 활성).
- `scripts/build-app.sh`: `build/Oddly Town.app` 생성, ad-hoc 서명.
- `scripts/test-core-docker.sh`: 공식 Swift 이미지로 Linux에서 코어 테스트.
- `scripts/render-art-preview.py`: Xcode 없이 픽셀아트·배치 미리보기.
- 투명 오버레이 패널 (non-activating, 클릭 통과, 창 레벨, Spaces/전체 화면 옵션, 드래그 이동).
- 메뉴 막대 메뉴: Show/Hide, Pause/Resume, Click-through, Activity Tracking, Town Status, Reset Window Position, Settings, Quit, (개발자) Developer.
- SpriteKit 마을: ASCII 픽셀맵 원본 아트, 주민 2명, 구름, 나무 흔들림, 연기, 깃발, 별, 해/달.
- 낮·밤 4단계 색조와 조명, 23~5시 집 소등.
- 성장 엔진: 3단계(2h/6h), 하루 3시간 상한, 레벨별 시설.
- 활동 감지(옵트인, 동의 대화상자): 번들 ID → 5개 카테고리, 이벤트 기반, 자리 비움 5분 제외, 구간 상한 180초.
- 카테고리별 시설: 공방(Development), 꽃밭·이젤(Creative), 도서관(Productivity), 축제 깃발(Entertainment).
- 로컬 JSON 저장/복원, 손상 파일 백업 후 복구, 관대한 필드 디코딩.
- SwiftUI 상태 창·설정 창, 활동 기록/마을 초기화.
- 개발자 모드(`--dev` / `ODDLY_DEV=1`): 별도 데이터 폴더, 5초 틱, 시간 배속, Demo Mode(저장 안 됨).
- 테스트 36개: 성장, 일일 상한, 카테고리 규칙, 분류기, 누적기, 저장/복구, 설정, 레이아웃, 낮·밤, 통합 시뮬레이션.

### Not yet verified
- 수동 테스트 체크리스트, `.app` 번들 빌드.
- 성능 목표 수치.
