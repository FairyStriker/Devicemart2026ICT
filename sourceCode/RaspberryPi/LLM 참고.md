# LLM 인계 정리

## 1. 최종 목표로 잡아둔 방향

현재 LLM은 측정 종료 후 세션 리포트를 자연어로 생성하는 용도로 넣기로 정리된 상태다.
즉, 실시간 추론 루프 안에서 LLM을 돌리는 구조가 아니라, 세션 종료 후 생성된 structured summary를 입력으로 받아 최종 사용자용 리포트를 만드는 역할이다.

최종적으로 의도한 출력은 대략 이런 형태다.
```json
{
    "summary_text": "전체 평균 점수는 95.38점으로 우수 수준입니다. 주요 자세는 turtle_neck이며, 나쁜 자세 비율은 100.0%입니다.",
    "trend_text": "측정 전반에서 turtle_neck 자세가 지속되었습니다.",
    "exercise_recommendations": [
        "턱 당기기 스트레칭",
        "어깨 열기 스트레칭",
        "벽 자세 교정"
    ]
}
```

즉 LLM은 단순 채팅 응답이 아니라, 형식이 정해진 JSON성 결과를 반환해야 한다.

⸻

## 2. 모델/백엔드 방향

현재 잡아둔 방향은 다음과 같다.
- 로컬 실행
- Raspberry Pi에서 동작
- llama.cpp + GGUF 방식
- 모델은 Qwen 3.5 0.8B 계열을 올리는 방향으로 정리됨
- 다만 지금 단계에서는 실제 모델 호출까지 붙이기보다, mock / rule / llm 전환 가능한 구조를 먼저 만들어 둔 상태

즉 정리하면:
- OpenAI API 같은 외부 호출이 아니라
- 로컬 LLM inference
- 경량 모델
- llama.cpp 실행 경로 기반

이 최종 방향이다.

⸻

## 3. LLM이 맡는 역할 범위

현재 LLM이 맡기로 한 역할은 아래 3개다.
1.	세션 전체 요약
   - 평균 점수
   - 대표 자세
   - 나쁜 자세 비율 등 요약
2.	시간 흐름 분석
	- minute summary를 기반으로 자세가 어떻게 지속/변화했는지 설명
3.	운동 추천
	- 자세 유형에 따라 맞춤형 스트레칭/운동 추천

즉, 리포트는 최소한 아래 3축으로 구성된다.
- summary_text
- trend_text
- exercise_recommendations

⸻

## 4. 현재 코드 구조상 LLM이 들어가는 위치

현재 전체 리포트 생성 흐름은 이미 대략 잡혀 있다.

main_real.py
세션 종료 후 아래 흐름이 있음.
- overall_summary 생성
- minute_summary 생성
- report_service.build_enhanced_report(...) 호출

즉, LLM은 main_real.py에서 직접 호출하는 게 아니라 report_service.py를 통해 들어가도록 설계된 상태다.

⸻

## 5. 현재 잡혀 있는 틀

### A. src/report/report_generator.py
이 파일은 이미 structured summary를 만드는 역할을 한다.

현재 생성하는 핵심 데이터:
- overall_summary
- minute_summary

즉 LLM 입력으로 쓸 수 있는 기초 데이터는 이미 여기서 나온다.

⸻

### B. src/report/report_service.py
이 파일은 최종 리포트 생성 진입점이다.

현재 구조는 대략 이런 의도다.
- REPORT_ENGINE == "rule" 이면
- 기존 ReportEnhancer 사용
- 향후 REPORT_ENGINE == "llm" 이면
- ReportLLMService 사용

즉 이 파일은 리포트 엔진 스위치 역할을 하도록 이미 설계되어 있다.

현재는 rule 기반만 실제 연결되어 있고,
LLM 분기는 아직 완전히 연결되지 않은 상태다.

⸻

### C. src/llm/report_llm_service.py
이 파일은 이미 만들어져 있고, 지금은 mock 수준의 틀이 있다.

현재 의도는 대략 이렇다.
- generate_feedback(overall_summary, minute_summary) 형태
- dominant posture 기반으로 운동 추천 맵을 넣어둠
- 아직 실제 llama.cpp 호출은 없음
- 현재는 “LLM 붙이면 이런 형태로 반환할 것”이라는 구조만 마련된 상태

즉 이 파일은 현재 실제 모델 연동 전 placeholder / scaffold 역할이다.

⸻

### D. src/config/settings.py
LLM 관련 설정도 어느 정도 이미 잡혀 있다.

확인된 항목:
- REPORT_ENGINE
- LLM_REPORT_MODE
- LLM_MODEL_BACKEND
- LLM_GGUF_MODEL_PATH
- LLM_CONTEXT_LEN
- LLM_MAX_TOKENS
- LLM_TEMPERATURE

즉 설정 파일도 LLM-ready 상태로 틀은 마련되어 있다.

다만 현재는:
- 중복 선언 정리 필요
- 실제 경로/실행 모드 정리 필요
정도만 남아 있다.

⸻

## 6. 지금 시점에서 코드가 준비된 정도

한마디로 정리하면:

이미 준비된 것
- 리포트가 들어갈 최종 위치
- LLM이 받을 입력 데이터 구조
- LLM이 반환해야 할 출력 형식
- rule / llm 분기 가능한 서비스 구조
- llama.cpp / GGUF를 염두에 둔 설정 항목

아직 안 붙은 것
- 실제 llama.cpp 호출 코드
- GGUF 모델 로드 / 프롬프트 생성 / 결과 파싱
- report_service.py의 llm 분기 실연결

즉 현재 상태는:

LLM을 붙일 뼈대는 거의 준비됐고, 실제 호출 로직만 비어 있는 상태

라고 보면 된다.

⸻

## 7. 조원이 이어서 해야 할 핵심 작업

### 1) report_service.py
- REPORT_ENGINE == "llm" 분기 추가
- ReportLLMService 연결

### 2) report_llm_service.py
- mock 리턴 제거
- 프롬프트 생성
- llama.cpp 호출
- 모델 출력 파싱
- 아래 형식으로 반환
```json
{
    "summary_text": "...",
    "trend_text": "...",
    "exercise_recommendations": ["...", "...", "..."]
}
```
### 3) settings.py
- 중복된 LLM_REPORT_MODE 정리
- LLM_GGUF_MODEL_PATH 등 실제 경로 정리
- REPORT_ENGINE=llm 테스트 가능하게 정리

⸻

## 8. LLM 관련 설계 의도 요약

이 프로젝트에서 LLM은 실시간 자세 판별 엔진이 아니다.
실시간 판별은 기존의:
- sensor factor / feature extraction
- classifier
- rule-based posture 판단
- score 계산

이 담당한다.

LLM은 그 위에서 세션 종료 후 사용자 친화적 설명을 생성하는 리포트 레이어다.

즉 역할을 정확히 나누면:
- 실시간 추론: 기존 코드
- 최종 자연어 리포트: LLM

이 구조다.

