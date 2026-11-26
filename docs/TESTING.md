# Testing

## 자동 테스트

| 명령 | 환경 | 범위 |
|---|---|---|
| `swift test` | Mac | `OddlyTownCore` 전체 |
| `scripts/test-core-docker.sh` | Linux + Docker | 동일 (macOS 타깃은 자동 제외) |
| `scripts/smoke-run.sh` | Mac (`scripts/build-app.sh` 후) | 번들 앱 실행 → 살아 있는지 확인 → CPU·메모리 샘플링 → SIGTERM 종료 → `town.json` 저장 확인 |
| CI (`.github/workflows/ci.yml`) | GitHub macOS + Linux | 위 전부: 앱 타깃 빌드, 테스트, 번들링, 스모크 실행(일반·`--dev`), 컴파일러 경고 주석 |

| 버전 | Mac (CLT, macOS 27 SDK) | Linux Docker (`swift:6.0-jammy`) |
|---|---|---|
| v0.1.0 | 36개 통과 | 36개 통과 |
| v0.2.0 | 70개 통과 | 70개 통과 |
| Unreleased (Capture Studio) | **80개 통과** (CI, Xcode 16.4) | **80개 통과** |

### 검증 항목

**v0.1부터 유지:**
- 성장 엔진, 일일 상한, 진행률
- 카테고리 → 시설 규칙
- 활동 감지가 꺼져 있어도 정상 성장
- 분류기, 활동 누적기
- 저장·손상 복구, 레이아웃
- 3일 통합 시뮬레이션

**v0.2 추가 (34개):**

| 요구사항 | 테스트 |
|---|---|
| 주민 행동 상태 전환 | `dayHasVarietyAndNoImmediateRepeats`, `eveningSendsPeopleHome`, `socializingPairsTwoResidents`, `gatheringBringsEveryoneToThePlaza`, `residentCountChangesWithGrowth` |
| 행동별 최소 지속 시간 | `everyPlanRespectsItsMinimumDuration` (모든 시간대 × 400회 결정) |
| 활동 카테고리에 따른 주민 행동 | `workshopTurnsWorkIntoWorkshopTime`, `creativeAndProductivityBuildingsAddTheirOwnBehaviour`, `noFeatureBehaviourAtNight` |
| 이벤트 간격·동시 발생 제한 | `nothingHappensDuringTheFirstQuietPeriod`, `neverTwoAtOnceAndAlwaysEnds`, `eventsAreRareAndSpacedOut`, `eventsEndAfterTheirDuration`, `longerTicksScaleTheChance`, `respectsConditions`, `forceReplacesTheRunningEvent` |
| 장식 배치 저장·복원 | `decorSurvivesRestart`, `placeAndRemove`, `lockedItemsStaySavedButHidden`, `lenientDecoding`, `badDecorFallsBackToStandardWithoutLosingProgress` |
| 기존 v0.1 저장 데이터 로딩 | `v1TownLoadsWithProgressKeptAndDefaultDecor`, `v1SettingsKeepChoicesAndMoveToCompactDefault`, `v1CustomWidthIsKeptAndSnapped`, `v2SettingsWith420StayAt420` |
| Ambient/Town Mode 상태 일치 | `bothModesSeeTheSameTownAfterEditing`, `snapshotAppliesHiddenFeaturesAndLockedDecor` |
| 활동 추적 비활성화 시 정상 성장 | `growthWorksWithTrackingDisabled` (v0.1) + 행동 테스트는 시설 없이도 기본 행동 6종 확인 |

화면 동작(애니메이션, 창, 클릭)은 자동 테스트하지 않습니다. 아래 수동 시나리오로 확인합니다.

## 필수 수동 시나리오 (Mac) — v0.2

빌드: `scripts/build-app.sh && open "build/Oddly Town.app"`. 빠른 확인은 `swift run OddlyTown --dev`(Developer 메뉴 → Demo Mode).
결과는 날짜와 함께 CHANGELOG의 "Verified"에 적습니다. **아래 항목은 아직 하나도 확인되지 않았습니다.**

1. **장시간 방치**
   - [ ] 1시간 이상 아무것도 하지 않음 → 주민이 계속 다양한 행동을 함, 이벤트가 가끔 일어남
   - [ ] 메모리 증가가 없음 (아래 샘플링 명령)
2. **여러 앱 번갈아 사용** (활동 감지 켬, `--dev`)
   - [ ] 터미널/Xcode → Level 2 이후 공방 등장, 주민이 공방에서 망치질
   - [ ] Figma/사진 → 꽃밭, 주민이 쪼그려 앉아 구경
