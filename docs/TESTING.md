# Testing

## 자동 테스트

| 명령 | 환경 | 범위 |
|---|---|---|
| `swift test` | Mac | `OddlyTownCore` 전체 |
| `scripts/test-core-docker.sh` | Linux + Docker | 동일 (macOS 타깃은 자동 제외) |

| 버전 | Mac (CLT, macOS 27 SDK) | Linux Docker (`swift:6.0-jammy`) |
|---|---|---|
| v0.1.0 | 36개 통과 | 36개 통과 |
| v0.2.0 | **미실행** | **70개 통과** |

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
```bash
PID=$(pgrep -x OddlyTown)
for i in $(seq 1 60); do ps -o %cpu=,rss= -p "$PID"; sleep 5; done | \
  awk '{c+=$1; m=$2>m?$2:m} END {printf "avg CPU %.2f%%, peak RSS %.1f MB\n", c/NR, m/1024}'
```

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
