# Testing

## 자동 테스트

| 명령 | 환경 | 범위 |
|---|---|---|
| `swift test` | Mac | `OddlyTownCore` 전체 |
| `scripts/test-core-docker.sh` | Linux + Docker | 동일 (macOS 타깃은 자동 제외) |

v0.1.0-alpha 결과: **Linux Docker (`swift:6.0-jammy`)에서 36개 테스트 통과.** Mac에서는 앱 빌드·실행만 확인했고 `swift test`는 아직 실행하지 않았습니다.

검증 항목:
- 성장 엔진: 레벨 경계, 일일 상한, 다음 날 초기화, 개발자 모드 상한 해제, 잘못된 값 무시, 진행률
- 카테고리 규칙: 서로 다른 카테고리가 서로 다른 시설을 해금, 최소 레벨, Other는 시설 없음
- 활동 감지 꺼짐: 시간만으로 Level 3 도달
- 분류기: 정확 일치, 접두사, 정확 일치 우선, 오버라이드, 대소문자, 미분류 → Other
- 누적기: 전환 시 크레딧, 체크포인트, 긴 공백 상한, 자리 비움, 일시정지/재개, 시계 역행
- 저장: 왕복, 파일 없음, 손상 JSON 백업·복구, 잘못된 모양, 부분/잘못된 필드, 설정 기본값·보정
- 레이아웃: 모서리 배치, 화면 밖 보정, 다중 화면 선택
- 통합: 3일 × 4시간(코드 편집기 2h + Figma 2h) 시뮬레이션 후 저장·복원

## 수동 테스트 체크리스트 (Mac)

빌드: `scripts/build-app.sh && open "build/Oddly Town.app"` (개발자 모드는 `.../MacOS/OddlyTown --dev`)

### 창
- [ ] 실행 시 Dock 아이콘 없음, 메뉴 막대에 집 아이콘
- [ ] 오른쪽 아래에 마을 표시, 창 테두리/그림자 없음, 배경 투명
- [ ] 마을 클릭 시 다른 앱의 키보드 포커스 유지 (텍스트 편집기에 입력하는 중 클릭해 보기)
- [ ] 마을 클릭 → 말풍선 (레벨/진행률), 4초 후 사라짐
- [ ] 드래그로 이동 → 재실행 후 위치 유지
- [ ] 설정의 크기 슬라이더 → 7:3 비율로 크기 변경
- [ ] Click-through 켜기 → 아래 앱이 클릭됨, 드래그 불가 / 끄기 → 원상복구
- [ ] "Float above other windows" 끄기 → 일반 창 뒤, 바탕화면 위
- [ ] Reset Window Position → 주 화면 오른쪽 아래로
- [ ] Hide/Show Town

### Spaces / 전체 화면 / 다중 모니터
- [ ] 다른 데스크톱(Space)으로 이동해도 마을 유지
- [ ] 다른 앱을 전체 화면으로: 기본값에서는 마을이 보이지 않음
- [ ] "Also show over full-screen apps" 켜기 → 전체 화면 위에 보이는지 (결과 기록)
- [ ] 외장 모니터 연결/해제 시 마을이 화면 밖으로 사라지지 않음
- [ ] 두 번째 모니터로 드래그 → 재실행 후 그 화면에 유지

### 애니메이션 / 낮·밤
- [ ] 주민 걷기·멈춤, 구름 이동, 나무 흔들림
- [ ] Pause Animation → 모두 정지, Resume → 재개
- [ ] (Demo) Time: Night → 어두운 색조, 창문·가로등 점등, 달·별 / Cycle → 5초마다 전환

### 성장 / 저장
- [ ] 개발자 모드: 약 2분 후 Level 2, 약 6분 후 Level 3 (60배속, 5초 틱)
- [ ] 종료 후 재실행 → 레벨 유지
- [ ] `town.json`을 망가뜨린 뒤 실행 → 앱이 뜨고 새 마을, `town.corrupt-*.json` 생성
- [ ] 일반 모드 데이터(`OddlyTown/`)와 개발자 모드 데이터(`OddlyTown-Dev/`)가 분리됨

### 활동
- [ ] Activity Tracking 켜기 → 동의 대화상자, "Not Now" 시 꺼진 상태 유지
- [ ] 개발자 모드에서 Xcode/터미널 사용 → Level 2 이후 공방 등장 (60배속 기준 약 45초)
- [ ] Figma/사진 앱 → 꽃밭·이젤, Music/Spotify → 축제 깃발
- [ ] 상태 창의 카테고리별 시간 증가
- [ ] Reset Activity History → 활동 시설 사라짐, 레벨 유지
- [ ] 끈 상태에서도 시간 성장 계속

### 잠자기
- [ ] 잠자기 후 깨우기 → 잠잔 시간만큼 갑자기 성장하지 않음
- [ ] 디스플레이 잠자기 중 CPU ≈ 0

## 성능 측정 방법

목표: 대기 메모리 ≤ 150MB, 평균 CPU ≈ 1% 이하, 15 FPS. **아래 측정을 하기 전에는 목표 달성 여부를 주장하지 않습니다.**

### Activity Monitor (빠른 확인)
1. `.app` 번들을 Release로 빌드해 실행 (`swift run`의 Debug 빌드는 수치가 높게 나옴).
2. Activity Monitor → CPU 탭에서 "Oddly Town" 검색, `보기 > 업데이트 빈도 > 자주(2초)`.
3. 5분 동안 관찰하며 % CPU 평균과 메모리 탭의 "메모리" 값을 기록.
4. 같은 측정을 다음 상태에서 반복: 애니메이션 중 / 일시정지 / 숨김 / 다른 앱 전체 화면.
5. Energy 탭의 "에너지 영향"도 기록.

### 터미널 샘플링 (기록용)
```bash
PID=$(pgrep -x OddlyTown)
for i in $(seq 1 60); do ps -o %cpu=,rss= -p "$PID"; sleep 5; done | \
  awk '{c+=$1; m=$2>m?$2:m} END {printf "avg CPU %.2f%%, peak RSS %.1f MB\n", c/NR, m/1024}'
```

### Instruments
- **Time Profiler**: 10분 기록 → 메인 스레드에서 SpriteKit 렌더 외 핫스팟 확인.
- **Allocations**: "Mark Generation"을 1분 간격으로 찍어 세대별 증가가 0에 가까운지 확인 (반복 객체 생성 여부).
- **Leaks**: 30분 실행 후 누수 없음 확인.
- **Energy Log** 또는 `powermetrics` (`sudo powermetrics --samplers tasks -i 5000 | grep -i oddly`)로 wakeup 횟수 확인.
- SpriteKit FPS: 개발 중 `townView.showsFPS = true`를 잠시 켜서 15 FPS 유지 확인 (커밋하지 말 것).

### 목표 미달 시 조치 순서
1. FPS 15 → 10
2. 구름/별/연기 노드 수 축소
3. 비활성(다른 앱 사용 중) 상태에서 애니메이션 간격 늘리기
4. 낮·밤 색조를 노드별 colorize 대신 사전 생성 텍스처 교체로

## 장시간 실행

24시간 실행하며 1시간마다 메모리(RSS)를 기록하고 증가 추세가 없는지 확인합니다. 결과는 CHANGELOG에 기록합니다.
