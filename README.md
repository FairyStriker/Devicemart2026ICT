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

## 목차

1. [개발 배경](#개발-배경)
2. [작품 개요](#작품-개요)
3. [주요 기능](#주요-기능)
4. [시스템 아키텍처](#시스템-아키텍처)
5. [하드웨어 구성](#하드웨어-구성)
6. [센서 구성](#센서-구성)
7. [감지 가능한 8종 자세](#감지-가능한-8종-자세)
8. [통신 프로토콜](#통신-프로토콜)
9. [LLM 기반 리포트 생성](#llm-기반-리포트-생성)
10. [실측 성능](#실측-성능)
11. [저장소 구조](#저장소-구조)
12. [실행 방법](#실행-방법)
13. [기술 스택](#기술-스택)
14. [공모전 정보](#공모전-정보)
15. [참고문헌](#참고문헌)

---

## 개발 배경

현대 사회에서 데스크 업무나 학습을 위해 의자에 장시간 앉아 있는 경우가 많고, 잘못된 자세는 거북목 증후군, 척추 측만증 등 근골격계 질환을 유발한다. 기존 자세 교정 보조 기구들은 대부분 **물리적인 지지 기능에만 국한**되어 있어, 사용자가 스스로 나쁜 습관을 인지하고 능동적으로 교정하도록 유도하는 데 한계가 있다.

본 작품은 이러한 문제를 해결하기 위해 **센서 네트워크와 엣지 컴퓨팅(Edge Computing)을 결합**하여, 사용자의 자세를 실시간으로 모니터링하고 즉각적인 피드백을 제공하는 **스마트 자세 교정 의자**를 제안한다.

---

## 작품 개요

본 시스템은 의자의 좌판과 등판에 부착된 **20개 모듈 / 24개 물리 센서**로 사용자의 하중 분포와 신체 위치 데이터를 50 Hz 주기로 수집한다. 수집된 데이터는 STM32 센서 노드에서 Raspberry Pi 5로 UART 전송되며, RPi5는 센서 보정 → 특징 추출 → 규칙 기반 자세 판정 → 점수 산출 → 리포트 생성까지의 전 과정을 수행한다.

분석 결과는 **Flutter 모바일 앱**으로 실시간 시각화되며, 측정 종료 후에는 **RPi5에서 로컬 추론되는 Qwen3.5-0.8B LLM**이 사용자별 맞춤형 자연어 분석 리포트를 생성한다. 클라우드 의존 없이 엣지에서 모든 추론이 완료되므로 **개인정보 노출 위험이 없다**.

---

## 주요 기능

| # | 기능 | 설명 |
|---|------|------|
| 1 | **다중 센서 융합** | 로드셀 16개 + 1D ToF 4개 + 3D ToF 2개 + IMU 2개를 50 Hz로 동기 수집 |
| 2 | **8종 자세 자동 분류** | 규칙 기반 판정 로직 + 머신러닝 분류기(확장) 이중 구조 |
| 3 | **개인화 캘리브레이션** | 10초간 500 프레임 평균으로 사용자별 baseline 생성 |
| 4 | **실시간 점수화** | 시간 누적 기반 감점/회복 모델 (1차/2차 경고 단계) |
| 5 | **자리 이탈 감지** | STAND 이벤트 5초 지속 시 자동 일시정지 |
| 6 | **로컬 LLM 리포트** | Qwen3.5-0.8B (Q4_K_M) llama-cpp 기반 온디바이스 추론 |
| 7 | **PWA 시뮬레이터** | 하드웨어 없이 시스템 동작 검증 가능 |
| 8 | **세션 / 일일 누적 분석** | SQLite 기반 분 단위 · 일일 누적 자세 추이 저장 |

---

## 시스템 아키텍처

본 시스템은 **STM32 센서 노드 — Raspberry Pi 5 분석 서버 — Flutter 모바일 앱** 의 3계층 구조로 구성된다.

```text
   ┌──────────────────────────┐    ┌──────────────────────────┐    ┌──────────────────────────┐
   │   STM32F411 Sensor Node  │    │   Raspberry Pi 5 Server  │    │     Flutter Mobile App   │
   │  ──────────────────────  │    │  ──────────────────────  │    │  ──────────────────────  │
   │  · 16 Loadcell (HX711)   │UART│  · Packet Parser         │WiFi│  · Splash / Profile      │
   │  · 4  1D ToF (VL53L0X)   │───▶│  · Sensor Calibration    │───▶│  · Calibration           │
   │  · 2  3D ToF (VL53L8CX)  │ 921k│  · Feature Extraction    │ HTTP│  · Realtime Dashboard    │
   │  · 2  IMU (MPU6050)      │baud│  · Rule-based Posture    │  WS │  · Pressure Heatmap      │
   │  · OLED (SSD1306)        │    │  · Score Calculation     │    │  · LLM Report Viewer     │
   │  · TCA9548A I2C MUX      │    │  · LLM Report (Qwen3.5)  │    │  · Offline History       │
   │  · Power / Battery Mon.  │    │  · SQLite Persistence    │    │  · Provider State Mgmt   │
   └──────────────────────────┘    └──────────────────────────┘    └──────────────────────────┘
        50 Hz 폴링 / 8ms 수집           FastAPI + WebSocket Push          17-stage Auto-Routing
```

| 계층 | 플랫폼 | 역할 | 주요 기술 |
|------|--------|------|-----------|
| **Sensor Node** | STM32F411CEU6 (Cortex-M4) | 50 Hz 센서 폴링 · 패킷 패킹 · UART 전송 | C / HAL / I2C / SPI / Hybrid Blocking |
| **Edge Server** | Raspberry Pi 5 (16 GB RAM) | 자세 분류 · 점수 산출 · LLM 추론 · API 서버 | Python / FastAPI / SQLite / llama-cpp |
| **Client** | Android / Web | 실시간 시각화 · 사용자 제어 · 리포트 열람 | Flutter / Dart / Provider |

---

## 하드웨어 구성

### 의자 부위별 센서 배치

| 부위 | 센서 | 수량 | 용도 |
|------|------|------|------|
| **제어부** | STM32F411CEU6 + RPi5 + TCA9548A | — | MCU · 분석 서버 · I2C 멀티플렉서 |
| **좌판** | 3선식 로드셀 50 kg + HX711 | 8 + 4 | 좌판 4구역 압력 분포 (풀브리지 구성) |
| **등판** | 4선식 막대형 로드셀 20 kg + HX711 | 8 + 8 | 등판 8구역 압력 분포 (1:1) |
| **등판 척추 라인** | VL53L0X (1D ToF) | 4 | 척추 굽힘 거리 |
| **헤드레스트** | VL53L8CX (3D ToF, 4×4) | 2 | 거북목 검출 · 머리 위치 |
| **헤드레스트** | MPU6050 (IMU) | 2 | 의자 / 상체 기울기 |

> **합계 — 4종 20개 모듈** (HX711 ×12 + VL53L0X ×4 + VL53L8CX ×2 + MPU6050 ×2)
> **물리 로드셀 ×16** + **거리 / 자세 센서 ×8** = **24개의 물리 센서**

### STM32 펌웨어 설계 핵심

| 항목 | 설정값 | 비고 |
|------|--------|------|
| 메인 루프 주기 | **20 ms (50 Hz)** | HAL_GetTick 기반 정확한 주기 유지 |
| 3D ToF 모드 | **4×4 (16 zones), 60 Hz** | 8×8 모드는 15 Hz 한계로 미사용 |
| 3D ToF SPI 클럭 | **3.125 MHz** | APB2 100 MHz / Prescaler 32 |
| 1D ToF Timing Budget | **20,000 μs** | 매 20 ms 사이클당 1회 측정 |
| MPU6050 설정 | **±2 g, DLPF 20 Hz, 50 Hz** | 가속도계 기반 pitch 산출 (atan2) |
| HX711 읽기 방식 | **Hybrid Blocking (110 ms 간격)** | 24-bit 비트뱅잉 + `__disable_irq` 보호 |
| HX711 영점 보정 | 500 ms 안정화 + 5회 더미 + 20회 평균 | 채널별 오프셋 저장 |
| UART Baud Rate | **921,600 bps** | 디버그 시 115,200 bps 전환 |
| 패킷 크기 | **129 bytes** | 헤더 + 센서 데이터 128B + XOR 1B |
| **루프 평균 소요 시간** | **약 9 ms / 20 ms (여유 55%)** | 평균 51 Hz 달성 |

### 전원 / 보호 회로

- **벅 컨버터 ↔ MCU 이격 거리 7 cm**: 거리 역제곱 법칙 / dB 감쇄식 / 자기장 세제곱 감쇄 모델을 종합해 도출
- **금속 방열판 접지**: 전계 노이즈 차폐 효율 보강
- **2,200 μF 대용량 콘덴서 + 890 Ω 블리더 저항 + LED**: 출력 리플 제거 및 잔류 전하 시각화 방전
- **션트 레귤레이터 KIA 431B + NPN C1384**: 배터리 저전압 부저 알림 시스템 (가변저항으로 임계값 / 음량 조절)

---

## 센서 구성

### 로드셀 (HX711 12채널)

| Index | 위치 |
|-------|------|
| 0–7 | 등판 좌·우 × 상·중상·중하·하 (8구역) |
| 8 | 좌판 후방 우 |
| 9 | 좌판 전방 우 |
| 10 | 좌판 후방 좌 |
| 11 | 좌판 전방 좌 |

### 거리 / 자세 센서

| Index | 센서 | 위치 |
|-------|------|------|
| 12, 13 | VL53L8CX (3D ToF) | 헤드레스트 좌 / 우 (10 cm 간격) |
| 14–17 | VL53L0X (1D ToF) | 등판 척추 라인 (상→하) |
| 18 | MPU6050 (IMU) | 의자 기울기 측정 |

### 자세 분석 특징(Feature)

| Feature | 의미 |
|---------|------|
| `back_lr_diff` | 등받이 좌우 압력 차이 |
| `seat_fb_shift` | 좌판 전후 하중 이동량 |
| `seat_lr_diff` | 좌판 좌우 균형 |
| `neck_mean` | 목 위치 평균 거리 (3D ToF) |
| `neck_forward_delta` | 목 전방 이동량 |
| `spine_curve` | 척추 곡률 (1D ToF 기반) |
| `imu_pitch_avg` / `imu_lr_diff` | 상체 기울기 평균 / 좌우 차이 |

---

## 감지 가능한 8종 자세

| 코드 | 한글명 | 설명 |
|------|--------|------|
| `normal` | **정자세** | 올바른 착석 자세 (점수 회복) |
| `turtle_neck` | **거북목** | 목이 앞으로 돌출된 자세 |
| `forward_lean` | **상체 전방 기울기** | 상체가 앞으로 기울어진 자세 |
| `reclined` | **뒤로 기대기** | 상체가 뒤로 기댄 자세 |
| `side_slouch` | **측면 쏠림** | 좌우 하중이 비대칭인 자세 |
| `leg_cross_suspect` | **다리 꼬기 의심** | 좌석 압력 비대칭 패턴 |
| `perching` | **걸터앉기** | 의자 앞쪽에만 체중 분포 |
| `slouched` | **전방 숙임** | 상체가 깊이 굽혀진 자세 |

> 각 자세의 임계값은 **5명의 피험자**를 대상으로 8종 자세를 30초씩 유지하도록 한 사전 실험에서 수집된 특징값 분포를 분석하여 도출하였다.

### 자세 점수화 모델

```text
S(t)   = S(t-1) - α(p) × Δt              (나쁜 자세 지속 시 감점)
S(t+T) = S(t) - β(p)                     (자세 임계 지속 시간 T 초과 시 1차 경고)
S(t)   = S(t) - γₖ(p)                    (k차 재경고)
S(t)   = S(t-1) + ρ × Δt                 (정자세 유지 시 회복)
```

α: 자세별 초당 감점 / β: 1차 경고 추가 감점 / γₖ: 재경고 단계별 감점 / ρ: 정자세 회복 계수

---

## 통신 프로토콜

### STM32 ↔ Raspberry Pi (UART, 921,600 bps)

#### ASCII Control Mode

| 방향 | 메시지 | 의미 |
|------|--------|------|
| STM32 → RPi | `READY` / `LINK_OK` | 부팅 완료 / 링크 확립 |
| RPi → STM32 | `ACK` | READY 응답 |
| RPi → STM32 | `CHK_SIT` | 착석 확인 요청 |
| STM32 → RPi | `SIT` / `STAND` | 착석 응답 / 5초 이상 이탈 |
| RPi → STM32 | `CAL` / `GO` / `STOP` | 캘리브레이션 / 측정 시작 / 중단 |
| STM32 → RPi | `CAL_DONE` | 캘리브레이션 완료 |

#### Binary Sensor Stream — 129 bytes

```text
┌────────────┬──────────────┬──────────────┬─────────────┬───────────┬────────────┐
│ Header 4B  │ Loadcell 48B │ Spine ToF 8B │ 3D ToF 64B  │ IMU 4B    │ Checksum 1B│
│ "DAT:/CAL:"│ 12 × int32   │ 4 × uint16   │ 32 × uint16 │ 2 × int16 │ XOR (1B)   │
└────────────┴──────────────┴──────────────┴─────────────┴───────────┴────────────┘
                                  Total = 129 bytes @ 50 Hz
```

> **무결성**: 128 바이트 센서 데이터에 대한 XOR 체크섬 1 바이트로 패킷 손상 검출
> 30분 이상 연속 측정 3회 검증 결과 **패킷 손실률 < 0.1%**

### Raspberry Pi ↔ Flutter App (HTTP / WebSocket)

| 종류 | 경로 | 용도 |
|------|------|------|
| HTTP `GET` | `/health`, `/meta` | 헬스 체크 · 시스템 상태 조회 |
| HTTP `POST` | `/command` | 명령 전송 (JSON ack 반환) |
| WebSocket | `/ws` | 실시간 push payload |

#### WebSocket Payload (7종)

| Type | 주기 | 용도 |
|------|------|------|
| `meta` | stage 변경 시 | 화면 자동 라우팅 기준 |
| `realtime_status` | 50 Hz | 자세 판정 + 집계 점수 |
| `sensor_distribution` | ~5 Hz | 17개 센서 시각화 데이터 |
| `stand_event` | 이벤트 | 자리 이탈 알림 |
| `minute_summary` | 1분마다 | 분 단위 누적 리포트 |
| `overall_summary` | 세션 종료 | 전체 결과 요약 |
| `enhanced_report` | 세션 종료 | LLM 분석 리포트 |

### 모바일 앱 — 17 Stage 자동 라우팅

앱의 화면 전환은 **사용자 버튼 입력이 아닌 RPi5 서버의 stage 변화에 의해 결정**된다. 사용자는 명령만 전송하고, 서버가 stage를 갱신해 WebSocket으로 통보하면 앱의 라우터가 즉시 대응 화면을 표시한다. 이 구조로 통신 지연이나 명령 처리 실패 시에도 앱과 서버 상태가 항상 동기화된다.

---

## LLM 기반 리포트 생성

세션 종료 시점에 RPi5는 **로컬 LLM 추론**을 수행하여 사용자에게 자연어 분석 리포트를 제공한다.

| 항목 | 설정 |
|------|------|
| **모델** | Qwen3.5-0.8B (8억 파라미터) |
| **양자화** | GGUF Q4_K_M |
| **런타임** | llama-cpp |
| **메모리 점유** | 약 0.6 GB (RPi5 16 GB RAM 환경에서 분석 서버와 동시 구동 가능) |
| **추론 시간** | 평균 약 20초 (15–25초) |
| **언어** | 한국어 (동급 경량 모델 대비 우수) |
| **Fallback** | 추론 실패 시 규칙 기반 대체 리포트 자동 생성 |

### 리포트 구성 요소

1. **전체 자세 상태 요약** — 평균 점수 / 대표 자세 / 양호 비율 등 정량 지표
2. **시간 흐름 기반 변화 분석** — 분 단위 추이로 본 자세 변화 패턴
3. **맞춤형 운동 추천** — 감지된 자세 문제에 대응하는 스트레칭 / 근력 운동
4. **생활 습관 개선 조언** — 작업 환경 / 휴식 주기 등 행동 변화 제안

> ☁️ **클라우드 의존 없음** — 모든 추론이 RPi5 내부에서 완료되므로 사용자 데이터가 외부로 전송되지 않는다.

---

## 실측 성능

본 시스템은 다음 3개 항목으로 통합 검증을 수행하였다.

| 항목 | 측정 방법 | 결과 |
|------|----------|------|
| **하드웨어 안정성** | 30분 이상 연속 측정 세션 × 3회 | UART 패킷 손실률 **< 0.1%** |
| **루프 주기 안정성** | OLED 기반 실시간 모니터링 | 평균 **51 Hz** (목표 50 Hz, 여유 55%) |
| **자세 판별 정확도** | 5명 피험자 × 8종 자세 × 30초 | 전체 평균 **약 85%** |
| **LLM 리포트 품질** | 다양한 세션에 대한 리포트 생성 | 평균 **약 20초**, 구조화된 피드백 안정 생성 |

### 자세별 정확도

| 자세 | 정확도 |
|------|--------|
| 정자세 / 뒤로 기대기 | **90% 이상** |
| 거북목 / 상체 전방 기울기 / 측면 쏠림 | 양호 |
| 다리 꼬기 의심 / 걸터앉기 | 상대적으로 낮음 (향후 ML 도입 예정) |

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
    │   │   ├── runtime/            # 50 Hz 측정 루프
    │   │   ├── app_flow/           # 상위 흐름 제어 (17 stage)
    │   │   ├── report/             # 리포트 생성 · LLM 연동
    │   │   ├── llm/                # Qwen3.5-0.8B 서비스
    │   │   ├── storage/            # SQLite · CSV 로거
    │   │   ├── feedback/           # 부저 피드백
    │   │   └── config/             # 환경 변수 설정
    │   ├── models/                 # ML 데이터셋 / 학습 스크립트
    │   ├── saved_models/           # 학습 완료 RandomForest 모델
    │   ├── tools/                  # fake_stm32 / fake_app / 패킷 스니퍼
    │   ├── profiles/               # 사용자 프로필 JSON
    │   ├── data/                   # 수집 raw / processed 데이터
    │   └── docs/                   # 14종 설계 문서
    │
    ├── STM32/                 # ⚙️  센서 노드 펌웨어 (C / HAL)
    │   ├── SmartChair.ioc          # CubeMX 프로젝트
    │   ├── Core/
    │   │   ├── Inc/ Src/           # main · IT · SSD1306 OLED
    │   │   ├── VL53L0X_API(1D)/    # 1D ToF ST 라이브러리
    │   │   └── VL53L8CX_API(3D)/   # 3D ToF ST ULD 라이브러리
    │   └── Drivers/                # CMSIS · STM32F4 HAL
    │
    ├── flutter_app/           # 📱 모바일 클라이언트 (Dart)
    │   ├── lib/
    │   │   ├── main.dart           # 진입점 · stage 라우팅
    │   │   ├── models/             # payload 데이터 모델 5종
    │   │   ├── services/           # api · websocket · 보고서 저장
    │   │   ├── providers/          # 전역 상태 (Provider)
    │   │   ├── widgets/            # 좌석 압력 시각화
    │   │   └── screens/            # 6종 화면 (Splash → ReportHistory)
    │   └── android/                # Android 빌드 설정
    │
    ├── SPCC-WebApp/           # 🌐 PWA 시뮬레이터
    │   ├── index.html              # React 단일 파일 시뮬레이터
    │   └── manifest.json           # PWA 매니페스트
    │
    └── rpisimulator2.py       # 🧪 가짜 RPi 서버 (앱 단독 테스트용)
```

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
| **Future** | ML 분류기 도입 (다리 꼬기 / 걸터앉기 정확도 향상) · 모델 경량화 | 📅 예정 |

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

## 참고문헌

1. STMicroelectronics, *STM32F411xC/xE — ARM Cortex-M4 32-bit MCU*, Datasheet (DS10314).
2. Raspberry Pi Foundation, *Raspberry Pi 5 Documentation*.
3. Google, *Flutter Documentation*.
4. STMicroelectronics, *STM32CubeIDE — Integrated Development Environment for STM32*.
5. STMicroelectronics, *STM32CubeMX — STM32 configuration and code generation tool*.
6. Google, *Dart Programming Language Documentation*.
7. WeAct Studio, *WeAct STM32F411CEU6 (BlackPill V3.1)*.
8. STMicroelectronics, *STM32F411xC/xE Reference Manual* (RM0383).
9. Texas Instruments, *TCA9548A — Low-Voltage 8-Channel I2C Switch with Reset*, Datasheet (SCPS207H).
10. AVIA Semiconductor, *HX711 — 24-Bit Analog-to-Digital Converter for Weigh Scales*, Datasheet.
11. STMicroelectronics, *VL53L0X — Time-of-Flight ranging sensor*, Datasheet (DS11555).
12. InvenSense (TDK), *MPU-6000 / MPU-6050 Product Specification*, Rev. 3.4.
13. STMicroelectronics, *VL53L8CX — Time-of-Flight 8×8 multizone ranging sensor*, Datasheet (DS14161).
14. STMicroelectronics, *SATEL-VL53L8 — Breakout board for VL53L8CX*.
15. STMicroelectronics, *VL53L8CX Ultra Lite Driver (ULD) User Manual* (UM3109).
16. STMicroelectronics, *VL53L0X API User Manual* (UM2039).
17. Qwen Team, Alibaba Cloud, *Qwen3.5 — GitHub Repository*.
18. Hugging Face, *Qwen/Qwen3.5-0.8B Model Card*.
19. Qwen Team, Alibaba Cloud, *Qwen3.5 Research*.
20. Remi Rousselet, *provider — A wrapper around InheritedWidget*, Pub.dev.
21. Dart Team, *http — A composable, Future-based library for making HTTP requests*, Pub.dev.
22. Flutter Team, *shared_preferences — Wraps platform-specific persistent storage*, Pub.dev.

---

<p align="center">
  <b>스마트 자세 교정 의자</b> · Smart Posture Correction Chair (SPCC)<br>
  <sub>© 2026 · 디바이스마트 ICT 융합프로젝트 공모전 출품작</sub>
</p>
