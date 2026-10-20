# Changelog

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
