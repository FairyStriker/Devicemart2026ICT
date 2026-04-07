# Raspberry Pi 5 Backend

> **스마트 자세 교정 의자** 의 분석 서버
> STM32 센서 노드로부터 50 Hz 바이너리 패킷을 수신하여 자세를 분석하고, 로컬 LLM 으로 자연어 리포트를 생성한다.

<p align="center">
  <img alt="Edge" src="https://img.shields.io/badge/Edge-Raspberry%20Pi%205-C51A4A">
  <img alt="Python" src="https://img.shields.io/badge/Python-3.x-3776AB">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-FastAPI-009688">
  <img alt="LLM" src="https://img.shields.io/badge/LLM-Qwen3.5--0.8B-purple">
  <img alt="Inference" src="https://img.shields.io/badge/Inference-llama--cpp-orange">
  <img alt="Storage" src="https://img.shields.io/badge/DB-SQLite-003B57">
</p>

---

## 목차

1. [개요](#개요)
2. [시스템 위치](#시스템-위치)
3. [디렉토리 구조](#디렉토리-구조)
4. [실행 방법](#실행-방법)
5. [환경 변수](#환경-변수)
6. [데이터 처리 파이프라인](#데이터-처리-파이프라인)
7. [센서 보정](#센서-보정)
8. [특징 추출](#특징-추출)
9. [자세 판단](#자세-판단)
10. [자세 점수 계산](#자세-점수-계산)
11. [LLM 리포트 생성](#llm-리포트-생성)
12. [세션 관리 및 데이터 저장](#세션-관리-및-데이터-저장)
13. [UART 프로토콜](#uart-프로토콜)
14. [앱 통신 API](#앱-통신-api)
15. [개발 도구](#개발-도구)
16. [상세 문서](#상세-문서)

---

## 개요

본 모듈은 스마트 자세 교정 의자 시스템의 **핵심 분석 엔진**으로, Raspberry Pi 5 (16 GB RAM) 상에서 다음 7개 계층을 수행한다.

1. **UART 통신 계층** — STM32로부터 129 byte 바이너리 패킷 수신 / 체크섬 검증
2. **센서 보정 계층** — 로드셀 질량 환산 · ToF EMA 안정화
3. **특징 추출 계층** — 8종 자세 feature 계산
4. **자세 판단 / 점수 계산 계층** — 규칙 기반 판정 + 시간 누적 점수
5. **세션 관리 계층** — 사용자 프로필 · 캘리브레이션 · 측정 세션 상태
6. **앱 통신 계층** — FastAPI HTTP + WebSocket
7. **리포트 생성 계층** — Qwen3.5-0.8B 로컬 LLM + 규칙 기반 fallback

---

## 시스템 위치

```text
   ┌────────────────┐    ┌──────────────────┐    ┌────────────────┐
   │  STM32F411     │UART│  Raspberry Pi 5  │WiFi│  Flutter App   │
   │  센서 노드     │───▶│  ★ 본 모듈 ★    │───▶│  모바일 앱     │
   │  50 Hz 수집    │921k│  분석 + LLM      │HTTP│  시각화 / 제어 │
   └────────────────┘    └──────────────────┘    └────────────────┘
```

---

## 디렉토리 구조

```text
RaspberryPi/
├── main_real.py                  # 실 RPi 런타임 진입점
├── main_compare.py               # ML vs Rule-based 분류기 비교 테스트
├── requirements.txt              # Python 의존성
│
├── src/
│   ├── communication/            # 통신 레이어
│   │   ├── uart_protocol.py          # STM32 ↔ RPi UART 프로토콜 정의
│   │   ├── uart_handshake.py         # UART 3-way 핸드셰이크
│   │   ├── command_sender.py         # RPi → STM32 제어 명령 전송
│   │   ├── wifi_server.py            # HTTP / WebSocket 서버 (FastAPI)
│   │   ├── app_command_handler.py    # 앱 command 해석 및 stage 유효성 검사
│   │   ├── app_payload_builder.py    # 앱 전달용 JSON payload 생성
│   │   ├── session_state.py          # 런타임 stage 상수 정의
│   │   ├── ble_gatt_server.py        # BLE GATT 서버 (예비)
│   │   ├── ble_sender.py             # BLE 전송 (예비)
│   │   └── ble_constants.py          # BLE 상수 정의
│   │
│   ├── sensor/                   # 센서 데이터 수신 및 파싱
│   │   ├── sensor_receiver.py        # UART 데이터 수신 / 이벤트 복원
│   │   ├── packet_parser.py          # 129-byte 바이너리 패킷 파싱
│   │   └── sensor_mapper.py          # raw → semantic 구조 매핑
│   │
│   ├── core/                     # 자세 분석 핵심 로직
│   │   ├── feature_extractor.py      # semantic packet → 자세 feature 추출
│   │   ├── posture_classifier.py     # ML 기반 자세 분류 (RandomForest)
│   │   ├── rule_based_classifier.py  # 규칙 기반 자세 분류
│   │   ├── posture_flags.py          # 규칙 기반 자세 이상 플래그 판정
│   │   ├── posture_score.py          # 자세 점수 · 경고 단계 산출
│   │   ├── posture_mapper.py         # 자세 label → 한글 표시 변환
│   │   ├── posture_types.py          # 자세 타입 상수
│   │   ├── posture_logic.py          # 자세 판별 보조 로직
│   │   ├── monitoring_metrics.py     # baseline 대비 안정도 지표 계산
│   │   └── sensor_factor.py          # 센서 보정 팩터 적용
│   │
│   ├── session/                  # 세션 · 프로필 · 캘리브레이션
│   │   ├── session_manager.py        # 런타임 세션 상태 관리
│   │   ├── profile_manager.py        # 사용자 프로필 JSON 관리
│   │   └── calibration.py            # 캘리브레이션 데이터 수집 및 baseline 계산
│   │
│   ├── runtime/                  # 실시간 측정 루프
│   │   └── measurement_runtime.py    # 50Hz DAT 수신 → 분석 → 브로드캐스트 루프
│   │
│   ├── app_flow/                 # 상위 흐름 제어
│   │   ├── app_flow_controller.py    # 앱 command 대기 / 분기 제어
│   │   ├── calibration_flow.py       # 캘리브레이션 플로우 실행
│   │   └── sit_detector.py           # 착석 확인 (CHK_SIT → SIT)
│   │
│   ├── report/                   # 리포트 생성
│   │   ├── report_generator.py       # 세션/분 단위 리포트 생성
│   │   ├── report_service.py         # 리포트 서비스 통합
│   │   ├── report_enhancer.py        # Rule-based 해석형 리포트 생성
│   │   ├── report_schema.py          # 리포트 데이터 구조 정의
│   │   ├── llm_report_engine.py      # LLM 리포트 엔진 (Qwen3.5-0.8B)
│   │   └── posture_display.py        # 자세 표시 유틸리티
│   │
│   ├── llm/                      # LLM 연동
│   │   └── report_llm_service.py     # llama-cpp 추론 서비스
│   │
│   ├── storage/                  # 데이터 저장
│   │   ├── database_manager.py       # SQLite DB 접근 (세션/리포트/사용자)
│   │   └── sample_logger.py          # 실시간 샘플 CSV 로깅
│   │
│   ├── feedback/                 # 피드백 출력
│   │   ├── buzzer_feedback.py        # 자세 이상 시 부저 피드백
│   │   └── test_buzzer.py            # 부저 테스트
│   │
│   └── config/
│       └── settings.py               # 환경 변수 기반 전역 설정
│
├── models/                       # ML 모델
│   ├── train_sklearn.py              # RandomForest 학습 스크립트
│   └── generate_dataset.py           # 학습용 데이터셋 생성
│
├── saved_models/
│   └── posture_rf.pkl                # 학습된 RandomForest 모델
│
├── tools/                        # 개발/디버깅 도구
│   ├── fake_stm32.py                 # 가상 STM32 시뮬레이터
│   ├── fake_app.py                   # 가상 앱 클라이언트
│   └── uart_packet_sniffer.py        # UART 패킷 스니퍼
│
├── profiles/                     # 사용자 프로필 JSON 저장소
├── data/                         # 수집 데이터 저장소
│
└── docs/                         # 14종 설계 문서
```

---

## 실행 방법

### 의존성 설치

```bash
pip install -r requirements.txt
```

주요 패키지: `fastapi`, `uvicorn`, `pyserial`, `numpy`, `pandas`, `scikit-learn`, `joblib`, `llama-cpp-python`

### 실행

```bash
# 실 RPi 환경 (STM32 연결)
python main_real.py

# Mock STM32 로 단독 테스트 (하드웨어 불필요)
POSTURE_UART_MOCK=1 python main_real.py
```

서버 시작 시 다음이 자동 동작한다.

1. UART Handshake (`READY` → `ACK` → `LINK_OK`)
2. WiFi Server 시작 (FastAPI + WebSocket on `:8000`)
3. 앱 연결 대기

---

## 환경 변수

| 환경 변수 | 기본값 | 설명 |
|-----------|--------|------|
| `POSTURE_UART_PORT` | `/dev/ttyAMA3` | UART 포트 |
| `POSTURE_UART_BAUD` | `921600` | UART Baud Rate |
| `POSTURE_UART_MOCK` | `0` | Mock 모드 (`1`이면 가상 STM32 사용) |
| `POSTURE_SAMPLE_RATE_HZ` | `50` | 센서 샘플링 주파수 |
| `POSTURE_CALIBRATION_SEC` | `10` | 캘리브레이션 지속 시간(초) |
| `POSTURE_REPORT_ENGINE` | `rule` | 리포트 엔진 (`rule` / `llm`) |
| `POSTURE_LLM_MODEL_PATH` | — | GGUF 모델 파일 경로 (LLM 모드) |
| `POSTURE_BUZZER_ENABLE` | `0` | 부저 피드백 활성화 |
| `POSTURE_DEBUG_SENSOR` | `0` | 센서 요약 디버그 출력 |
| `POSTURE_DEBUG_FEATURES` | `0` | Feature 디버그 출력 |
| `POSTURE_DEBUG_FLAGS` | `0` | Flag 디버그 출력 |
| `POSTURE_ENABLE_SAMPLE_LOGGER` | `1` | CSV 샘플 로거 활성화 |

---

## 데이터 처리 파이프라인

```text
DAT Packet (50 Hz)
   │
   ├─▶ packet_parser       (struct.unpack, XOR 체크섬 검증)
   ├─▶ sensor_mapper       (raw → semantic 구조 매핑)
   ├─▶ feature_extractor   (8개 자세 feature 계산)
   ├─▶ posture_classifier  (Rule-based 판정 + ML 예측)
   ├─▶ posture_flags       (복합 자세 이상 플래그 판정)
   ├─▶ posture_score       (시간 누적 점수 / 경고 단계)
   ├─▶ report_generator    (분 단위 / 세션 누적 리포트)
   └─▶ wifi_server         (WebSocket 브로드캐스트)
```

---

## 센서 보정

### 로드셀 질량 환산

각 로드셀 채널은 **단위 질량당 계수 × 잡음 임계값** 처리로 킬로그램 단위 하중값으로 변환된다.

```text
        ⎧ 0                            (|raw_i × k_i| < ε)
w_i  =  ⎨
        ⎩ raw_i × k_i                  (그 외)
```

| 기호 | 의미 |
|------|------|
| `raw_i` | STM32 가 영점 보정한 i 번째 로드셀 채널 |
| `k_i` | 채널별 단위 질량당 계수 (사전 실험 도출) |
| `ε` | 잡음 제거 임계값 |
| `w_i` | 변환된 하중값 (kg) |

### ToF 거리 안정화 (EMA)

ToF 데이터는 단순 계수 보정보다 **측정 안정화**에 중점을 두어 다음 3단계로 처리한다.

**1단계 — 유효 거리 범위 검사**

```text
              ⎧ INVALID                       (d < d_min ∨ d > d_max)
d_filtered = ⎨
              ⎩ d                              (그 외)
```

**2단계 — 급격한 변화 억제**

```text
              ⎧ d_prev                        (|d - d_prev| > Δmax)
d_jumpcut  = ⎨
              ⎩ d                              (그 외)
```

**3단계 — 지수 이동 평균 (EMA)**

```text
d_smooth(t) = α × d_jumpcut + (1 - α) × d_smooth(t-1)
```

이 과정을 통해 센서 간 편차와 순간 잡음을 효과적으로 억제한다.

---

## 특징 추출

보정된 센서 데이터는 다음 8개 핵심 feature 로 변환된다.

| Feature | 데이터 출처 | 의미 |
|---------|------------|------|
| `back_lr_diff` | 등판 로드셀 (좌/우) | 등받이 좌우 압력 차이 |
| `seat_fb_shift` | 좌판 로드셀 (전/후) | 좌판 전후 하중 이동량 |
| `seat_lr_diff` | 좌판 로드셀 (좌/우) | 좌석 좌우 균형 |
| `neck_mean` | 3D ToF 평균 | 목 위치 평균 거리 |
| `neck_forward_delta` | 3D ToF 변화량 | 목 전방 이동 정도 |
| `spine_curve` | 1D ToF (4채널) | 척추 곡률 (등받이 거리 변화) |
| `imu_pitch_avg` | MPU6050 평균 | 상체 기울기 평균 |
| `imu_lr_diff` | MPU6050 좌/우 차이 | 상체 좌우 기울기 비대칭 |

---

## 자세 판단

추출된 feature 는 **기준 자세(baseline) 대비 변화량**과 함께 규칙 기반 판단 로직에 입력되어 다음 8종 자세로 분류된다.

| 코드 | 한글명 | 판단 핵심 |
|------|--------|----------|
| `normal` | 정자세 | 모든 feature 가 정상 범위 |
| `turtle_neck` | 거북목 | `neck_forward_delta` 임계값 초과 |
| `forward_lean` | 상체 전방 기울기 | `imu_pitch_avg` 양의 방향 임계값 초과 |
| `reclined` | 뒤로 기대기 | `imu_pitch_avg` 음의 방향 임계값 초과 |
| `side_slouch` | 측면 쏠림 | `back_lr_diff` 또는 `imu_lr_diff` 임계값 초과 |
| `leg_cross_suspect` | 다리 꼬기 의심 | `seat_lr_diff` 패턴 비대칭 |
| `perching` | 걸터앉기 | `seat_fb_shift` 전방 편향 |
| `slouched` | 전방 숙임 | `spine_curve` 변화 + `back_lr_diff` 종합 |

### 임계값 산출

각 자세의 임계값은 **5명의 피험자**를 대상으로 8종 자세를 30초씩 유지한 사전 실험에서 수집된 feature 분포를 분석하여 도출하였다.

### 머신러닝 분류기 (확장)

`posture_classifier.py` 는 scikit-learn RandomForest 기반 ML 분류 구조를 포함한다. 현재 구현 단계에서는 **규칙 기반 판단**이 최종 결정의 핵심 역할을 수행하며, ML 분류기는 향후 데이터 축적 후 전환을 위한 확장 슬롯으로 동작한다.

---

## 자세 점수 계산

자세 점수는 **시간 누적 기반 감점/회복 모델**로 계산된다.

### (1) 연속 감점 (나쁜 자세 지속)

```text
S(t) = S(t-1) − α(p) × Δt
```

`α(p)`: 자세 `p` 에 대한 초당 감점 계수, `Δt`: 샘플 간 시간 간격

### (2) 1차 경고 (임계 지속 시간 초과)

```text
S(t + T) = S(t) − β(p)
```

자세 `p` 가 임계 지속 시간 `T` 이상 유지되면 추가 패널티 `β(p)` 부여.

### (3) k차 재경고

```text
S(t) = S(t) − γ_k(p)
```

동일 자세가 계속 유지되면 단계별 추가 감점 `γ_k(p)` 반복 부여.

### (4) 정자세 회복

```text
S(t) = S(t-1) + ρ × Δt
```

정자세 유지 시 초당 회복 계수 `ρ` 만큼 점수 회복.

이 모델을 통해 사용자의 자세 유지 습관을 정량적으로 평가하고 나쁜 자세의 누적 영향을 점수에 반영한다.

---

## LLM 리포트 생성

세션 종료 시점에 RPi5 는 **로컬 LLM 추론**을 수행하여 사용자 맞춤형 자연어 리포트를 생성한다.

### 모델 사양

| 항목 | 설정 |
|------|------|
| **모델** | Qwen3.5-0.8B (8억 파라미터) |
| **양자화** | GGUF Q4_K_M |
| **런타임** | llama-cpp |
| **메모리 점유** | 약 0.6 GB |
| **추론 시간** | 평균 약 20초 (15–25초) |
| **언어** | 한국어 (동급 경량 모델 대비 우수) |

### 선정 근거

1. **메모리 효율성** — 0.8B / Q4_K_M 양자화로 약 0.6 GB 만 점유, RPi5 16 GB RAM 환경에서 분석 서버와 동시 구동 가능
2. **한국어 품질** — 동급 경량 모델 대비 자연스러운 한국어 생성 가능
3. **응답 시간** — RPi5 llama-cpp 기반 추론 시 15–25초 내 완료, 사용자 대기 허용 범위

### 리포트 구성

LLM 입력은 **전체 세션 요약 + 분 단위 시간 흐름**으로 구성되며, 출력은 다음 구조화된 리포트를 포함한다.

1. **전체 자세 상태 요약**
2. **시간 흐름 기반 자세 변화 분석**
3. **맞춤형 운동 추천**
4. **생활 습관 개선 조언**

### Fallback 전략

추론 실패 시에도 동일한 출력 구조를 유지하기 위해 **규칙 기반 대체 리포트** 경로를 함께 구성하여 시스템 안정성을 확보하였다. (`report_enhancer.py`)

---

## 세션 관리 및 데이터 저장

### 세션 단위

하나의 세션은 사용자가 착석하여 측정을 시작한 시점부터 종료 시점까지의 데이터를 포함하며, 다음 지표를 생성한다.

| 지표 | 설명 |
|------|------|
| `avg_score` | 평균 자세 점수 |
| `total_sitting_sec` | 총 착석 시간 |
| `dominant_posture` | 가장 빈번한 자세 |
| `dominant_posture_ratio` | 대표 자세 비율 (%) |
| `good_posture_ratio` | 정상 자세 비율 (%) |
| `bad_posture_ratio` | 비정상 자세 비율 (%) |
| `posture_duration_sec` | 자세별 누적 시간 |

### SQLite 스키마 (`posture_system.db`)

| 테이블 | 설명 |
|--------|------|
| `users` | 사용자 프로필 (ID, 이름, 키, 체중, 작업/휴식 시간) |
| `baselines` | 캘리브레이션 기준값 |
| `sessions` | 측정 세션 기록 |
| `minute_reports` | 분 단위 자세 리포트 |
| `daily_reports` | 일일 누적 리포트 |

### 사용자 프로필 (`profiles/*.json`)

JSON 파일로 사용자별 프로필과 baseline 데이터를 저장한다.

### CSV 샘플 로그 (`data/`)

측정 중 raw / semantic / feature / flag 데이터를 CSV 로 기록하여 후속 모델 재학습에 활용한다.

---

## UART 프로토콜

STM32 와 RPi 간 통신은 두 가지 모드로 동작한다.

### ASCII Control Mode

| 방향 | 메시지 | 설명 |
|------|--------|------|
| STM32 → RPi | `READY` | 부팅 완료 |
| RPi → STM32 | `ACK` | READY 응답 |
| STM32 → RPi | `LINK_OK` | 핸드셰이크 완료 |
| RPi → STM32 | `CHK_SIT` | 착석 확인 요청 |
| STM32 → RPi | `SIT` | 착석 응답 |
| RPi → STM32 | `CAL` | 캘리브레이션 시작 |
| STM32 → RPi | `GO` | 측정 시작 |
| RPi → STM32 | `STOP` | 측정 중단 |
| STM32 → RPi | `STAND` | 자리 이탈 5초 지속 |
| STM32 → RPi | `CAL_DONE` | 캘리브레이션 완료 |

### Binary Sensor Stream

129 byte 고정 길이 패킷, 50 Hz 전송, XOR 체크섬 검증.

```text
[Header 4B] [Loadcell 48B] [Spine ToF 8B] [3D ToF 64B] [IMU 4B] [Checksum 1B]
 DAT:/CAL:   12 × int32     4 × uint16     32 × uint16   2 × int16  XOR
```

> 상세 내용은 [`docs/uart_protocol.md`](docs/uart_protocol.md) 참고.

---

## 앱 통신 API

### HTTP Endpoints

| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/health` | 서버 상태 확인 |
| `GET` | `/meta` | 현재 시스템 stage / 사용자 정보 |
| `POST` | `/command` | 앱 → RPi 명령 전달 (JSON ack 반환) |

### WebSocket

```
ws://<raspberry_pi_ip>:8000/ws
```

Push payload 7종: `meta`, `realtime_status`, `sensor_distribution`, `minute_summary`, `overall_summary`, `stand_event`, `enhanced_report`

### 주요 Command

| Command | 허용 Stage | 설명 |
|---------|-----------|------|
| `submit_profile` | `uart_link_ready` | 신규 프로필 등록 |
| `select_profile` | `uart_link_ready` | 기존 프로필 선택 |
| `start_calibration` | `wait_calibration_decision` | 캘리브레이션 시작 |
| `skip_calibration` | `wait_calibration_decision` | 캘리브레이션 생략 |
| `start_measurement` | `wait_start_decision` | 측정 시작 |
| `pause_measurement` | `measuring` | 측정 일시정지 |
| `resume_measurement` | `paused` | 측정 재개 |
| `quit_measurement` | `measuring` / `paused` / `wait_restart_decision` | 세션 종료 |
| `resume_after_stand` | `wait_restart_decision` | STAND 후 재측정 |
| `decline_resume_after_stand` | `wait_restart_decision` | STAND 후 종료 |
| `request_recalibration` | `wait_calibration_decision` / `paused` | 재캘리브레이션 |

### 런타임 동작 흐름

```text
RPi 부팅
  │
  ├─ UART Handshake (READY → ACK → LINK_OK)
  ├─ WiFi Server 시작 (FastAPI + WebSocket)
  ├─ 앱에서 프로필 선택/등록
  ├─ 캘리브레이션 수행 여부 결정
  │   ├─ 캘리브레이션 실행 (CHK_SIT → SIT → CAL → CAL stream → baseline 계산)
  │   └─ 캘리브레이션 생략 (기존 baseline 사용)
  ├─ 측정 시작 (CHK_SIT → SIT → GO → DAT stream)
  │
  └─ 실시간 측정 루프 (50 Hz)
      ├─ DAT 패킷 수신 및 파싱
      ├─ semantic mapping
      ├─ feature 추출
      ├─ 자세 분류 (Rule + ML)
      ├─ 자세 플래그 판정
      ├─ 점수 산출 및 경고 단계 계산
      ├─ realtime_status WebSocket 브로드캐스트
      ├─ 분 단위 리포트 누적
      │
      ├─ [STAND 이벤트] → 앱에 stand_event 전달 → 재측정/종료 선택
      ├─ [일시정지] → STOP → resume / quit / recalibration 대기
      └─ [세션 종료] → 리포트 생성 → DB 저장
```

---

## 개발 도구

### `tools/fake_stm32.py`

실제 STM32 없이 전체 시스템을 테스트하기 위한 가상 센서 노드. UART 핸드셰이크, CAL/DAT 스트림, STAND 이벤트를 시뮬레이션한다.

```bash
POSTURE_UART_MOCK=1 python main_real.py
```

### `tools/fake_app.py`

가상 앱 클라이언트. HTTP / WebSocket 으로 RPi 서버에 command 를 전송하고 payload 를 수신한다.

### `tools/uart_packet_sniffer.py`

UART raw 패킷을 직접 수신하여 체크섬 검증 및 센서값을 출력하는 디버깅 도구.

### `main_compare.py`

ML 분류기와 Rule-based 분류기의 예측 결과를 자세별로 비교하는 테스트 스크립트.

---

## 개발 단계

### Stage 1 — Mock 기반 파이프라인 검증 (✅ 완료)

Fake STM32 를 이용하여 하드웨어 없이 전체 시스템 구조를 사전 검증하였다. UART 핸드셰이크, 상태 전이, 자세 분석 파이프라인, 리포트 생성, DB 저장, 앱 API 연동을 검증하였다.

### Stage 2 — 실 하드웨어 연동 (✅ 완료)

실제 STM32 센서 데이터를 연결하여 센서 매핑, feature threshold, 자세 판별 로직을 실측 기반으로 보정하였다. 30분 이상 연속 측정 3회 검증 결과 패킷 손실률 < 0.1% 달성.

### Stage 3 — 실측 데이터 기반 고도화 (📅 예정)

수집된 실측 데이터를 기반으로 ML 모델 재학습, LLM 리포트 엔진 통합, 자세 판별 정확도 향상 (현재 평균 85% → 90% 목표) 을 진행한다.

---

## 상세 문서

상세 설계 문서는 [`docs/`](docs/) 디렉토리에서 확인할 수 있다.

| 문서 | 설명 |
|------|------|
| [system_architecture.md](docs/system_architecture.md) | 시스템 구조 및 모듈 구성 |
| [code_structure.md](docs/code_structure.md) | 코드 구조 및 파일별 역할 |
| [runtime_sequence.md](docs/runtime_sequence.md) | 런타임 시퀀스 다이어그램 |
| [uart_protocol.md](docs/uart_protocol.md) | STM32 ↔ RPi UART 통신 규약 |
| [api_spec.md](docs/api_spec.md) | 앱 ↔ RPi HTTP/WebSocket API 명세 |
| [database_schema.md](docs/database_schema.md) | SQLite 데이터베이스 스키마 |
| [posture_detection_logic.md](docs/posture_detection_logic.md) | 자세 감지 로직 상세 |
| [posture_definition.md](docs/posture_definition.md) | 자세 정의 |
| [development_stages.md](docs/development_stages.md) | 개발 단계별 검증 내역 |
| [sensor_layout.md](docs/sensor_layout.md) | 센서 배치 |
| [sensor_index_mapping.md](docs/sensor_index_mapping.md) | 센서 인덱스 매핑 |
| [test_checklist.md](docs/test_checklist.md) | 테스트 체크리스트 |
| [stm32_integration_checklist.md](docs/stm32_integration_checklist.md) | STM32 연동 체크리스트 |
| [ble_protocol.md](docs/ble_protocol.md) | BLE 프로토콜 (예비) |

### 추가 LLM / 자세 분석 참고자료

| 문서 | 설명 |
|------|------|
| [LLM 참고.md](LLM%20참고.md) | LLM 통합 참고 |
| [전체(factor, LLM).md](<전체(factor,%20LLM).md>) | factor / LLM 종합 정리 |
| [참고자료.md](참고자료.md) | 일반 참고자료 |

---

## 관련 모듈

| 모듈 | 위치 |
|------|------|
| **전체 시스템 개요** | [`../../README.md`](../../README.md) |
| **STM32 펌웨어** | [`../STM32/`](../STM32/) |
| **Flutter 모바일 앱** | [`../flutter_app/`](../flutter_app/) |
| **PWA 시뮬레이터** | [`../SPCC-WebApp/`](../SPCC-WebApp/) |
