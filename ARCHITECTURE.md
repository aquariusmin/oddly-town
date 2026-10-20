# Architecture

## 한눈에 보기

```
┌──────────────────────── OddlyTown (macOS app target) ────────────────────────┐
│                                                                              │
│  AppDelegate ──▶ AppController ◀──── MenuBarController (NSStatusItem/NSMenu) │
│                   │  ▲    │                                                  │
│      settings/    │  │    └──▶ WindowPresenter ──▶ StatusView / SettingsView │
│      callbacks    ▼  │                              (SwiftUI, AppModel)      │
│                 AppModel                                                     │
│                   │                                                          │
│   FrontmostAppMonitor ──(bundle ID)──▶ AppController ──(TownSnapshot)──▶     │
│   (NSWorkspace notifications)                     OverlayWindowController    │
│                                                    ├ OverlayPanel (NSPanel)  │
│                                                    └ TownView ▶ TownScene    │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │ uses
┌───────────────────── OddlyTownCore (Foundation only) ────────────────────────┐
│ ActivityClassifier  ActivityAccumulator  GrowthEngine + GrowthRules          │
│ TownState  TownSnapshot/DayPhase  AppSettings  JSONFileStore  OverlayLayout  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 모듈별 역할

| 구성요소 (지시서 기준) | 파일 (`Sources/` 기준, 앱 타깃은 `OddlyTown/`) | 역할 |
|---|---|---|
| App Lifecycle | `System/AppDelegate.swift` | `@main`, accessory 활성화 정책(Dock 아이콘 없음), 종료 시 저장 |
| Menu Bar Controller | `System/MenuBarController.swift` | 메뉴 막대 아이콘, 열 때마다 메뉴 재구성, Developer 하위 메뉴 |
| Overlay Window Controller | `System/OverlayWindowController.swift` | 투명 non-activating 패널, 위치/크기, 클릭 통과, 창 레벨, Spaces 동작, 렌더링 on/off 판단 |
| Town Scene / Animation | `Town/TownScene.swift`, `Town/TownArt.swift`, `Town/PixelArt.swift` | 노드 생성(1회), 스냅샷 적용, SKAction 기반 반복 애니메이션 |
| Town Growth Engine | `OddlyTownCore/GrowthEngine.swift`, `OddlyTownCore/GrowthRules.swift` | 순수 함수: (상태, 시간, 활동) → 새 상태, 레벨, 해금 시설 |
| Activity Monitoring | `System/FrontmostAppMonitor.swift`, `OddlyTownCore/ActivityAccumulator.swift` | 전면 앱 변경 이벤트 → 카테고리별 추정 시간 |
| Activity Classification | `OddlyTownCore/ActivityClassifier.swift` | 번들 ID → 카테고리 (사용자 오버라이드 > 정확 일치 > 접두사 > Other) |
| Local Persistence | `OddlyTownCore/JSONFileStore.swift`, `OddlyTownCore/TownState.swift` | 원자적 JSON 저장, 손상 파일 백업 후 기본값 복구, 관대한 디코딩 |
| Settings Manager | `OddlyTownCore/AppSettings.swift`, `UI/AppModel.swift`, `UI/SettingsView.swift` | 설정 모델(Codable), SwiftUI 바인딩, 변경 시 즉시 저장·적용 |

규칙은 한 곳에 모여 있습니다.
- 성장 수치와 활동 → 시설 매핑: `GrowthRules.standard`
- 앱 분류표: `ActivityClassifier.defaultExact` / `defaultPrefixes`
- 마을 배치·그래픽: `TownScene.build*()` / `TownArt`

## 데이터 흐름

1. **틱** (일반 60초, 개발자 모드 5초; `Timer`, tolerance 20%)
   `AppController.tick()` → 경과 시간(최대 틱 간격×3으로 제한) × timeScale을 `GrowthEngine.advancing`에 전달 → 일일 상한 적용 → `TownState` 갱신.
2. **활동** (켜져 있을 때만)
   `NSWorkspace.didActivateApplicationNotification` → 번들 ID → `ActivityClassifier` → `ActivityAccumulator.switchTo` → 이전 카테고리 구간을 크레딧. 매 틱 `checkpoint`로 구간을 잘라 쌓고, 5분 이상 입력이 없으면 그 구간은 0으로 처리. 한 구간 최대 180초.
   저장되는 것은 `TownState.activitySeconds`(카테고리 → 초)뿐입니다.
3. **스냅샷**
   `TownState` (또는 Demo 상태) → `TownSnapshot { level, features, phase, lateNight }` → 이전과 다를 때만 `TownScene.apply`.
4. **저장**
   레벨 변경 시, 5분마다, 잠자기/사용자 전환 직전, 종료 시 `town.json` 저장. 설정은 변경 즉시 `settings.json`.
   `~/Library/Application Support/OddlyTown/` (개발자 모드는 `OddlyTown-Dev/`).
5. **복구**
   JSON 파싱 실패 → `town.corrupt-<timestamp>.json`으로 옮기고 새 마을 시작. 일부 필드만 깨진 경우 필드별 기본값/0으로 보정(음수·NaN 제거, 모르는 카테고리 무시).

### 잠자기와 시간

- 성장은 "앱이 실행 중이고 Mac이 깨어 있는 시간"입니다. 잠자기 동안 틱이 없고, 깨어난 직후 큰 경과 시간은 틱 간격×3으로 잘립니다.
- 활동 감지가 꺼져 있어도 성장 엔진은 그대로 동작합니다 (테스트: `testGrowthWorksWithTrackingDisabled`).

### Demo Mode

`AppController.demo: DemoState?`가 있으면 스냅샷을 Demo 상태에서 만듭니다. `TownState`를 읽기만 하고 쓰지 않으며, 디스크에 저장하지 않습니다. 개발자 모드에서만 메뉴가 보입니다.

## 렌더링과 성능 전략

- **15 FPS** (`SKView.preferredFramesPerSecond`). 픽셀아트라 체감 차이가 작고 GPU/CPU 부담이 줄어듭니다.
- **노드는 시작 시 한 번만 생성** (~90개 스프라이트). 이후에는 숨김/표시, 색조, 알파만 바뀝니다. 텍스처도 시작 시 생성.
- **모든 반복 애니메이션은 `SKAction.repeatForever`** — `update(_:)` 프레임 콜백을 쓰지 않고 클로저 기반 액션도 없습니다. 주민 경로는 시설 구성이 바뀔 때만 다시 만듭니다.
- **렌더링 중단 조건**: 숨김, 애니메이션 꺼짐/일시정지, 창이 가려짐(`occlusionState`), 디스플레이 잠자기 → `SKView.isPaused = true` (렌더 루프 정지). 정지 중 상태가 바뀌면 0.5~4.5초만 렌더링을 켜서 한 번 그립니다(`requestRedraw`). 일시정지 중에는 `world` 노드도 멈춰 클릭 말풍선만 움직입니다.
- **폴링 없음**: 전면 앱은 이벤트 기반. 타이머는 성장 틱 1개(60초)와 Demo 순환용(데모 중에만).
- **텍스처**: 1 아트 픽셀 = 1 텍셀, `filteringMode = .nearest`, 월드 노드 ×3 스케일. `Resources/Art/<name>.png`가 있으면 생성 텍스처 대신 사용.

측정 방법은 [docs/TESTING.md](docs/TESTING.md)에 있습니다. **수치는 아직 측정되지 않았습니다.**

## 창 동작

- `NSPanel` + `.borderless` + `.nonactivatingPanel`, `canBecomeKey = false` → 클릭해도 다른 앱의 포커스를 뺏지 않음.
- 창 레벨: 기본 `.floating`(일반 창 위). 설정에서 끄면 데스크톱 아이콘 바로 위 레벨(일반 창 뒤, 바탕화면 위젯처럼).
- Spaces: `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`. 전체 화면 앱 위 표시(`.fullScreenAuxiliary`)는 **기본 꺼짐** — 시스템 제한을 우회하지 않고, 전체 화면에서는 자연스럽게 사라지는 쪽을 기본값으로 했습니다.
- 위치 계산(`OverlayLayout`)은 AppKit과 분리되어 테스트됩니다. 화면 구성이 바뀌면 보이는 영역 안으로 다시 맞춥니다.
- 클릭 통과 중에는 드래그도 막히므로 위치/크기 조절은 메뉴와 설정 창에서 합니다.

## 확장 지점

- 새 시설: `TownFeature`에 case 추가 → `GrowthRules`에 규칙 → `TownScene.build*`에 노드 추가.
- 새 카테고리 규칙: `ActivityClassifier` 표 수정, 또는 사용자 `categoryOverrides`.
- 정식 아트: 같은 이름의 PNG를 `Resources/Art/`에 넣기.
- 저장 형식 변경: `TownState.schemaVersion`을 올리고 `init(from:)`에서 마이그레이션.
