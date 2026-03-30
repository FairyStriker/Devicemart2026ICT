# RaspberryPi
# SPCC — Raspberry Pi Backend

Smart Posture Correction Chair(SPCC) 시스템의 **Raspberry Pi 5 백엔드** 소스코드이다.  
STM32 센서 노드로부터 UART를 통해 수신한 센서 데이터를 실시간으로 분석하고,  
자세 분류 · 점수 산출 · 리포트 생성을 수행한 뒤 Flutter 앱에 WebSocket/HTTP로 전달한다.

---

## 시스템 구성

```text
        Flutter App
            │
            │ WiFi (HTTP / WebSocket)
            ▼
     Raspberry Pi 5 Backend
            │
            │ UART (921600 baud)
            ▼
      STM32F411 Sensor Node
            │
            │ Sensor Input
            ▼
    HX711 / VL53L0X / VL53L8CX / MPU6050
```

---

## 디렉토리 구조

```text
RaspberryPi/
├── main_real.py                  # 실제 RPi 런타임 진입점
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
│   │   ├── llm_report_engine.py      # LLM 리포트 엔진 (확장용)
│   │   └── posture_display.py        # 자세 표시 유틸리티
│   │
│   ├── llm/                      # LLM 연동 (확장용)
│   │   └── report_llm_service.py     # LLM 기반 리포트 서비스
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
└── docs/                         # 설계 문서
    ├── system_architecture.md
    ├── code_structure.md
    ├── runtime_sequence.md
    ├── uart_protocol.md
    ├── api_spec.md
    ├── database_schema.md
    ├── posture_detection_logic.md
    ├── posture_definition.md
    ├── sensor_layout.md
    ├── sensor_index_mapping.md
    ├── development_stages.md
    ├── ble_protocol.md
    ├── stm32_integration_checklist.md
    └── test_checklist.md
```

---

## 설치 및 실행

### 의존성 설치

```bash
pip install -r requirements.txt
```

주요 패키지: `fastapi`, `uvicorn`, `pyserial`, `numpy`, `pandas`, `scikit-learn`, `joblib`

### 실행

```bash
# 실제 RPi 환경 (STM32 연결)
python main_real.py

# Mock STM32로 테스트
POSTURE_UART_MOCK=1 python main_real.py
```

---

## 환경 변수 설정

| 환경 변수 | 기본값 | 설명 |
|-----------|--------|------|
| `POSTURE_UART_PORT` | `/dev/ttyAMA3` | UART 포트 |
| `POSTURE_UART_BAUD` | `921600` | UART Baud Rate |
| `POSTURE_UART_MOCK` | `0` | Mock 모드 (`1`이면 가상 STM32 사용) |
| `POSTURE_SAMPLE_RATE_HZ` | `50` | 센서 샘플링 주파수 |
| `POSTURE_CALIBRATION_SEC` | `10` | 캘리브레이션 지속 시간(초) |
| `POSTURE_REPORT_ENGINE` | `rule` | 리포트 엔진 (`rule` / `llm`) |
| `POSTURE_BUZZER_ENABLE` | `0` | 부저 피드백 활성화 |
| `POSTURE_DEBUG_SENSOR` | `0` | 센서 요약 디버그 출력 |
| `POSTURE_DEBUG_FEATURES` | `0` | Feature 디버그 출력 |
| `POSTURE_DEBUG_FLAGS` | `0` | Flag 디버그 출력 |
| `POSTURE_ENABLE_SAMPLE_LOGGER` | `1` | CSV 샘플 로거 활성화 |

---

## UART 통신 프로토콜

STM32와 RPi 간 통신은 두 가지 모드로 동작한다.

### ASCII Control Mode

시스템 제어용 텍스트 메시지 (`\n` 구분)

| 방향 | 메시지 | 설명 |
|------|--------|------|
| STM32 → RPi | `READY` | 부팅 완료, 통신 준비 |
| RPi → STM32 | `ACK` | READY 응답 |
| STM32 → RPi | `LINK_OK` | 링크 연결 확인 |
| RPi → STM32 | `CHK_SIT` | 착석 확인 요청 |
| STM32 → RPi | `SIT` | 착석 확인 응답 |
| RPi → STM32 | `CAL` | 캘리브레이션 시작 |
| RPi → STM32 | `GO` | 측정 시작 |
| RPi → STM32 | `STOP` | 측정 중단 |
| STM32 → RPi | `STAND` | 자리 이탈 감지 (5초 지속) |

