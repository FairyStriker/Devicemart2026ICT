# Flutter Mobile App

> **스마트 자세 교정 의자** 의 Android / Web 클라이언트 앱
> RPi5 의 17개 시스템 stage 변화에 따라 5개 화면이 자동으로 라우팅되는 서버 주도(server-driven) 구조

<p align="center">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Flutter-02569B">
  <img alt="Language" src="https://img.shields.io/badge/Language-Dart-0175C2">
  <img alt="Design" src="https://img.shields.io/badge/Design-Material%203-757575">
  <img alt="State" src="https://img.shields.io/badge/State-Provider-blue">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-3DDC84">
</p>

---

## 목차

1. [개요](#개요)
2. [시스템 위치](#시스템-위치)
3. [핵심 설계 — 서버 주도 라우팅](#핵심-설계--서버-주도-라우팅)
4. [폴더 구조](#폴더-구조)
5. [화면 흐름](#화면-흐름)
6. [화면별 상세](#화면별-상세)
7. [통신 구조](#통신-구조)
8. [상태 관리](#상태-관리)
9. [센서 시각화](#센서-시각화)
10. [감지 자세](#감지-자세)
11. [실행](#실행)
12. [의존성](#의존성)

---

## 개요

본 모듈은 RPi5 분석 서버에 명령을 전송하고 실시간 자세 데이터를 수신·시각화하는 모바일 앱이다.

### 주요 기능

| # | 기능 | 설명 |
|---|------|------|
| 1 | **서버 주도 라우팅** | RPi5 의 17개 stage 변화에 따라 5개 화면이 자동 전환 |
| 2 | **실시간 4탭 대시보드** | 점수 / 압력 분포 / 프로토콜 / 로그 동시 모니터링 |
| 3 | **3행 4열 압력 시각화** | 등판 8 + 척추 4 + 좌석 4 셀에 양호 → 주의 → 위험 색상 표시 |
| 4 | **AI 분석 리포트 열람** | RPi5 의 LLM 추론 결과를 자동 수신하여 표시 |
| 5 | **오프라인 보고서 5개 보관** | 최근 5개 세션 결과를 SharedPreferences 에 저장 |
| 6 | **자리 이탈 다이얼로그** | STAND 이벤트 수신 시 재개 / 종료 다이얼로그 표시 |

---

## 시스템 위치

```text
   ┌────────────────┐    ┌────────────────┐    ┌──────────────────┐
   │  STM32F411     │UART│  Raspberry Pi5 │WiFi│  Flutter App     │
   │  센서 노드     │───▶│  분석 서버     │───▶│  ★ 본 모듈 ★    │
   │  50 Hz 수집    │921k│  LLM 리포트    │HTTP│  실시간 시각화   │
   └────────────────┘    └────────────────┘    └──────────────────┘
```

---

## 핵심 설계 — 서버 주도 라우팅

본 앱의 화면 전환은 **사용자 버튼 입력이 아닌 RPi5 서버의 stage 변화**에 의해 결정된다.

```text
일반 모바일 앱:
   [버튼 누름] → [앱이 직접 다음 화면으로 이동]

본 앱:
   [버튼 누름] → [RPi5에 command 전송]
                  ↓
                  [서버가 stage 갱신]
                  ↓
                  [WebSocket으로 stage 변경 알림]
                  ↓
                  [전역 상태 갱신 → 라우터 자동 화면 전환]
```

### 장점

- **상태 동기화 보장**: 통신 지연이나 명령 처리 실패 시에도 앱과 서버 상태가 항상 일치
- **단일 진실 공급원**: RPi5 의 stage 가 시스템 진행 상태의 유일한 기준
- **에러 복구 용이**: 앱이 임의 화면을 표시하지 않으므로 서버 재연결 시 즉시 동기화

### Stage → Screen 매핑

| RPi5 Stage 그룹 | 표시 화면 |
|----------------|-----------|
| `boot`, `uart_link_ready` | SplashScreen → ProfileScreen |
| `wait_calibration_decision`, `calibrating` | CalibrationScreen |
| `wait_start_decision`, `measuring`, `paused` | MeasurementScreen |
| `wait_restart_decision`, `session_finished` | ReportScreen |
| (오프라인) | ReportHistoryScreen |

> 17개 세부 stage 는 위 5개 화면 그룹으로 매핑된다.

---

## 폴더 구조

```text
flutter_app/
├── pubspec.yaml                       # Flutter 의존성 / 메타정보
├── android/                           # Android 빌드 설정
│   └── app/
│       ├── proguard-rules.pro         # 코드 난독화
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── res/xml/
│               └── network_security_config.xml  # 평문 HTTP 허용 (RPi5 로컬 통신)
│
└── lib/
    ├── main.dart                       # 진입점 + stage 기반 화면 라우팅
    │
    ├── models/                         # 데이터 모델
    │   ├── stage.dart                      # RPi5 stage 상수 (17종)
    │   ├── meta_model.dart                 # meta payload (사용자 정보 / stage)
    │   ├── realtime_status_model.dart      # 자세 판정 + 집계 점수
    │   ├── sensor_distribution_model.dart  # 17개 센서 {percent, level, raw}
    │   └── summary_model.dart              # minute / overall / enhanced / stand
    │
    ├── services/
    │   ├── api_service.dart                # HTTP POST /command
    │   ├── websocket_service.dart          # WebSocket 7종 type 분기 처리
    │   └── report_storage_service.dart     # 최근 5개 보고서 로컬 저장
    │
    ├── providers/
    │   └── app_state_provider.dart         # 전역 상태 (Provider + WS 콜백)
    │
    ├── widgets/
    │   └── chair_sensor_widget.dart        # 좌석 압력 분포 격자 시각화
    │
    └── screens/
        ├── splash_screen.dart              # IP 입력 + 최근 보고서 진입점
        ├── profile_screen.dart             # 신규 등록 / 기존 선택
        ├── calibration_screen.dart         # 캘리브레이션 시작 / 생략
        ├── measurement_screen.dart         # 4탭 실시간 대시보드
        ├── report_screen.dart              # 세션 결과 + AI 분석
        └── report_history_screen.dart      # 오프라인 보고서 열람
```

---

## 화면 흐름

```text
SplashScreen (IP 입력)
    │
    ├── [최근 보고서] ────▶ ReportHistoryScreen (오프라인)
    │
    └── [연결] ────▶ ProfileScreen (신규 등록 / 기존 선택)
                         │
                         └─▶ CalibrationScreen (시작 / 생략)
                                  │
                                  └─▶ MeasurementScreen (실시간 측정 + 4탭)
                                           │
                                           ├── [STAND 이벤트] → 다이얼로그
                                           │      ├─ 재개 → 측정 계속
                                           │      └─ 종료 → ReportScreen
                                           │
                                           └─▶ ReportScreen (세션 결과 + AI 분석 + 자동 저장)
```

---

## 화면별 상세

### 1. SplashScreen

| 항목 | 내용 |
|------|------|
| 역할 | RPi5 IP 주소 입력 / 연결 시작 / 최근 보고서 5개 진입점 |
| 진입 stage | (앱 시작 직후) |
| 주요 위젯 | IP 텍스트필드, 연결 버튼, 최근 보고서 버튼 |

### 2. ProfileScreen

| 항목 | 내용 |
|------|------|
| 역할 | 신규 프로필 등록 (이름, 키, 체중, 작업/휴식 시간) 또는 기존 프로필 선택 |
| 진입 stage | `uart_link_ready` |
| 송신 명령 | `submit_profile` / `select_profile` (POST `/command`) |

### 3. CalibrationScreen

| 항목 | 내용 |
|------|------|
| 역할 | 캘리브레이션 시작 / 생략 선택, 진행 상태 표시 |
| 진입 stage | `wait_calibration_decision` |
| 송신 명령 | `start_calibration` / `skip_calibration` |
| 표시 정보 | 캘리브레이션 진행률 (10초 / 500 프레임) |

### 4. MeasurementScreen ⭐ 핵심 화면

4개 탭으로 구성된 실시간 대시보드.

#### 탭 1 — 대시보드

- 실시간 자세 점수
- 감지된 자세 유형 (8종)
- 좌우 균형 / 척추 거리 / 목 거리 집계 모니터링 지표

#### 탭 2 — 압력 분포

의자 형태를 모방한 격자 시각화 위젯:

```text
┌─────────────────────────────────────┐
│  등판 영역 (3행 × 4열 = 12셀)        │
│  ┌──┬──┬──┬──┐                      │
│  │L1│척1│척2│R1│  ← 등판 좌·척추·우 │
│  ├──┼──┼──┼──┤                      │
│  │L2│척3│척4│R2│                    │
│  ├──┼──┼──┼──┤                      │
│  │L3│  │  │R3│                      │
│  ├──┼──┼──┼──┤                      │
│  │L4│  │  │R4│                      │
│  └──┴──┴──┴──┘                      │
│                                     │
│  좌석 영역 (2행 × 2열 = 4셀)         │
│  ┌──┬──┐                            │
│  │후좌│후우│                        │
│  ├──┼──┤                            │
│  │전좌│전우│                        │
│  └──┴──┘                            │
└─────────────────────────────────────┘

색상: 🟢 양호 → 🟡 주의 → 🔴 위험
```

각 셀의 배경색이 양호 · 주의 · 위험 상태에 따라 실시간으로 변화한다.

#### 탭 3 — 프로토콜

- 현재 시스템 단계 (stage)
- 연결 상태 (HTTP / WebSocket)
- WebSocket 수신 주기 등 통신 상태

#### 탭 4 — 로그

- 시스템 단계 변경 이력
- 자세 변경 이벤트
- 경고 이벤트
- 실시간 통신 로그 누적 표시

#### 자리 이탈 처리

`stand_event` 수신 시 다이얼로그를 통해 **재개** 또는 **종료** 선택을 사용자에게 요청한다.

| 항목 | 내용 |
|------|------|
| 진입 stage | `measuring`, `paused` |
| 송신 명령 | `pause_measurement` / `resume_measurement` / `quit_measurement` / `resume_after_stand` / `decline_resume_after_stand` |

### 5. ReportScreen

| 항목 | 내용 |
|------|------|
| 역할 | 세션 종합 결과 표시 + AI 분석 코멘트 |
| 진입 stage | `wait_restart_decision`, `session_finished` |
| 표시 정보 | 평균 점수 · 자세 분포 · 측정 시간 · LLM 코멘트 |
| 자동 저장 | 종료 시 SharedPreferences 에 저장 (최근 5개 유지) |

> RPi5 에서 Qwen3.5-0.8B 모델이 로컬 추론한 자세 분석 피드백을 `enhanced_report` payload 로 수신·표시한다.

### 6. ReportHistoryScreen

| 항목 | 내용 |
|------|------|
| 역할 | 오프라인 상태에서도 최근 5개 보고서 열람 |
| 데이터 출처 | SharedPreferences 로컬 저장소 |

---

## 통신 구조

### HTTP (앱 → RPi5)

| Method | Endpoint | 용도 |
|--------|----------|------|
| `POST` | `http://<RPi5 IP>:8000/command` | 8종 command 전송 |
| `GET` | `http://<RPi5 IP>:8000/meta` | 초기 연결 확인 |

### WebSocket (RPi5 → 앱)

```
ws://<RPi5 IP>:8000/ws
```

#### 7종 Payload Type

| Type | 주기 | 용도 |
|------|------|------|
| `meta` | stage 변경 시 | **화면 자동 전환 기준** |
| `realtime_status` | 50 Hz | 자세 판정 + 집계 점수 |
| `sensor_distribution` | ~5 Hz | 17개 센서 시각화 데이터 |
| `stand_event` | 이벤트 | 자리 이탈 알림 |
| `minute_summary` | 1분마다 | 분 단위 누적 리포트 |
| `overall_summary` | 세션 종료 | 전체 결과 요약 |
| `enhanced_report` | 세션 종료 | LLM 분석 리포트 |

### 송신 Command (앱 → RPi5)

| Command | 의미 |
|---------|------|
| `submit_profile` | 신규 프로필 등록 |
| `select_profile` | 기존 프로필 선택 |
| `start_calibration` | 캘리브레이션 시작 |
| `skip_calibration` | 캘리브레이션 생략 |
| `start_measurement` | 측정 시작 |
| `pause_measurement` | 측정 일시정지 |
| `resume_measurement` | 측정 재개 |
| `quit_measurement` | 세션 종료 |
| `request_recalibration` | 재캘리브레이션 |
| `resume_after_stand` | STAND 후 재측정 |
| `decline_resume_after_stand` | STAND 후 종료 |

### Ack 형식

```json
{ "ok": true,  "message": "command_received" }
{ "ok": false, "message": "invalid_command" }
```

---

## 상태 관리

본 앱은 **Provider 패턴**으로 전역 상태를 관리한다.

### `AppStateProvider`

WebSocket 콜백에서 다음을 처리한다.

| 처리 항목 | 설명 |
|----------|------|
| 시스템 단계 변경 감지 | 화면 라우팅 트리거 |
| 실시간 자세 업데이트 | 대시보드 / 압력 분포 갱신 |
| Stand event 처리 | 중복 방지 플래그 적용 |
| 분 요약 누적 | minute_summary 리스트 관리 |
| 세션 결과 수신 | overall_summary 저장 |
| AI 분석 결과 수신 | enhanced_report 즉시 반영 |

```text
WebSocket 수신
   │
   ├─▶ AppStateProvider (전역 상태 갱신)
   │       │
   │       └─▶ notifyListeners()
   │
   ├─▶ 라우터 (stage 변화 감지 → 화면 자동 전환)
   └─▶ UI 위젯 (Consumer/Selector → 즉시 리빌드)
```

---

## 센서 시각화

### `widgets/chair_sensor_widget.dart`

의자의 실제 센서 배치를 반영한 격자 위젯이다.

| 영역 | 격자 | 데이터 출처 |
|------|------|------------|
| 등판 | 3행 × 4열 (12셀) | `back_pressure.*` (8) + `spine_tof.*` (4) |
| 좌석 | 2행 × 2열 (4셀) | `seat_pressure.*` (4) |

각 셀의 배경색은 **양호 → 주의 → 위험** 단계에 따라 다음과 같이 변한다.

| 상태 | 색상 |
|------|------|
| 양호 (`level=0`) | 🟢 초록 |
| 주의 (`level=1`) | 🟡 노랑 |
| 위험 (`level=2`) | 🔴 빨강 |

### 센서 위치 매핑 (17개)

| 위치 | 센서 종류 | 수량 | payload 키 |
|------|----------|------|-----------|
| 등받이 좌·우 | HX711 (압력) | 8 | `back_pressure.*` |
| 등받이 척추 라인 | VL53L0X (1D ToF) | 4 | `spine_tof.*` |
| 좌석 4구역 | HX711 (압력) | 4 | `seat_pressure.*` |
| 헤드레스트 | VL53L8CX (3D ToF) | 2 | `head_tof.*` |
| 의자 본체 | MPU6050 (IMU) | 2 | `imu.*` |

---

## 감지 자세

| 코드 | 한글명 |
|------|--------|
| `normal` | 정자세 |
| `turtle_neck` | 거북목 |
| `forward_lean` | 상체 전방 기울기 |
| `reclined` | 뒤로 기대기 |
| `side_slouch` | 측면 쏠림 |
| `leg_cross_suspect` | 다리 꼬기 의심 |
| `perching` | 걸터앉기 |
| `slouched` | 전방 숙임 |

자세 분류는 RPi5 에서 수행되며, 앱은 결과만 수신하여 표시한다.

---

## 실행

```bash
# 의존성 설치
flutter pub get

# 개발 모드 실행 (Android 디바이스 / 에뮬레이터 / Chrome)
flutter run

# Android 릴리즈 APK 빌드
flutter build apk --release

# Web 빌드
flutter build web
```

### 평문 HTTP 통신 허용 (Android)

RPi5 와 LAN 내 평문 HTTP 로 통신하기 위해 `network_security_config.xml` 에 cleartext 를 허용한다. 운영 환경에서는 특정 IP 만 화이트리스트로 제한해야 한다.

---

## 의존성

```yaml
provider: ^6.1.1                  # 전역 상태 관리
http: ^1.2.0                      # HTTP POST 요청
web_socket_channel: ^3.0.1        # WebSocket 수신
shared_preferences: ^2.2.2        # 보고서 로컬 저장
```

---

## 통합 테스트 결과

| 검증 항목 | 결과 |
|----------|------|
| RPi5 연결 / 프로필 등록·선택 | ✅ 정상 |
| 캘리브레이션 흐름 | ✅ 정상 |
| 실시간 측정 50 Hz 시각화 | ✅ 정상 |
| 자리 이탈 다이얼로그 | ✅ 정상 |
| LLM 분석 결과 수신·표시 | ✅ 정상 (평균 약 20초) |
| 오프라인 보고서 열람 | ✅ 정상 |

---

## 관련 모듈

| 모듈 | 위치 |
|------|------|
| **전체 시스템 개요** | [`../../README.md`](../../README.md) |
| **STM32 펌웨어** | [`../STM32/`](../STM32/) |
| **Raspberry Pi 백엔드** | [`../RaspberryPi/`](../RaspberryPi/) |
| **앱 ↔ RPi API 명세 (상세)** | [`../RaspberryPi/docs/api_spec.md`](../RaspberryPi/docs/api_spec.md) |
