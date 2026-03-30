# src/report/llm_report_engine.py

import json
import time
from typing import Any, Dict, List

from src.config.settings import (
    LLM_REPORT_MODE,
    LLM_MODEL_BACKEND,
    LLM_GGUF_MODEL_PATH,
    LLM_CONTEXT_LEN,
    LLM_MAX_TOKENS,
    LLM_TEMPERATURE,
)

# 자세 한국어 라벨
POSTURE_LABEL_KR = {
    "turtle_neck": "거북목 성향",
    "forward_lean": "몸통 전방 기울어짐",
    "side_slouch": "좌우 비대칭 기울어짐",
    "leg_cross_suspect": "하체 좌우 불균형 의심",
    "thinking_pose": "책상 앞 숙임 자세",
    "reclined": "뒤로 기대는 자세",
    "perching": "의자 끝에 걸터앉은 자세",
    "normal": "비교적 안정적인 자세",
}


class LLMReportEngine:
    """
    llama-cpp-python 기반 LLM 리포트 엔진.

    - LLM_REPORT_MODE=mock: 실제 모델 호출 없이 rule-based 응답
    - LLM_REPORT_MODE=live: Qwen GGUF 모델로 실제 AI 리포트 생성
    """

    def __init__(self):
        self.model = None
        if LLM_REPORT_MODE == "live":
            self._load_model()

    def _load_model(self):
        try:
            from llama_cpp import Llama

            if not LLM_GGUF_MODEL_PATH:
                print("[LLM] ERROR: LLM_GGUF_MODEL_PATH is empty")
                return

            print(f"[LLM] Loading model: {LLM_GGUF_MODEL_PATH} ...")
            load_start = time.time()

            self.model = Llama(
                model_path=LLM_GGUF_MODEL_PATH,
                n_ctx=LLM_CONTEXT_LEN,
                n_threads=4,
                verbose=False,
            )

            elapsed = time.time() - load_start
            print(f"[LLM] Model loaded in {elapsed:.1f}s")

        except ImportError:
            print("[LLM] llama-cpp-python not installed. Run: pip install llama-cpp-python")
            self.model = None
        except Exception as e:
            print(f"[LLM] Model load failed: {e}")
            self.model = None

    def build_enhanced_report(
        self,
        overall_summary: Dict[str, Any],
        minute_summary: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        prompt = self._build_prompt(
            overall_summary=overall_summary,
            minute_summary=minute_summary,
        )

        print("[LLM] Generating report...")
        gen_start = time.time()

        raw_output = self._call_model(prompt)

        elapsed = time.time() - gen_start
        print(f"[LLM] Report generated in {elapsed:.1f}s")

        parsed = self._parse_output(raw_output, overall_summary)
        return parsed

    def _build_prompt(
        self,
        overall_summary: Dict[str, Any],
        minute_summary: List[Dict[str, Any]],
    ) -> str:
        overall_json = json.dumps(overall_summary, ensure_ascii=False, indent=2)
        minute_json = json.dumps(minute_summary, ensure_ascii=False, indent=2)

        return f"""You are a posture correction expert.

Analyze the user's posture report data and generate structured feedback.

[INPUT]
overall_summary:
{overall_json}

minute_summary:
{minute_json}

[LABEL GUIDE]
- turtle_neck: 거북목 성향
- forward_lean: 몸통 전방 기울어짐
- side_slouch: 좌우 비대칭 기울어짐
- leg_cross_suspect: 하체 좌우 불균형 의심
- thinking_pose: 책상 앞 숙임 자세
- reclined: 뒤로 기대는 자세
- perching: 의자 끝에 걸터앉은 자세
- normal: 비교적 안정적인 자세

[RULES]
- Answer in Korean.
- Use only the provided posture data.
- Do not diagnose diseases or medical conditions.
- Focus only on posture tendency, sitting habit, and practical correction advice.
- Recommend exactly 3 exercises.
- Keep the response concise and practical.
- Output valid JSON only.
- Do not include markdown, bullet points, or extra explanation.

[OUTPUT FORMAT]
{{
  "posture_analysis": "string",
  "trend_analysis": "string",
  "exercise_recommendations": [
    "string",
    "string",
    "string"
  ],
  "summary": "string"
}}
"""

    def _call_model(self, prompt: str) -> str:
        if LLM_REPORT_MODE == "mock":
            return self._mock_response(prompt)

        if LLM_REPORT_MODE == "live":
            return self._call_llama_cpp_python(prompt)

        raise ValueError(f"Unsupported LLM report mode: {LLM_REPORT_MODE}")

    def _call_llama_cpp_python(self, prompt: str) -> str:
        if self.model is None:
            print("[LLM] Model not loaded, falling back to mock")
            return self._mock_response(prompt)

        try:
            output = self.model(
                prompt,
                max_tokens=LLM_MAX_TOKENS,
                temperature=LLM_TEMPERATURE,
                stop=["}\n\n", "```", "\n\n\n"],
            )

            text = output["choices"][0]["text"].strip()

            # JSON이 }로 끝나지 않으면 닫아줌
            if text and not text.rstrip().endswith("}"):
                text = text.rstrip() + "}"

            print(f"[LLM] Raw output length: {len(text)} chars")
            return text

        except Exception as e:
            print(f"[LLM] Inference failed: {e}")
            return self._mock_response(prompt)

    def _mock_response(self, prompt: str) -> str:
        return json.dumps(
            {
                "posture_analysis": "전체 평균 점수는 양호하며, 주요 자세 경향이 관찰되었습니다.",
                "trend_analysis": "측정 전반에서 특정 자세가 비교적 지속적으로 관찰되었습니다.",
                "exercise_recommendations": [
                    "턱 당기기 스트레칭 (chin tuck)",
                    "어깨 열기 스트레칭",
                    "벽 기대 자세 교정",
                ],
                "summary": "자세 패턴이 확인되어 생활 습관 교정이 권장됩니다.",
            },
            ensure_ascii=False,
        )

    def _parse_output(
        self, raw_output: str, overall_summary: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        overall_summary = overall_summary or {}
        posture = overall_summary.get("dominant_posture", "normal")
        posture_kr = POSTURE_LABEL_KR.get(posture, posture)

        # JSON 추출 시도 (LLM이 앞뒤에 텍스트를 붙일 수 있으므로)
        parsed_data = None
        try:
            parsed_data = json.loads(raw_output)
        except json.JSONDecodeError:
            # { 부터 마지막 } 까지 추출 시도
            start = raw_output.find("{")
            end = raw_output.rfind("}")
            if start != -1 and end != -1 and end > start:
                try:
                    parsed_data = json.loads(raw_output[start : end + 1])
                except json.JSONDecodeError:
                    pass

        if parsed_data is None:
            print("[LLM] JSON parsing failed, using rule-based fallback")
            return self._rule_based_fallback(overall_summary)

        # 필드 추출 (posture_analysis/summary_text 둘 다 허용)
        posture_analysis = str(
            parsed_data.get("posture_analysis", parsed_data.get("summary_text", ""))
        ).strip()
        trend_analysis = str(
            parsed_data.get("trend_analysis", parsed_data.get("trend_text", ""))
        ).strip()
        summary = str(parsed_data.get("summary", "")).strip()
        exercises = parsed_data.get("exercise_recommendations", [])

        if not isinstance(exercises, list):
            exercises = []
        exercises = [str(x).strip() for x in exercises if str(x).strip()][:3]

        while len(exercises) < 3:
            exercises.append("바른 자세 재정렬")

        if not posture_analysis:
            posture_analysis = f"주요 자세는 {posture_kr}이며, 자세 데이터 분석이 완료되었습니다."
        if not trend_analysis:
            trend_analysis = "시간 흐름에 따른 자세 변화 추이가 확인되었습니다."
        if not summary:
            summary = f"{posture_kr} 중심의 자세 패턴이 확인되어 생활 습관 교정이 권장됩니다."

        return {
            "summary_text": posture_analysis,
            "trend_text": trend_analysis,
            "exercise_recommendations": exercises,
            "summary": summary,
        }

    def _rule_based_fallback(self, overall_summary: Dict[str, Any]) -> Dict[str, Any]:
        posture = overall_summary.get("dominant_posture", "normal")
        posture_kr = POSTURE_LABEL_KR.get(posture, posture)
        avg_score = overall_summary.get("avg_score", 0)
        bad_ratio = overall_summary.get("bad_posture_ratio", 0)

        exercise_map = {
            "turtle_neck": ["목 뒤 스트레칭 (chin tuck)", "어깨 열기 스트레칭", "벽 기대 자세 교정"],
            "forward_lean": ["허리 신전 스트레칭", "코어 강화 플랭크", "고관절 펴기 스트레칭"],
            "side_slouch": ["좌우 균형 스트레칭", "측면 코어 운동", "골반 정렬 스트레칭"],
            "leg_cross_suspect": ["고관절 좌우 밸런스 스트레칭", "골반 정렬 운동", "햄스트링 이완 스트레칭"],
            "thinking_pose": ["목-등 상부 스트레칭", "어깨 후인 자세 연습", "흉추 가동성 운동"],
            "reclined": ["골반 세우기 연습", "복부 긴장 유지 운동", "허리 중립자세 연습"],
            "perching": ["엉덩이 깊게 앉기 연습", "코어 브레이싱 운동", "고관절 안정화 운동"],
        }

        exercises = exercise_map.get(posture, ["목 스트레칭", "어깨 스트레칭", "골반 정렬 운동"])

        return {
            "summary_text": f"평균 점수 {avg_score:.1f}점, 주요 자세는 {posture_kr}입니다. 나쁜 자세 비율 {bad_ratio:.0%}로 교정이 필요합니다.",
            "trend_text": f"측정 중 {posture_kr}이(가) 반복적으로 관찰되었습니다.",
            "exercise_recommendations": exercises,
            "summary": f"{posture_kr} 중심의 자세 패턴이 확인되어 생활 습관 교정이 필요합니다.",
        }
