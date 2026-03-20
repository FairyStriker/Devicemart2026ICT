# POSTURE AI — Flutter App

## 프로젝트 구조

```
lib/
├── main.dart                        # 앱 진입점 + stage별 화면 라우팅
│
├── models/
│   ├── stage.dart                   # RPi stage 상수 (session_state.py 동기화)
│   ├── meta_model.dart              # GET /meta 응답 모델
│   ├── realtime_status_model.dart   # GET /status 실시간 자세 모델
│   └── summary_model.dart           # GET /report 결과 모델
│
├── services/
│   ├── api_service.dart             # HTTP 통신 (GET/POST)
│   └── polling_service.dart         # 0.5~2초 주기 polling
│
├── providers/
│   └── app_state_provider.dart      # 전역 상태 (Provider)
│
└── screens/
    ├── splash_screen.dart           # IP 입력 / 연결
    ├── profile_screen.dart          # 프로필 등록/선택
    ├── calibration_screen.dart      # 캘리브레이션 흐름
    ├── measurement_screen.dart      # 실시간 측정 (핵심 화면)
    └── report_screen.dart           # 세션 결과
```

## 화면 흐름 (stage 기준)

```
SplashScreen          → 연결 전 / 연결 실패
ProfileScreen         → uart_link_ready, profile_loaded
CalibrationScreen     → wait_calibration_decision ~ calibration_completed
MeasurementScreen     → wait_start_decision ~ measuring ~ paused
ReportScreen          → session_saved, session_ended
```

## 통신 방식

| 방향 | 방법 |
|------|------|
| 앱 → RPi | HTTP POST /command |
| RPi → 앱 | HTTP Polling (GET /meta, /status, /report) |

- `/meta`   : 0.8초 주기 (stage 변화 감지)
- `/status` : 0.5초 주기 (실시간 자세)
- `/report` : 2초 주기 (세션 결과)

## 설치 및 실행

```bash
flutter pub get
flutter run
```

## 의존성

```yaml
provider: ^6.1.1         # 상태 관리
http: ^1.2.0             # HTTP 통신
shared_preferences: ^2.2.2  # IP 저장
```
