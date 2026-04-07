# 스마트 자세 교정 의자

> **무게 센서, ToF 센서 그리고 기울기 센서를 이용한 자세 교정 의자**
> 2026 ICT 융합프로젝트 공모전 출품작 — Smart Posture Correction Chair (SPCC)

<p align="center">
  <img alt="Contest" src="https://img.shields.io/badge/Devicemart-2026%20ICT-blue">
  <img alt="MCU" src="https://img.shields.io/badge/MCU-STM32F411CEU6-03234B">
  <img alt="Edge" src="https://img.shields.io/badge/Edge-Raspberry%20Pi%205-C51A4A">
  <img alt="App" src="https://img.shields.io/badge/App-Flutter-02569B">
  <img alt="LLM" src="https://img.shields.io/badge/LLM-Qwen3.5--0.8B-purple">
  <img alt="Sample Rate" src="https://img.shields.io/badge/Sampling-50Hz-success">
  <img alt="Accuracy" src="https://img.shields.io/badge/Accuracy-~85%25-brightgreen">
</p>

---

## 작품 소개

장시간 좌식 생활로 인한 거북목, 척추 측만 등 자세 불량을 사용자가 인지하지 못하는 순간까지 정량화하여 알려주는 **엣지 컴퓨팅 기반 스마트 자세 교정 의자**이다.

의자에 부착된 **20개 모듈 / 24개 물리 센서**가 50 Hz로 사용자의 하중 분포와 신체 위치를 실시간 측정하고, **Raspberry Pi 5**에서 자세를 분석한 뒤 **로컬 LLM(Qwen3.5-0.8B)** 이 자연어 리포트를 생성한다. 모든 추론이 의자 내부에서 완료되므로 **클라우드 의존 없이 개인정보가 보호된다**.

---

## 시스템 구성 (3계층)

```text
   ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
   │  STM32F411     │UART│  Raspberry Pi5 │WiFi│  Flutter App   │
   │  센서 노드     │───▶│  분석 서버     │───▶│  모바일 클라이언트 │
   │  50 Hz 수집    │921k│  LLM 리포트    │HTTP│  실시간 시각화 │
   └────────────────┘    └────────────────┘    └────────────────┘
```

| 계층 | 폴더 | 핵심 역할 |
|------|------|----------|
| 🔧 **센서 노드** | [`sourceCode/STM32/`](sourceCode/STM32/) | 20개 모듈 50 Hz 폴링 · 129B 패킷 UART 송신 |
| 🧠 **엣지 서버** | [`sourceCode/RaspberryPi/`](sourceCode/RaspberryPi/) | 자세 분류 · 점수 산출 · LLM 리포트 · API 서버 |
| 📱 **모바일 앱** | [`sourceCode/flutter_app/`](sourceCode/flutter_app/) | 실시간 시각화 · 사용자 제어 · 리포트 열람 |
| 🌐 **PWA 시뮬레이터** | [`sourceCode/SPCC-WebApp/`](sourceCode/SPCC-WebApp/) | 하드웨어 없이 시스템 동작 검증 |

각 컴포넌트의 상세 사양 · 빌드 · 실행 방법은 위 폴더 내부의 `README.md` 에서 확인할 수 있다.

---

## 핵심 사양

| 항목 | 값 |
|------|----|
| **센서 수** | 4종 20개 모듈 (HX711×12, VL53L0X×4, VL53L8CX×2, MPU6050×2) |
| **물리 로드셀** | 16개 (좌판 8 + 등판 8) |
| **샘플링 주파수** | 50 Hz (실측 평균 51 Hz, 9 ms / 20 ms 여유 55%) |
| **UART** | 921,600 bps · 129 byte 바이너리 패킷 (XOR 체크섬) |
| **자세 분류** | 8종 (정자세 / 거북목 / 상체 전방 기울기 / 측면 쏠림 / 걸터앉기 / 다리 꼬기 의심 / 뒤로 기대기 / 전방 숙임) |
| **LLM** | Qwen3.5-0.8B (GGUF Q4_K_M, llama-cpp, ~0.6 GB, 평균 20초) |
| **MCU** | STM32F411CEU6 (ARM Cortex-M4 @ 100 MHz) |
| **엣지 디바이스** | Raspberry Pi 5 (16 GB RAM) |
| **모바일 앱** | Flutter (Material 3, Provider) |

---

## 실측 성능

| 항목 | 결과 |
|------|------|
| 30분 연속 측정 패킷 손실률 | **< 0.1%** |
| 평균 루프 주파수 | **51 Hz** (목표 50 Hz 대비) |
| 8종 자세 평균 판별 정확도 | **약 85%** (정자세 · 뒤로 기대기 90% 이상) |
| LLM 리포트 평균 생성 시간 | **약 20초** (RPi5 로컬 추론) |

---

## 빠른 시작

### Raspberry Pi 백엔드 실행

```bash
cd sourceCode/RaspberryPi
pip install -r requirements.txt
python main_real.py                       # 실 하드웨어
POSTURE_UART_MOCK=1 python main_real.py   # Mock STM32
```

