# 요약
- RPi 접속 후 cd posture_ai -> python main_real.py하면 동작
- Factor 적용 위치 확인용, 현재 흐름 이해용으로 src/runtime/measurement_runtime.py 확인 가능
- 리포트 생성 흐름 이해용으로 main_real.py 확인 가능
- Factor 수정 -> src/core/sensor_factor.py, src/config/settings.py
- LLM 수정 -> src/report/report_service.py, src/llm/service.py
- 부저는 코드 수정 안 하고 환경변수로 ON/OFF 가능하고 ON 할 시 requirement.txt에 #gpiod; platform_system == "Linux" 이거 주석 해제하고 pip install -r requirement.txt 후 환경변수로 제어하면 됨
	ON: POSTURE_BUZZER_ENABLE=1 python main_real.py

# 📌 현재 시스템 개요
- STM32
- 센서 데이터 수집
- Loadcell 12ch
- ToF 3D 32ch
- ToF 1D 4ch
- MPU 2ch
- UART로 Raspberry Pi에 바이너리 패킷 전송
- Raspberry Pi
- UART 수신
- packet parsing / checksum 검증
- feature extraction
- posture classification
- score 계산
- SQLite 저장
- 최종 리포트 생성
- 모바일 앱과 통신

⸻

# 📂 현재 확인된 파일 트리
```md
posture_ai/
├── main_real.py
├── requirements.txt
└── src/
    ├── config/
    │   └── settings.py
    ├── communication/
    │   ├── app_payload_builder.py
    │   ├── command_sender.py
    │   └── uart_protocol.py
    ├── feedback/
    │   ├── audio_feedback.py
    │   └── buzzer_feedback.py
    ├── llm/
    │   └── report_llm_service.py
    ├── report/
    │   ├── report_generator.py
    │   ├── report_service.py
    │   └── report_enhancer.py
    ├── runtime/
    │   └── measurement_runtime.py
    └── core/
        └── sensor_factor.py
```

⸻

# ✅ 현재까지 반영 완료된 사항

## 1. factor 구조 선반영 완료

아래 작업은 이미 반영된 상태다.
- src/core/sensor_factor.py 생성 완료
- src/config/settings.py에 factor 관련 설정 추가 완료
- src/runtime/measurement_runtime.py에 factor 적용 연결 완료

즉 현재 구조는 아래 흐름이다.
```md
raw_packet 수신
→ apply_sensor_factors(raw_packet)
→ map_raw_packet(raw_packet)
→ feature extraction
→ posture classification / score 계산
```

## 2. 현재 factor 상태
- 지금은 의자가 최종 완성 전이라 최종 factor 수치 확정 불가
- 따라서 현재는 기본값 scaffold 중심
- 나중에 최종 실측 후 settings.py의 수치만 교체 예정

⸻

# 🔥 앞으로 해야 할 작업 1: LLM 리포트 연동

목표

세션 종료 후 생성되는:
- overall_summary
- minute_summary

를 기반으로 실제 LLM을 호출해서 자연어 리포트를 생성하는 구조로 연결

⸻

# 수정 대상 파일

## 1) src/report/report_service.py

현재는 rule 기반 enhancer 중심 구조다.
해야 할 일:
- REPORT_ENGINE == "llm" 분기 추가
- ReportLLMService 연결

즉 방향은 아래와 같다.
```md
if engine == "rule" → 기존 report_enhancer 사용
if engine == "llm"  → report_llm_service 사용
```

⸻

## 2) src/llm/report_llm_service.py

현재는 mock 수준의 뼈대 파일이다.
해야 할 일:
- 프롬프트 구성
- llama.cpp 호출
- GGUF 모델 경로 사용
- 결과 파싱
- 최종 반환 형식 통일

출력 형식 목표:
```json
{
    "summary_text": "...",
    "trend_text": "...",
    "exercise_recommendations": ["...", "...", "..."]
}
```

⸻

## 3) src/config/settings.py

확인 및 정리할 항목:
- REPORT_ENGINE
- LLM_REPORT_MODE
- LLM_MODEL_BACKEND
- LLM_GGUF_MODEL_PATH
- LLM_CONTEXT_LEN
- LLM_MAX_TOKENS
- LLM_TEMPERATURE

⸻

참고

main_real.py는 이미 세션 종료 후 아래 구조를 가지고 있다.
```md
overall_summary 생성
minute_summary 생성
report_service.build_enhanced_report(...) 호출
```
따라서 main_real.py 수정은 최소화하고,
핵심 구현은 report_service.py / report_llm_service.py 쪽에서 처리하는 방향으로 가면 된다.

⸻

# 🔥 앞으로 해야 할 작업 2: 부저 실연동 복구 및 테스트