### Binary Sensor Stream Mode

129바이트 고정 길이 패킷 (50Hz 전송)

```text
[Header 4B] [Loadcell 48B] [Spine ToF 8B] [3D ToF 64B] [IMU 4B] [Checksum 1B]
 DAT:/CAL:   12×int32        4×uint16       32×uint16     2×int16    XOR
```

---

## 앱 통신 API

### HTTP Endpoints

| Method | Endpoint | 설명 |
|--------|----------|------|
| `GET` | `/health` | 서버 상태 확인 |
| `GET` | `/meta` | 현재 시스템 stage/사용자 정보 |
| `POST` | `/command` | 앱 → RPi 명령 전달 |

### WebSocket

```
ws://<raspberry_pi_ip>:8000/ws
```

Push 전송 payload 종류: `meta`, `realtime_status`, `minute_summary`, `overall_summary`, `stand_event`, `enhanced_report`

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

---

## 런타임 동작 흐름

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
  └─ 실시간 측정 루프 (50Hz)
      ├─ DAT 패킷 수신 및 파싱
      ├─ semantic mapping
      ├─ feature 추출
      ├─ 자세 분류 (ML + Rule-based)
      ├─ 자세 플래그 판정
      ├─ 점수 산출 및 경고 단계 계산
      ├─ realtime_status WebSocket 브로드캐스트
      ├─ 분 단위 리포트 누적
      │
      ├─ [STAND 이벤트] → 앱에 stand_event 전달 → 재측정/종료 선택
      ├─ [일시정지] → STOP → resume/quit/recalibration 대기
      └─ [세션 종료] → 리포트 생성 → DB 저장
```

---

## 자세 분류

### 감지 가능한 자세 (8종)

| Label | 한글명 | 설명 |
|-------|--------|------|
| `normal` | 정자세 | 올바른 착석 자세 |
| `turtle_neck` | 거북목 | 목이 앞으로 돌출 |
| `forward_lean` | 상체 굽힘 | 상체가 앞으로 기울어짐 |
| `reclined` | 기대앉기 | 상체가 뒤로 기울어짐 |
| `side_slouch` | 측면 기울어짐 | 좌우 하중 불균형 |
| `leg_cross_suspect` | 다리 꼬기 의심 | 좌석 압력 비대칭 |
| `thinking_pose` | 턱 괴기 | 한쪽 팔에 체중 지지 |
| `perching` | 걸터앉기 | 의자 앞쪽에만 체중 분포 |

### 분류 방식

- **ML 분류기**: scikit-learn RandomForest (`saved_models/posture_rf.pkl`)
- **Rule-based 분류기**: threshold 기반 규칙 판별 (fallback)
- **자세 플래그**: 복합 자세 이상을 개별 플래그로 동시 판정

### 데이터 처리 파이프라인

```text
DAT Packet
  → packet_parser (struct.unpack)
  → sensor_mapper (semantic 구조 변환)
  → feature_extractor (자세 feature 계산)
  → posture_classifier (ML 예측)
  → posture_flags (규칙 기반 플래그)
  → posture_score (점수/경고 산출)
  → report_generator (리포트 누적)
  → wifi_server (WebSocket 브로드캐스트)