### Flutter 앱 실행

```bash
cd sourceCode/flutter_app
flutter pub get
flutter run
```

### STM32 펌웨어

`sourceCode/STM32/SmartChair.ioc` 를 STM32CubeIDE 에서 열어 빌드 후 ST-Link 로 플래시.

### 하드웨어 없이 앱 단독 검증

```bash
pip install aiohttp
python sourceCode/rpisimulator2.py
```

> 자세한 환경 변수 / 빌드 옵션 / 디버깅 방법은 각 컴포넌트 폴더의 README 를 참고한다.

---

## 저장소 구조

```text
Devicemart2026ICT/
│
├── README.md                  ← 본 문서 (전체 개요)
├── .gitignore
│
└── sourceCode/
    ├── STM32/                 ⚙️  센서 노드 펌웨어 (C / HAL)
    ├── RaspberryPi/           🧠 분석 서버 (Python)
    ├── flutter_app/           📱 모바일 클라이언트 (Dart)
    ├── SPCC-WebApp/           🌐 PWA 시뮬레이터
    └── rpisimulator2.py       🧪 가짜 RPi 서버 (앱 단독 테스트용)
```

---

<<<<<<< HEAD
=======
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

`sourceCode/STM32/SmartChair.ioc` 를 **STM32CubeIDE** 에서 열어 빌드 후 ST-Link 로 플래시한다.

### 4. 하드웨어 없이 앱 단독 검증

```bash
pip install aiohttp
python sourceCode/rpisimulator2.py
```

---

## 컴포넌트별 문서

| 컴포넌트 | 문서 |
|----------|------|
| Raspberry Pi 백엔드 | [`sourceCode/RaspberryPi/README.md`](sourceCode/RaspberryPi/README.md) |
| Raspberry Pi 설계 문서 (14종) | [`sourceCode/RaspberryPi/docs/`](sourceCode/RaspberryPi/docs/) |
| Flutter 앱 | [`sourceCode/flutter_app/README.md`](sourceCode/flutter_app/README.md) |
| PWA 시뮬레이터 | [`sourceCode/SPCC-WebApp/README.md`](sourceCode/SPCC-WebApp/README.md) |
| LLM 통합 참고 자료 | [`sourceCode/RaspberryPi/LLM 참고.md`](sourceCode/RaspberryPi/LLM%20참고.md) |

---

## 기술 스택

| 영역 | 사용 기술 |
|------|----------|
| **MCU** | STM32F411CEU6 (WeAct BlackPill V3.1, ARM Cortex-M4 @ 100 MHz) |
| **Embedded** | C, STM32CubeMX, STM32CubeIDE, HAL Driver, VL53L0X / VL53L8CX ULD SDK |
| **Edge Server** | Raspberry Pi 5 (16 GB RAM), Python 3, FastAPI, Uvicorn |
| **Backend Library** | PySerial, NumPy, Pandas, scikit-learn, SQLite |
| **LLM Inference** | Qwen3.5-0.8B (GGUF Q4_K_M), llama-cpp |
| **Mobile** | Flutter (Material 3), Dart, Provider, http, web_socket_channel, shared_preferences |
| **Web** | React (CDN), PWA, vanilla JavaScript |
| **Hardware** | TCA9548A (I2C MUX), HX711 ADC, XL4005 벅 컨버터, KIA 431B 션트 레귤레이터 |
| **Sensors** | HX711 + Loadcell, VL53L0X (1D ToF), VL53L8CX (3D ToF), MPU6050 (IMU), SSD1306 (OLED) |

---

## 개발 단계

| 단계 | 내용 | 상태 |
|------|------|------|
| **Stage 1** | Mock 기반 파이프라인 검증 (UART · 분류 · 리포트 · 앱 연동) | ✅ 완료 |
| **Stage 2** | 실 하드웨어 연동 · 센서 매핑 · feature threshold 보정 | ✅ 완료 |
| **Stage 3** | 통합 검증 (30분 연속 측정 · 정확도 평가 · LLM 리포트 검증) | ✅ 완료 |

---

>>>>>>> b9fef9a1ec33eca55299440a1650046668d488f0
## 공모전 정보

| 항목 | 내용 |
|------|------|
| **공모전명** | 2026 ICT 융합프로젝트 공모전 (디바이스마트 주최) |
| **접수 기간** | 2026.02.01 ~ 2026.03.31 |
| **응모 양식** | A4 10–30매 (DOC / HWP) — 회로도 · 소스코드 · 제작 과정 일체 + 참가신청서 |
| **심사 발표** | 2026년 5월 ~ 6월 중 |
| **공모전 페이지** | [디바이스마트 공모전 게시판](https://www.devicemart.co.kr/board/view?id=award_board&seq=151400) |

---

<p align="center">
  <b>스마트 자세 교정 의자</b> · Smart Posture Correction Chair (SPCC)<br>
  <sub>© 2026 · 디바이스마트 ICT 융합프로젝트 공모전 출품작</sub>
</p>
