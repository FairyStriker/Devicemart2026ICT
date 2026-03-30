# Flutter App — 스마트 자세 교정 의자

RPi5 + STM32 기반 스마트 자세 교정 의자의 Android/Web 클라이언트 앱

## 시스템 구성
```
STM32F411 (센서 수집, 50Hz)
    ↓ UART 921600baud
RPi5 (자세 판정)
    ↓ WiFi (HTTP + WebSocket)
Flutter App (시각화, 제어)
```

## 통신 구조

| 방향 | 프로토콜 | 경로 |
|------|----------|------|
| 앱 → RPi | HTTP POST | `http://<IP>:8000/command` |
| RPi → 앱 | WebSocket | `ws://<IP>:8000/ws` |

### Command (앱 → RPi, 11종)

`submit_profile`, `select_profile`, `start_calibration`, `skip_calibration`, `start_measurement`, `pause_measurement`, `resume_measurement`, `quit_measurement`, `request_recalibration`, `resume_after_stand`, `decline_resume_after_stand`

### WebSocket Payload (RPi → 앱, 7종)

| type | 주기 | 용도 |
|------|------|------|
| `meta` | stage 변경 시 | 화면 전환 기준 |
| `realtime_status` | 50Hz | 자세 판정 + 집계 점수 |
| `sensor_distribution` | ~5Hz | 개별 센서 17종 시각화 |
| `stand_event` | 이벤트 | 자리 이탈 알림 |
| `minute_summary` | 1분마다 | 분별 리포트 |
| `overall_summary` | 세션 종료 | 전체 결과 |
| `enhanced_report` | 세션 종료 | AI 분석 보고서 |

## 프로젝트 구조
```
lib/
├── main.dart                              # 진입점 + stage 기반 화면 라우팅
│
├── models/
│   ├── stage.dart                         # RPi stage 상수
│   ├── meta_model.dart                    # meta payload
│   ├── realtime_status_model.dart         # 자세 판정 + 집계 점수
│   ├── sensor_distribution_model.dart     # 개별 센서 {percent, level, raw}
│   └── summary_model.dart                 # 결과 (minute/overall/enhanced/stand)
│
├── services/
│   ├── api_service.dart                   # HTTP POST /command
│   ├── websocket_service.dart             # WebSocket 수신 (7종 type 분기)
│   └── report_storage_service.dart        # 최근 5개 보고서 로컬 저장
│
├── providers/
│   └── app_state_provider.dart            # 전역 상태 (Provider + WS 콜백)
│
├── widgets/
│   └── chair_sensor_widget.dart           # 좌석 압력 분포 시각화
│
└── screens/
    ├── splash_screen.dart                 # IP 입력 + 최근 보고서 버튼
    ├── profile_screen.dart                # 프로필 등록/선택
    ├── calibration_screen.dart            # 캘리브레이션
    ├── measurement_screen.dart            # 실시간 측정 (4탭: 대시보드/압력분포/프로토콜/로그)
    ├── report_screen.dart                 # 세션 결과 + AI 분석
    └── report_history_screen.dart         # 저장된 보고서 열람 (오프라인)
```

## 화면 흐름
```
SplashScreen (IP 입력)
    ├── [최근 보고서] → ReportHistoryScreen (오프라인)
    └── [연결] → ProfileScreen
                    └── CalibrationScreen
                            └── MeasurementScreen (실시간)
                                    └── ReportScreen (AI 분석 + 자동 저장)
```

## 센서 구성

| 위치 | 센서 | 수량 | 데이터 |
|------|------|------|--------|
| 등받이 좌우 | HX711 (압력) | 8개 | `back_pressure.*` |
| 등받이 중앙 | VL53L0X (ToF) | 4개 | `spine_tof.*` |
| 좌석 | HX711 (압력) | 4개 | `seat_pressure.*` |
| 머리/목 | VL53L8CX (3D ToF) | 2개 | `head_tof.*` |
| 등판 | MPU6050 (IMU) | 2개 | `imu.*` |

## 감지 자세 (8종, 동시 감지)

| 코드 | 한글 |
|------|------|
| `normal` | 정자세 |
| `turtle_neck` | 거북목 |
| `forward_lean` | 상체 굽힘 |
| `reclined` | 누워 앉기 |
| `side_slouch` | 새우 자세 |
| `leg_cross_suspect` | 다리 꼬기 |
| `thinking_pose` | 생각하는 사람 자세 |
| `perching` | 걸터앉기 |

## 실행
```bash
flutter pub get
flutter run
```

## 의존성
```yaml
provider: ^6.1.1
http: ^1.2.0
web_socket_channel: ^3.0.1
shared_preferences: ^2.2.2
```