3. **클릭 통과**
   - [ ] Click-through 켠 상태로 마을 아래 앱을 클릭·스크롤할 수 있음, 드래그·더블클릭은 동작하지 않음
   - [ ] Click-through 끈 상태에서 투명 영역(하늘 부분) 클릭이 아래 앱으로 가는지 기록 (macOS 기본 동작 확인용)
4. **Town Mode에서 장식 변경**
   - [ ] 더블클릭과 메뉴 양쪽으로 열림, Ambient 마을은 숨음
   - [ ] 주민·건물·장식 자리 클릭 → 화살표와 설명
   - [ ] 장식 자리에 랜턴 배치 → 밤(Demo: Time: Night)에 빛남
   - [ ] 벤치를 다른 자리로 옮김 → 주민이 새 벤치에 앉음
   - [ ] 들꽃 숨기기 → 양쪽 모드에서 사라짐
   - [ ] Back to Ambient / Esc / 창 닫기 → Ambient 마을이 다시 나타나고 같은 장식
5. **종료 후 재실행**
   - [ ] 레벨, 장식, 숨긴 기능, 창 위치, 크기 유지
   - [ ] v0.1 데이터 폴더를 그대로 두고 v0.2 실행 → 레벨 유지, 창이 280×120으로 바뀜, `town.json`에 `"schemaVersion" : 2`
6. **잠자기 → 복귀**
   - [ ] 잠잔 시간만큼 갑자기 성장하지 않음
   - [ ] 복귀 후 주민이 정상적으로 움직임 (멈춘 채로 남지 않음)
   - [ ] 디스플레이 잠자기 중 CPU ≈ 0
7. **외부 모니터 연결/해제**
   - [ ] 마을이 화면 밖으로 사라지지 않음
   - [ ] Town Mode 창 위치가 다음에 열 때 유지

### 로그인 시 열기 · 동작 줄이기 (Unreleased)
`scripts/build-app.sh` 후 `.app`으로 실행합니다(`swift run`에서는 Open at Login이 비활성이어야 정상).
- [ ] Settings → Startup → Open at login 켬 → 시스템 설정 → 일반 → 로그인 항목에 Oddly Town이 보임 (승인이 필요하면 안내 창 → "Open Login Items"로 이동)
- [ ] 로그아웃 → 로그인 후 마을이 자동으로 뜸
- [ ] 시스템 설정에서 항목을 끄고 앱으로 돌아옴 → Settings 토글과 메뉴 체크가 꺼짐으로 바뀜
- [ ] 끄기 → 로그인 항목에서 사라짐
- [ ] 손쉬운 사용 → 디스플레이 → 동작 줄이기 켬(앱 실행 중) → 구름·나무·연기·깃발·별·반딧불이가 멈추고 주민은 계속 걸음, Settings에 안내 문구
- [ ] 동작 줄이기 켠 상태로 Town Mode 열기 → 같은 상태. 시설 등장은 제자리 페이드
- [ ] 동작 줄이기 끔 → 장식 움직임이 다시 시작됨
- [ ] Capture Studio는 동작 줄이기와 관계없이 모든 움직임 유지

### 계절 (Unreleased, 4a)
`swift run OddlyTown --dev` → Developer → Demo Mode.
- [ ] Season: Spring/Summer/Autumn/Winter → 땅, 나무, 지붕 눈이 즉시 바뀜. Ambient와 Town Mode가 같은 계절
- [ ] Winter + Time: Night → 눈 위에 밤 색조, 창문 불빛이 눈에 가려지지 않음
- [ ] Season: Real Calendar → 실제 계절로 돌아옴 (11월 = 가을, 12월 1일 0시부터 겨울)
- [ ] Settings → Seasons: Off → 여름 모습, Southern → 12월에 여름. 설정 문구의 "Now:"가 맞음
- [ ] Town Status와 Town Mode 패널에 계절 표시
- [ ] Capture Studio: E로 계절 순환, 6 = Winter night, 1–5는 실제 계절
- [ ] 나무 흔들림이 계절이 바뀐 뒤에도 계속됨. 동작 줄이기가 켜져 있으면 계절을 바꿔도 멈춘 채로 있음
- [ ] 메모리: 계절을 여러 번 바꿔도 증가가 멈춤 (계절 텍스처는 계절당 한 번만 생성)