```

---

## 센서 구성 및 매핑

### Loadcell (HX711 × 12)

| Index | 위치 |
|-------|------|
| 0 | 등판 우측 상단 |
| 1 | 등판 우측 상중단 |
| 2 | 등판 우측 하중단 |
| 3 | 등판 우측 하단 |
| 4 | 등판 좌측 상단 |
| 5 | 등판 좌측 상중단 |
| 6 | 등판 좌측 하중단 |
| 7 | 등판 좌측 하단 |
| 8 | 좌판 후방 우 |
| 9 | 좌판 전방 우 |
| 10 | 좌판 후방 좌 |
| 11 | 좌판 전방 좌 |

### ToF 센서

| Index | 센서 | 위치 |
|-------|------|------|
| 12 | VL53L8CX (3D) | 헤드레스트 우측 |
| 13 | VL53L8CX (3D) | 헤드레스트 좌측 |
| 14–17 | VL53L0X (1D) | 등판 척추 라인 (상→하) |

### IMU

| Index | 센서 | 위치 |
|-------|------|------|
| 18 | MPU6050 | 의자 기울기 측정 |

---

## 데이터 저장

### SQLite (`posture_system.db`)

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

측정 중 raw/semantic/feature/flag 데이터를 CSV로 기록하여 후속 모델 재학습에 활용한다.

---

## 리포트 시스템

### 리포트 지표

| 지표 | 설명 |
|------|------|
| `avg_score` | 평균 자세 점수 |
| `total_sitting_sec` | 총 착석 시간 |
| `dominant_posture` | 가장 빈번한 자세 |
| `dominant_posture_ratio` | 대표 자세 비율 (%) |
| `good_posture_ratio` | 정상 자세 비율 (%) |
| `bad_posture_ratio` | 비정상 자세 비율 (%) |
| `posture_duration_sec` | 자세별 누적 시간 |

### Enhanced Report

Rule-based 또는 LLM 기반으로 생성되는 해석형 리포트이다.  
요약 문장(`summary_text`), 추이 분석(`trend_text`), 운동 추천(`exercise_recommendations`)을 포함한다.

---

## 개발 도구

### `tools/fake_stm32.py`

실제 STM32 없이 전체 시스템을 테스트하기 위한 가상 센서 노드이다.  
UART 핸드셰이크, CAL/DAT 스트림, STAND 이벤트를 시뮬레이션한다.

### `tools/fake_app.py`

가상 앱 클라이언트로, HTTP/WebSocket을 통해 RPi 서버에 command를 전송하고 payload를 수신한다.

### `tools/uart_packet_sniffer.py`

UART raw 패킷을 직접 수신하여 checksum 검증 및 센서값을 출력하는 디버깅 도구이다.

### `main_compare.py`

ML 분류기와 Rule-based 분류기의 예측 결과를 자세별로 비교하는 테스트 스크립트이다.

---

## 개발 단계

### Stage 1 — Mock 기반 파이프라인 검증 (완료)

Fake STM32를 이용하여 하드웨어 없이 전체 시스템 구조를 사전 검증하였다.  
UART 핸드셰이크, 상태 전이, 자세 분석 파이프라인, 리포트 생성, DB 저장, 앱 API 연동을 검증하였다.

### Stage 2 — 실제 하드웨어 연동 (진행 중)

실제 STM32 센서 데이터를 연결하여 센서 매핑, feature threshold, 자세 판별 로직을 실측 기반으로 보정하는 단계이다.

### Stage 3 — 실측 데이터 기반 고도화 (예정)

수집된 실측 데이터를 기반으로 ML 모델 재학습, LLM 리포트 엔진 통합, 자세 판별 정확도 향상을 진행한다.

---

## 문서

상세 설계 문서는 `docs/` 디렉토리에서 확인할 수 있다.

| 문서 | 설명 |
|------|------|
| [system_architecture.md](docs/system_architecture.md) | 시스템 구조 및 모듈 구성 |
| [code_structure.md](docs/code_structure.md) | 코드 구조 및 파일별 역할 |
| [runtime_sequence.md](docs/runtime_sequence.md) | 런타임 시퀀스 다이어그램 |
| [uart_protocol.md](docs/uart_protocol.md) | STM32 ↔ RPi UART 통신 규약 |
| [api_spec.md](docs/api_spec.md) | 앱 ↔ RPi HTTP/WebSocket API 명세 |
| [database_schema.md](docs/database_schema.md) | SQLite 데이터베이스 스키마 |
| [posture_detection_logic.md](docs/posture_detection_logic.md) | 자세 감지 로직 |
| [development_stages.md](docs/development_stages.md) | 개발 단계별 검증 내역 |
| [sensor_layout.md](docs/sensor_layout.md) | 센서 배치 |
| [sensor_index_mapping.md](docs/sensor_index_mapping.md) | 센서 인덱스 매핑 |
| [test_checklist.md](docs/test_checklist.md) | 테스트 체크리스트 |
| [stm32_integration_checklist.md](docs/stm32_integration_checklist.md) | STM32 연동 체크리스트 |
