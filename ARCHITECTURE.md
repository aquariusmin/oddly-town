# Architecture

## 한눈에 보기

```
┌──────────────────────────── OddlyTown (macOS app target) ────────────────────────────┐
│                                                                                      │
│  AppDelegate ──▶ AppController ◀──── MenuBarController (NSStatusItem / NSMenu)       │
│                   │   ▲   │                                                          │
│                   │   │   ├──▶ WindowPresenter ──▶ StatusView / SettingsView         │
│                   │   │   └──▶ TownModeWindowController ─┬ SKView ▶ TownScene (6×)   │
│                   ▼   │        (only while open)          └ TownModePanel (SwiftUI)  │
│                 AppModel  ◀── SwiftUI bindings / callbacks                           │
│                                                                                      │
│  FrontmostAppMonitor ─(bundle ID)─▶ AppController ─(TownSnapshot, events)─▶ scenes   │
│                                         │                                            │
│                                         └─▶ OverlayWindowController                  │
│                                              ├ OverlayPanel (NSPanel, transparent)    │
│                                              └ TownView ▶ TownScene (2×, Ambient)     │
│                                                                                      │
│  TownScene ─ TownScene+Life (ResidentSprite) ─ TownScene+Events (visitors, selection)│
│  TownArt / TownArt+Characters / TownArt+Decor / PixelArt (texture cache)             │
└───────────────────────────────────────┬──────────────────────────────────────────────┘
                                        │ uses
┌─────────────────────────── OddlyTownCore (Foundation only) ──────────────────────────┐
│ GrowthEngine + GrowthRules   ActivityClassifier   ActivityAccumulator                │
│ TownLife + ResidentBehaviorRules (resident FSM)   EventScheduler + EventRules        │
│ TownState (v2, + DecorLayout)   AppSettings (v2)   TownSnapshot.make / DayPhase      │
│ JSONFileStore   OverlayLayout   DurationText   SplitMix64                            │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## 모듈별 역할

경로는 `Sources/` 기준입니다. 앱 타깃 파일은 `OddlyTown/` 아래에 있습니다.

| 구성요소 | 파일 | 역할 |
|---|---|---|
| App Lifecycle | `System/AppDelegate.swift` | `@main`, accessory 정책(Dock 아이콘 없음), 종료 시 저장 |
| Menu Bar | `System/MenuBarController.swift` | 메뉴를 열 때마다 다시 구성, Town Mode 전환, Developer/Demo 하위 메뉴 |
| Ambient Mode | `System/OverlayWindowController.swift` | 투명 non-activating 패널, 정수 배율 크기, 클릭 통과, 창 레벨, Spaces, 렌더링 on/off, Town Mode 중 일시 중단 |
| Town Mode | `UI/TownModeWindowController.swift`, `UI/TownModePanel.swift` | 일반 창 + 6× 장면 + 정보/장식 패널. 닫으면 해제 |
| 장면 | `Town/TownScene*.swift` | 노드 1회 생성, 스냅샷 적용, 주민 행동 재생, 이벤트 연출, 선택 |
| 아트 | `Town/TownArt*.swift`, `Town/PixelArt.swift` | ASCII 픽셀맵 → 텍스처(캐시), PNG 교체 지점 |
| 성장 | `OddlyTownCore/GrowthEngine.swift`, `GrowthRules.swift` | (상태, 시간, 활동) → 새 상태, 레벨, 해금 |
| 주민 행동 | `OddlyTownCore/ResidentLife.swift` | 가중치 FSM, 최소 지속 시간, 대화 짝, 모임, 시설별 행동 |
| 이벤트 | `OddlyTownCore/TownEvents.swift` | 이벤트 규칙, 빈도·간격·동시 발생 제한 |
| 장식 | `OddlyTownCore/Decor.swift` | 4개 슬롯, 레벨 잠금, 숨길 수 있는 장식 기능 |
| 활동 | `System/FrontmostAppMonitor.swift`, `OddlyTownCore/ActivityAccumulator.swift`, `ActivityClassifier.swift` | 전면 앱 이벤트 → 카테고리 → 추정 시간 |
| 저장 | `OddlyTownCore/JSONFileStore.swift`, `TownState.swift`, `AppSettings.swift` | 원자적 JSON, 손상 파일 백업, 관대한 디코딩, 스키마 v1→v2 |
| 설정 | `UI/AppModel.swift`, `UI/SettingsView.swift` | SwiftUI 바인딩, 변경 즉시 저장·적용 |

**규칙은 한 곳에 모여 있습니다.**
- 성장 수치, 활동 → 시설: `GrowthRules.standard`
- 시설 → 주민 행동, 시간대별 가중치: `ResidentBehaviorRules`
- 행동별 지속 시간: `ResidentActivity.durationRange`
- 이벤트 종류·확률·간격: `EventRules.standard`
- 장식 종류와 필요 레벨: `DecorItem`
- 앱 분류표: `ActivityClassifier`
- 화면 위치(장소 → 좌표): `TownScene.position(of:resident:)`, `TownArt.decorSlots`

## 데이터 흐름

1. **틱** (60초, 개발자 모드 5초)
   `AppController.tick()`에서 세 가지를 처리합니다.
   - 성장: 경과 시간(최대 틱×3)에 배속을 곱해 `GrowthEngine`에 넘깁니다. 일일 상한이 적용됩니다.
   - 활동: 카테고리 체크포인트를 기록합니다.
   - 반영: 스냅샷을 다시 만들고 `EventScheduler.update`를 호출합니다.
2. **스냅샷**
   `TownSnapshot.make(state:engine:now:)`가 레벨, 해금 시설 − 숨긴 시설, 레벨이 허용하는 장식, 시간대를 계산합니다. 결과가 바뀌었을 때만 모든 장면(Ambient, 열려 있다면 Town Mode)에 `apply`합니다. Demo Mode에서는 `DemoState`로 같은 함수를 호출합니다.
3. **주민** (장면마다 `TownLife` 하나)
   - 진행: `ResidentSprite`가 `BehaviorPlan` 하나를 SKAction 시퀀스(걷기 → 행동 → 마지막 콜백)로 재생합니다. 콜백에서 `TownLife.nextPlans`가 다음 계획을 정합니다.
   - 대화: 비어 있는 다른 주민을 함께 끌어옵니다.
   - 저장 안 함: 순간 상태는 저장하지 않습니다. 실행 시에는 현재 시간대에 맞는 계획부터 바로 시작합니다(밤이면 집 안).
4. **이벤트**
   스케줄러는 활성 이벤트를 최대 1개만 둡니다. 끝난 뒤 25분은 쉬고, 그 뒤에는 분당 15% 확률로 시작합니다. 확률은 틱 길이에 비례해 조정됩니다. 시작/종료 변화를 각 장면이 연출합니다. 고양이와 여행자는 미리 만든 노드를 쓰고, 모임은 `gatherEveryone`을 씁니다. 마을이 보이지 않으면 시작하지 않습니다.
5. **Town Mode 편집**
   패널 바인딩이 `AppController.placeDecor`/`setFeature(hidden:)`를 호출하면 `TownState.decor`를 바꾸고 즉시 저장한 뒤 `refresh()`합니다. 그러면 양쪽 장면이 같은 스냅샷을 받습니다. Demo 중에는 `DemoState.decor`만 바뀝니다.
6. **저장**
   레벨이 바뀔 때, 5분마다, 장식을 바꿀 때, 잠자기/사용자 전환 직전, 종료할 때 `town.json`을 저장합니다. 설정은 변경 즉시 `settings.json`에 저장됩니다. Town Mode 창 위치는 macOS 프레임 자동 저장(`OddlyTownTownMode`)을 씁니다.

### 스키마와 마이그레이션

| 파일 | v1 (0.1.0) | v2 (0.2.0) | 마이그레이션 |
|---|---|---|---|
| `town.json` | 성장, 활동, 일일 상한 | + `decor { slots[4], hiddenFeatures }` | `decor`가 없거나 깨졌으면 `DecorLayout.standard`. 다음 저장 때 `schemaVersion: 2`로 씀 |
| `settings.json` | 기본 너비 420 | `schemaVersion`, 기본 너비 280, 너비는 140의 배수 | v1이면서 420이었다면 280으로. 그 외 너비는 가장 가까운 배수로 |

필드는 모두 `decodeIfPresent` + 기본값으로 읽습니다. 모르는 장식이나 카테고리는 무시하고, 음수와 NaN은 0으로 바꿉니다. JSON 자체가 깨졌으면 `*.corrupt-<time>.json`으로 옮긴 뒤 새로 시작합니다.

## 렌더링과 성능 전략

- **정수 배율:** 월드는 140×60 픽셀입니다. Ambient는 2~6×(설정), Town Mode는 6×이고, 장면 크기 = 뷰 크기라서 화면에서 추가 스케일링이 없습니다. 텍스처는 `filteringMode = .nearest`입니다.
- **FPS:** Ambient 12, Town Mode 20.
- **노드는 시작 시 한 번만 생성:**
  - 시설·장식은 슬롯마다 8종 전부를 미리 만들고 표시 여부만 바꿉니다.
  - 주민 3명, 고양이, 여행자, 선택 화살표도 미리 만들어 둡니다.
  - 실행 중에 새로 만드는 것은 짧게 쓰는 SKAction뿐입니다.
- **텍스처 캐시:** `TownArt.cached`. 두 모드가 공유하고, Town Mode를 다시 열어도 새로 만들지 않습니다.
- **프레임마다 실행하는 로직 없음:**
  - `update(_:)`를 쓰지 않습니다.
  - 주민 결정은 행동이 끝날 때만 내립니다(주민당 10~60초).
  - 이벤트 판정은 60초 틱에서만 합니다.
- **Ambient 렌더링 중단:** 숨김, 애니메이션 꺼짐, 가려짐(`occlusionState`), 디스플레이 잠자기, Town Mode 열림일 때 `SKView.isPaused = true`로 렌더 루프를 멈춥니다. 정지 중 상태가 바뀌면 잠깐(0.5~4.5초) 그립니다. 일시정지 중에는 `world`도 멈춰서 주민 결정과 이벤트 연출이 진행되지 않습니다.
- **Town Mode 해제:** 닫으면 `presentScene(nil)`을 호출하고 컨트롤러를 해제하며, 선택 갱신 타이머도 멈춥니다. 최소화하면 렌더링을 멈춥니다.
- **타이머:**

  | 타이머 | 주기 | 도는 동안 |
  |---|---|---|
  | 성장 틱 | 60초 | 항상 |
  | Town Mode 선택 정보 | 2초 | Town Mode가 열려 있을 때만 |
  | Demo 낮·밤 순환 | 5초 | 순환 기능을 켰을 때만 |

수치는 아직 측정하지 않았습니다. 측정 방법은 [docs/TESTING.md](docs/TESTING.md)에 있습니다.

## 창 동작

- **Ambient:** `NSPanel` + `.borderless` + `.nonactivatingPanel`이고 `canBecomeKey = false`라서 클릭해도 포커스를 가져가지 않습니다.
  - 창 레벨: `.floating` 또는 데스크톱 아이콘 바로 위.
  - Spaces: `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`. 전체 화면 위 표시(`.fullScreenAuxiliary`)는 기본 꺼짐입니다.
- **더블클릭:** `TownView.mouseUp`의 `clickCount >= 2` → Town Mode. 첫 번째 클릭은 평소처럼 말풍선을 띄우므로 단일 클릭·드래그와 충돌하지 않습니다. 클릭 통과 중에는 마우스 이벤트를 받지 않기 때문에 메뉴로 엽니다.
- **Town Mode:** 일반 `NSWindow`(titled, closable)입니다. 앱을 활성화해서 열고, `.fullScreenNone`이며 크기는 고정입니다.

## 확장 지점

- **새 주민 행동:** `ResidentActivity`에 case 추가 → `ResidentBehaviorRules.weights`/`featureActivities` → `ResidentSprite.activity(_:at:)`에 애니메이션 → `TownArt.residentRows`에 프레임.
- **새 이벤트:** `TownEventKind` + `EventRules.standard`에 규칙 → `TownScene.startEvent`에 연출.
- **새 장식:** `DecorItem` case + `TownArt.decorRows`.
- **새 시설:** `TownFeature` → `GrowthRules` → `TownScene.build*`.
- **정식 아트:** 같은 이름의 PNG를 `Resources/Art/`에 넣으면 됩니다(예: `cottage.png`, `decor-bench.png`, `resident-mori-walkA.png`).
- **저장 형식 변경:** 스키마 버전을 올리고 `init(from:)`에서 변환한 뒤, `MigrationTests`에 이전 버전 JSON을 그대로 추가합니다.
