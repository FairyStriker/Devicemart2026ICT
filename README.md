# SPCC — Smart Posture Correction Chair

> **2026 ICT 융합프로젝트 공모전 출품작**
> 17개 센서 기반 실시간 자세 분석 · 교정 의자 시스템

<p align="center">
  <img alt="Stage" src="https://img.shields.io/badge/Stage-2%20(HW%20Integration)-orange">
  <img alt="Sensors" src="https://img.shields.io/badge/Sensors-17-blue">
  <img alt="Postures" src="https://img.shields.io/badge/Postures-8-success">
  <img alt="Sample Rate" src="https://img.shields.io/badge/Sample%20Rate-50Hz-informational">
  <img alt="License" src="https://img.shields.io/badge/License-Educational-lightgrey">
</p>

---

## 작품 개요

**SPCC(Smart Posture Correction Chair)** 는 의자에 부착된 17개의 센서로 사용자의 착석 자세를 실시간으로 측정하고, 머신러닝과 규칙 기반 알고리즘을 결합하여 8종의 자세를 자동 판별하는 **AI 자세 교정 시스템**이다. 측정 결과는 모바일 앱으로 실시간 시각화되며, 세션 종료 시 LLM 기반의 맞춤형 자세 분석 리포트를 제공한다.

장시간 좌식 생활로 인한 거북목, 골반 틀어짐, 척추 측만 등 자세 불량을 **사용자가 인지하지 못하는 순간까지 정량화**하여 알려주는 것이 본 작품의 핵심 가치이다.

---

## 시스템 구성

```text
   ┌─────────────────────┐      ┌──────────────────────┐      ┌─────────────────────┐
   │   STM32F411 Node    │      │   Raspberry Pi 5     │      │     Flutter App     │
   │  ─────────────────  │      │  ──────────────────  │      │  ─────────────────  │
   │  • 12× HX711        │ UART │  • 자세 분류 (ML)    │ WiFi │  • 실시간 시각화    │
   │  • 4× VL53L0X (1D)  │ ───▶ │  • Rule-based Flag   │ ───▶ │  • 4탭 대시보드     │
   │  • 2× VL53L8CX (3D) │ 921k │  • 점수 산출         │  WS  │  • AI 리포트 열람   │
   │  • 1× MPU6050       │      │  • 리포트 생성       │      │  • 오프라인 보관    │
   │  • OLED Display     │      │  • SQLite 저장       │      │                     │
   └─────────────────────┘      └──────────────────────┘      └─────────────────────┘
        센서 50Hz 수집                FastAPI + WebSocket             Provider 상태관리
```

| 계층 | 하드웨어 / 플랫폼 | 역할 |
|------|------|------|
| **Sensor Node** | STM32F411CEU6 (Cortex-M4) | 17개 센서 50Hz 수집 · 129B 패킷 송신 |
| **Backend** | Raspberry Pi 5 + Python | 자세 분류 · 점수 산출 · 리포트 · DB |
| **Client** | Flutter (Android / Web) | 실시간 시각화 · 사용자 제어 · 리포트 열람 |

---

## 주요 기능

| # | 기능 | 설명 |
|---|------|------|
| 1 | **17개 센서 융합 분석** | 압력(12) · 척추 ToF(4) · 머리 3D ToF(2) · IMU(1) 통합 처리 |
| 2 | **8종 자세 자동 분류** | RandomForest ML + Rule-based 이중 분류 (Fallback 보장) |
| 3 | **실시간 50Hz 모니터링** | UART 921600bps · WebSocket 푸시로 지연 없는 시각화 |
| 4 | **개인화 캘리브레이션** | 사용자별 baseline 측정으로 체형 차이 보정 |
| 5 | **자리 이탈 감지** | STAND 이벤트 · 5초 이상 이탈 시 세션 일시정지 |
| 6 | **AI 리포트 생성** | Rule 기반 + LLM 확장형 해석 리포트 (운동 추천 포함) |
| 7 | **세션 / 일일 누적 분석** | 분 단위 · 일일 단위 자세 추이 SQLite 저장 |
| 8 | **PWA 시뮬레이터** | 하드웨어 없이 시스템 동작 검증 가능 |

---

## 감지 자세 (8종)

| 코드 | 한글명 | 설명 |
|------|--------|------|
| `normal` | 정자세 | 올바른 착석 자세 |
| `turtle_neck` | 거북목 | 목이 앞으로 돌출된 자세 |
| `forward_lean` | 상체 굽힘 | 상체가 앞으로 기울어진 자세 |
| `reclined` | 누워 앉기 | 상체가 뒤로 기댄 자세 |
| `side_slouch` | 측면 기울어짐 | 좌우 하중이 비대칭인 자세 |
| `leg_cross_suspect` | 다리 꼬기 의심 | 좌석 압력 비대칭 패턴 |
| `thinking_pose` | 턱 괴기 | 한쪽 팔에 체중을 지지하는 자세 |
| `perching` | 걸터앉기 | 의자 앞쪽에만 체중이 분포된 자세 |

