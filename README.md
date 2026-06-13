# AMA (Auto Marking App)
## 바닥충격음 차단성능 측정 포인트 자동 마킹 앱

### 개요
ARKit/LiDAR를 활용하여 바닥충격음 차단성능 측정을 위한 5개 포인트를
자동으로 계산하고 AR 화면에 표시하는 iOS 앱입니다.

**기존 방식**: 2명 × 2~3분 (줄자 수동 측정)
**AMA 사용 시**: 1명 × 45초 (AR 자동 계산)

---

### 측정 기준 (KS F 2810)
- 바닥면적 14m² 이상 → 포인트 간격 **0.75m**
- 바닥면적 14m² 미만 → 포인트 간격 **0.5m**
- 5개 포인트: 중앙 + 전/후/좌/우 (다이아몬드 배치)

---

### 앱 흐름

#### Step 1: 공간 스캔
- iPhone을 들고 방 안을 천천히 둘러봄
- LiDAR가 바닥/벽 경계를 감지 → 보라색 AR 라인으로 표시
- 바닥 면적 자동 계산 (녹색 배지)

#### Step 2: 포인트 표시
- 면적 기반으로 5개 포인트 자동 배치
- AR 화면에 번호 + 거리 + 연결선 표시
- 포인트에 가까이 가면 자동 체크 (40cm 이내)

#### Step 3: 마킹 완료
- "마킹 완료" 버튼 → 결과 저장
- 좌표, 면적, 벽 치수 등 상세 리포트
- 텍스트로 공유 가능

---

### 빌드 방법

#### 필요 환경
- Mac (macOS 14+)
- Xcode 15+
- iPhone (iOS 17+, ARKit 지원)
- Apple 계정

#### 설정
1. `AMA.xcodeproj` 열기
2. Signing & Capabilities → Team 선택
3. Bundle Identifier를 고유값으로 변경 (예: com.yourname.ama)
4. iPhone 연결 → 빌드 대상 선택 → ▶ Run

#### 주의
- **실제 기기 전용** (시뮬레이터 불가)
- LiDAR 탑재 기기(iPhone 12 Pro+)에서 최적 성능
- 무료 Apple 계정은 7일마다 재설치 필요

---

### 파일 구조
```
AMA/
├── AMAApp.swift              # 앱 진입점
├── ContentView.swift         # 메인 화면 (AR + UI 오버레이)
├── ARViewContainer.swift     # ARKit 세션, 경계선/포인트 렌더링
├── MeasurementManager.swift  # 핵심 로직 (면적 계산, 포인트 배치)
├── ResultView.swift          # 결과 화면
├── InfoView.swift            # 측정 정보 / 사용 안내
├── Assets.xcassets/          # 앱 아이콘, 색상
└── Info.plist                # 카메라 권한, ARKit 설정
```

---

© 2026 AMA - Auto Marking App
