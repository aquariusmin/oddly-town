# Changelog

## [0.1.0-alpha] — 2026-10-21

### Fixed
- macOS에서 `CGRect` 기하 속성(`minX` 등)을 찾지 못하던 문제: `OverlayLayout`에 `import CoreGraphics` 추가 (Linux Foundation과의 차이).
- Demo 낮·밤 순환 토글의 배타적 접근(Exclusivity) 위반 컴파일 오류.

### Verified
- Apple Silicon Mac (Command Line Tools, macOS 27 SDK)에서 `swift run OddlyTown` 빌드 및 실행.

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
- 수동 테스트 체크리스트, Mac에서의 `swift test`, `.app` 번들 빌드.
- 성능 목표 수치.