---

## 센서 구성

| 센서 | 모델 | 수량 | 설치 위치 | 측정 항목 |
|------|------|------|-----------|-----------|
| 압력 센서 | HX711 + Loadcell | **12** | 등판(8) · 좌판(4) | 부위별 하중 분포 |
| 1D ToF | VL53L0X | **4** | 등판 척추 라인 (상→하) | 척추 곡률 거리 |
| 3D ToF | VL53L8CX | **2** | 헤드레스트 좌/우 | 머리 위치 · 거북목 검출 |
| IMU | MPU6050 | **1** | 의자 본체 | 의자 기울기 / 흔들림 |
| **합계** | — | **17** | — | — |

---

## 저장소 구조

```text
Devicemart2026ICT/
│
├── README.md                  ← 본 문서
├── .gitignore
│
└── sourceCode/
    │
    ├── RaspberryPi/           # 🧠 메인 백엔드 (Python)
    │   ├── main_real.py            # 실 하드웨어 진입점
    │   ├── main_compare.py         # ML vs Rule 분류기 비교
    │   ├── requirements.txt
    │   ├── src/
    │   │   ├── communication/      # UART · HTTP · WebSocket · BLE
    │   │   ├── sensor/             # 129B 패킷 파싱 / semantic 매핑
    │   │   ├── core/               # 자세 분류 · feature · 점수
    │   │   ├── session/            # 세션 · 프로필 · 캘리브레이션
    │   │   ├── runtime/            # 50Hz 측정 루프
    │   │   ├── app_flow/           # 상위 흐름 제어
    │   │   ├── report/             # 리포트 생성 · LLM 연동
    │   │   ├── llm/                # LLM 서비스 (확장)
    │   │   ├── storage/            # SQLite · CSV 로거
    │   │   ├── feedback/           # 부저 피드백
    │   │   └── config/             # 환경 변수 설정
    │   ├── models/                 # ML 데이터셋 / 학습 스크립트
    │   ├── saved_models/           # 학습 완료 RandomForest 모델
    │   ├── tools/                  # 가상 STM32 / 가상 앱 / 패킷 스니퍼
    │   ├── profiles/               # 사용자 프로필 JSON
    │   ├── data/                   # 수집 raw / processed 데이터
    │   └── docs/                   # 14종 설계 문서
    │
    ├── STM32/                 # ⚙️  센서 노드 펌웨어 (C / HAL)
    │   ├── SmartChair.ioc          # CubeMX 프로젝트
    │   ├── Core/                   # main / IT / SSD1306 OLED
    │   │   ├── VL53L0X_API(1D)/    # 1D ToF 라이브러리
    │   │   └── VL53L8CX_API(3D)/   # 3D ToF 라이브러리
    │   └── Drivers/                # CMSIS · STM32F4 HAL
    │
    ├── flutter_app/           # 📱 모바일 클라이언트 (Dart)
    │   ├── lib/
    │   │   ├── main.dart           # 진입점 · stage 라우팅
    │   │   ├── models/             # payload 데이터 모델 5종
    │   │   ├── services/           # api · websocket · 보고서 저장
    │   │   ├── providers/          # 전역 상태 (Provider)
    │   │   ├── widgets/            # 좌석 압력 시각화
    │   │   └── screens/            # 6종 화면 (Splash → Report)
    │   └── android/                # Android 빌드 설정
    │
    ├── SPCC-WebApp/           # 🌐 PWA 시뮬레이터
    │   ├── index.html              # React 단일 파일 시뮬레이터
    │   └── manifest.json           # PWA 매니페스트
    │
    └── rpisimulator2.py       # 🧪 가짜 RPi 서버 (앱 단독 테스트용)
```

---

## 통신 프로토콜 요약

### STM32 ↔ Raspberry Pi (UART, 921600 bps)

**ASCII Control Mode** — 시스템 제어용 텍스트 메시지

| 방향 | 메시지 | 의미 |
|------|--------|------|
| STM32 → RPi | `READY` / `LINK_OK` / `SIT` / `STAND` | 부팅 / 링크 확립 / 착석 / 이탈 |
| RPi → STM32 | `ACK` / `CHK_SIT` / `CAL` / `GO` / `STOP` | 응답 / 확인요청 / 캘리브레이션 / 측정 |

**Binary Sensor Stream** — 50Hz 129바이트 고정 길이

```text
[Header 4B] [Loadcell 48B] [Spine ToF 8B] [3D ToF 64B] [IMU 4B] [Checksum 1B]
 DAT:/CAL:    12×int32       4×uint16       32×uint16    2×int16    XOR
```