현재는 부저 기능을 안전하게 비활성화한 상태다.
즉 handshake / UART / 센서 파이프라인 복구를 위해 부저 관련 로직을 조건부로 막아둔 상태였다.

이제 실제 하드웨어 연동 테스트를 할 때는 부저를 단계적으로 다시 켜야 한다.

⸻

현재 부저 관련 상태

## 1) src/config/settings.py

현재는 아래처럼 되어 있다.
```md
BUZZER_ENABLE = os.getenv("POSTURE_BUZZER_ENABLE", "0") == "1"
```
즉 기본값은 OFF 상태다. 

⸻

## 2) src/runtime/measurement_runtime.py

현재는 아래 구조로 되어 있어야 한다.
```md
buzzer = None
if BUZZER_ENABLE:
    from src.feedback.buzzer_feedback import BuzzerFeedback
    buzzer = BuzzerFeedback()
```
그리고 이후에도 이런 식으로 방어 코드가 들어가 있어야 한다. = 다 되어있다
```md
if buzzer:
    buzzer.reset()

if buzzer:
    buzzer.update(active_bad_postures)

finally:
    if buzzer:
        buzzer.close()
```
### 즉 현재는 BUZZER_ENABLE이 0이면 아예 import / 생성 / update / close가 실행되지 않음

⸻

# 부저를 다시 켜는 순서

## 단계 1. settings.py에서 부저 ON

파일:
- src/config/settings.py

현재:

`BUZZER_ENABLE = os.getenv("POSTURE_BUZZER_ENABLE", "0") == "1"`

실연동 테스트 시:
- 코드 기본값을 "1"로 바꾸거나
- 실행 시 환경변수로 POSTURE_BUZZER_ENABLE=1 주입

권장 방식:
`기본값은 그대로 두고, 실행 시 환경변수로만 ON 하는 것을 추천`

예:

`POSTURE_BUZZER_ENABLE=1 python main_real.py`

이 방식이 더 안전하다.

⸻

## 단계 2. measurement_runtime.py의 조건부 buzzer 코드 유지

중요:
- 현재 measurement_runtime.py에서 추가한 if buzzer: 가드들은 지우지 말 것
- 그 상태 그대로 두고 BUZZER_ENABLE=1일 때만 실제 활성화되게 해야 함

즉,
- buzzer = None
- if BUZZER_ENABLE: ...
- if buzzer: ...

이 구조는 유지해야 한다.

⸻

## 단계 3. requirements / gpiod 설치 확인

현재 requirements.txt에는 아마 아래처럼 주석 처리되어 있을 수 있다.
```md
# GPIO (Raspberry Pi only)
#gpiod; platform_system == "Linux"
```
### 실부저 테스트 전에 해야 할 일:
- Raspberry Pi 환경에서 gpiod import 가능 여부 확인
- 필요한 경우 수동 설치
- buzzer_feedback.py가 현재 사용하는 GPIO 라이브러리 기준으로 정상 import 확인

즉 부저 실험 전 체크 항목:
1.	python -c "import gpiod; print('ok')" 또는 현재 사용하는 라이브러리 import 확인
2.	buzzer_feedback.py 단독 테스트
3.	그 다음 main_real.py 전체 연동 테스트

⸻

## 단계 4. buzzer_feedback.py 단독 테스트 후 전체 연동

권장 순서:
1.	buzzer_feedback.py 단독 테스트
2.	GPIO line on/off 확인
3.	그 다음 main_real.py에 POSTURE_BUZZER_ENABLE=1로 연동 테스트

즉 바로 전체 시스템으로 가지 말고, 부저 모듈 단독 → 전체 연동 순서로 확인

⸻

# 📌 factor 관련 현재 판단

지금 가능한 것
- factor 적용 구조는 이미 완료
- 일부 센서 값으로 초안 factor 실험 가능
- scaffold 상태로 유지 가능

아직 어려운 것
- 최종 factor 수치 확정
- 이유: 의자가 아직 완성 전이라 최종 장착 위치/하중 분산/거리 배치가 고정되지 않음

따라서 현재 전략
- 구조는 유지
- 값은 임시값
- 최종 factor는 의자 완성 후 settings.py 숫자만 교체

⸻

✅ 지금 작업 우선순위
1. report_service.py에 llm 분기 추가
2. report_llm_service.py를 실제 llama.cpp 호출 구조로 교체
3. settings.py의 LLM 설정 정리
4. factor 값은 지금 당장 확정하지 말고 scaffold 유지
5. 부저는 전체 시스템이 안정된 뒤 POSTURE_BUZZER_ENABLE=1로 단계적 재활성화

⸻