### 날씨 (Unreleased, 4b)
`--dev` → Demo Mode.
- [ ] Weather: Rain → 1.5초 동안 빗줄기가 나타나고, 마을이 흐려지고, 해가 사라짐. 밖에 있는 주민에게 노란 우산. 선택 화살표가 우산 위에 표시됨
- [ ] Weather: Snow → 눈송이가 천천히 흔들리며 떨어짐, 우산 없음
- [ ] Weather: Clear → 입자가 페이드아웃 후 멈춤(CPU가 비 오기 전 수준으로 돌아옴)
- [ ] Rain + Time: Night → 밤 색조 위에 빗줄기, 창문 불빛 정상
- [ ] 비 오는 동안 주민 대부분이 집에 있다가 가끔 나옴 (Town Mode에서 몇 분 관찰)
- [ ] 동작 줄이기 켬 → 입자 사라짐, 흐린 색조·우산은 유지. 끄면 다시 내림
- [ ] Capture Studio: W로 날씨 순환, Ambient 투명 영역(하늘)에도 빗줄기가 보임
- [ ] 성능: 비 오는 동안 CPU를 `scripts/measure-resources.sh`로 측정해 맑은 날과 비교

### 기타 확인
- [ ] 실행 시 Dock 아이콘 없음. Ambient 마을 클릭 시 다른 앱의 키보드 포커스 유지
- [ ] Settings → Size: 2×~6× 단계로만 바뀌고 픽셀이 흐려지지 않음
- [ ] 늦은 밤(23시 이후) 모든 주민이 집 안, 집 불 꺼짐, 가로등·랜턴은 켜짐
- [ ] Demo: 이벤트 3종, 주민 행동 8종, Level/Time 전환, 화면 모서리 "DEMO" 표시
- [ ] Demo 중 장식 변경 → Demo를 끄면 원래 장식으로 돌아옴 (실제 데이터 미변경)
- [ ] 전체 화면 앱, Spaces 전환, 다중 모니터 (v0.1 항목 유지)

## 성능 측정 방법

목표: 대기 메모리 150MB 이하, 평균 CPU 약 1% 이하, Ambient 10~15 FPS(현재 설정 12). **아래 측정을 하기 전에는 목표를 달성했다고 주장하지 않습니다.**

측정할 상태:
- Ambient 애니메이션 중
- 일시정지
- 숨김
- Town Mode 열림
- Town Mode를 닫은 직후 (자원 해제 확인)
- 다른 앱 전체 화면

### Activity Monitor
1. Release로 빌드한 `.app`을 실행합니다. `swift run`의 Debug 빌드는 수치가 높게 나옵니다.
2. CPU 탭에서 "OddlyTown"을 찾고 업데이트 빈도를 2초로 맞춥니다.
3. 상태마다 5분씩 % CPU 평균과 메모리를 기록합니다. Energy 탭의 "에너지 영향"도 기록합니다.

### 터미널 샘플링 (기록용)
`scripts/measure-resources.sh`를 씁니다.
- CPU: ps의 감쇠 평균(`%cpu`) 대신 누적 CPU 시간의 변화로 계산하므로 실제 평균입니다.
- 메모리: RSS와, macOS에서는 Activity Monitor의 "메모리"와 같은 physical footprint(`vmmap --summary`)를 기록합니다.

```bash
open "build/Oddly Town.app"
scripts/measure-resources.sh -d 300 -i 5 -o ambient.csv                 # 상태 하나당 5분
scripts/measure-resources.sh -d 300 --max-cpu 1 --max-mem 150          # 목표 미달이면 exit 2
```

결과 요약(평균·최대 CPU, 메모리 시작/끝/최대/변화량)을 상태별로 이 문서나 CHANGELOG의 "Verified"에 날짜와 함께 적습니다. 장시간 방치 시나리오에서는 `-d 3600 -i 30`처럼 쓰고 메모리 "change"가 0 근처인지 봅니다.

### Instruments
- **Allocations**: Town Mode를 5번 열고 닫으며 "Mark Generation"을 찍어 세대 사이 증가가 0에 가까운지 확인합니다. 장시간 방치 중에도 1분 간격으로 확인합니다.
- **Time Profiler**: 10분 기록해서 SpriteKit 렌더 외 핫스팟이 없는지(특히 `TownLife`, `EventScheduler`) 확인합니다.
- **Leaks**: 30분 실행 후 확인합니다.
- **powermetrics**: `sudo powermetrics --samplers tasks -i 5000 | grep -i oddly`로 wakeup 횟수를 봅니다.

### 목표 미달 시 조치 순서
1. Ambient FPS 12 → 10
2. 별·연기·구름 노드 수 축소
3. 주민 행동 지속 시간 늘리기 (`ResidentActivity.durationRange`)
4. 낮·밤 색조를 노드별 colorize 대신 사전 생성 텍스처로 교체