### Raspberry Pi ↔ Flutter App (HTTP / WebSocket)

| 종류 | 경로 | 용도 |
|------|------|------|
| HTTP `GET` | `/health`, `/meta` | 헬스 체크 · 시스템 상태 조회 |
| HTTP `POST` | `/command` | 11종 명령 전송 (프로필/캘리브레이션/측정 제어) |
| WebSocket | `/ws` | 7종 payload 푸시 (`meta`, `realtime_status`, `sensor_distribution`, `minute_summary`, `overall_summary`, `stand_event`, `enhanced_report`) |

---

## 실행 방법

### 1. Raspberry Pi 백엔드

```bash
cd sourceCode/RaspberryPi
pip install -r requirements.txt

# 실 하드웨어 환경
python main_real.py

# Mock STM32로 단독 테스트
POSTURE_UART_MOCK=1 python main_real.py
```

### 2. Flutter 앱

```bash
cd sourceCode/flutter_app
flutter pub get
flutter run
```

### 3. STM32 펌웨어

`sourceCode/STM32/SmartChair.ioc` 를 STM32CubeIDE 에서 열어 빌드 후 ST-Link 로 플래시한다.

### 4. 하드웨어 없이 앱 단독 검증

```bash
pip install aiohttp
python sourceCode/rpisimulator2.py
```

---

## 컴포넌트별 문서

각 컴포넌트의 상세 문서는 해당 디렉토리의 README 와 `docs/` 폴더에서 확인할 수 있다.

| 컴포넌트 | 문서 |
|----------|------|
| Raspberry Pi 백엔드 | [`sourceCode/RaspberryPi/README.md`](sourceCode/RaspberryPi/README.md) |
| Raspberry Pi 설계 문서 | [`sourceCode/RaspberryPi/docs/`](sourceCode/RaspberryPi/docs/) (14종) |
| Flutter 앱 | [`sourceCode/flutter_app/README.md`](sourceCode/flutter_app/README.md) |
| PWA 시뮬레이터 | [`sourceCode/SPCC-WebApp/README.md`](sourceCode/SPCC-WebApp/README.md) |
| LLM 통합 참고 자료 | [`sourceCode/RaspberryPi/LLM 참고.md`](sourceCode/RaspberryPi/LLM%20참고.md) |

---

## 개발 단계

| 단계 | 내용 | 상태 |
|------|------|------|
| **Stage 1** | Mock 기반 파이프라인 검증 (UART · 분류 · 리포트 · 앱 연동) | ✅ 완료 |
| **Stage 2** | 실 하드웨어 연동 · 센서 매핑 · feature threshold 보정 | 🔄 진행 중 |
| **Stage 3** | 실측 데이터 기반 ML 재학습 · LLM 리포트 엔진 통합 · 정확도 고도화 | 📅 예정 |

---

## 사용 기술

| 영역 | 기술 스택 |
|------|-----------|
| **Embedded** | C, STM32CubeMX/IDE, HAL Driver, FreeRTOS, VL53L0X/L8CX SDK |
| **Backend** | Python 3, FastAPI, Uvicorn, PySerial, NumPy, Pandas, scikit-learn (RandomForest), SQLite |
| **Mobile** | Flutter (Dart), Provider, HTTP, WebSocketChannel, SharedPreferences |
| **Web** | React (CDN), PWA, vanilla JS |
| **AI / LLM** | scikit-learn, LLM API (확장 슬롯) |
| **DevOps** | Git, GitHub, GitHub Pages |

---

## 공모전 정보

| 항목 | 내용 |
|------|------|
| **공모전명** | 2026 ICT 융합프로젝트 공모전 (디바이스마트 주최) |
| **접수 기간** | 2026.02.01 ~ 2026.03.31 |
| **응모 양식** | A4 10–30매 (DOC / HWP) — 회로도 · 소스코드 · 제작 과정 일체 + 참가신청서 |
| **심사 발표** | 2026년 5월 ~ 6월 중 (디바이스마트 홈페이지 개별 안내) |
| **공모전 페이지** | [디바이스마트 공모전 게시판](https://www.devicemart.co.kr/board/view?id=award_board&seq=151400) |

### 제출 파일 (총 4개)

1. 최종 원고 (DOC / HWP)
2. 사용 자료 압축본 (이미지 · 회로도 · 소스코드 등 원본)
3. 공모전 참가신청서
4. 사용 부품명 · 디바이스마트 상품코드 리스트

---

## 작품명

> **자세교정 의자** — Smart Posture Correction Chair (SPCC)

---

<p align="center">
  <sub>© 2026 SPCC Project · 디바이스마트 ICT 융합프로젝트 공모전 출품작</sub>
</p>
