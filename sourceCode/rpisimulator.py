"""
fake_rpi_server.py
Flutter 앱 테스트용 가짜 RPi 서버
실행: python fake_rpi_server.py
주소: http://localhost:8000
"""

import json
import time
import random
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

# ─── 시스템 상태 ──────────────────────────────────────────────
state = {
    "stage": "uart_link_ready",
    "user_id": None,
    "user_name": None,
    "calibration_reason": None,
    "session_id": 1,
    "measuring": False,
    "paused": False,
    "sitting_sec": 0.0,
}

# ─── 실시간 자세 데이터 ───────────────────────────────────────
POSTURES = [
    "normal", "turtle_neck", "forward_lean",
    "reclined", "side_slouch", "thinking_pose",
]

realtime_data = {
    "posture": "normal",
    "score": 100.0,
    "alert": False,
    "alert_stage": 0,
    "loadcell_score": 95.0,
    "loadcell_level": "good",
    "spine_score": 15.0,
    "spine_level": "good",
    "neck_score": 25.0,
    "neck_level": "good",
}

# 분 단위 리포트 누적
minute_summaries = []
report_ready = False
overall_summary = None


# ─── 실시간 데이터 시뮬레이션 스레드 ─────────────────────────
def simulate_realtime():
    tick = 0
    while True:
        time.sleep(0.5)
        if not state["measuring"]:
            continue

        tick += 1
        state["sitting_sec"] += 0.5

        # 자세 랜덤 변화 (10초마다)
        if tick % 20 == 0:
            realtime_data["posture"] = random.choice(POSTURES)

        # 점수 변화
        if realtime_data["posture"] == "normal":
            realtime_data["score"] = min(100.0, realtime_data["score"] + 0.5)
        else:
            realtime_data["score"] = max(0.0, realtime_data["score"] - random.uniform(0.3, 1.2))

        score = realtime_data["score"]
        realtime_data["alert"] = score < 70
        realtime_data["alert_stage"] = 0 if score >= 70 else (1 if score >= 40 else 2)

        # 모니터링 지표
        realtime_data["loadcell_score"] = round(random.uniform(80, 99), 1)
        realtime_data["loadcell_level"] = _level(realtime_data["loadcell_score"], 85, 70)
        realtime_data["spine_score"] = round(random.uniform(5, 30), 1)
        realtime_data["spine_level"] = _level_inv(realtime_data["spine_score"], 15, 25)
        realtime_data["neck_score"] = round(random.uniform(10, 40), 1)
        realtime_data["neck_level"] = _level_inv(realtime_data["neck_score"], 20, 30)

        # 1분마다 minute_summary 추가
        if tick % 120 == 0:
            _add_minute_summary()

        # 자리 이탈 시뮬레이션 (5분마다)
        if tick % 600 == 0 and state["stage"] == "measuring":
            print("[SIM] STAND 이벤트 발생")
            state["stage"] = "wait_restart_decision"
            state["measuring"] = False


def _level(val, good_thresh, warn_thresh):
    if val >= good_thresh:
        return "good"
    if val >= warn_thresh:
        return "warning"
    return "danger"


def _level_inv(val, warn_thresh, danger_thresh):
    if val <= warn_thresh:
        return "good"
    if val <= danger_thresh:
        return "warning"
    return "danger"


def _add_minute_summary():
    minute_summaries.append({
        "type": "minute_summary",
        "user_id": state["user_id"] or "user_001",
        "session_id": state["session_id"],
        "minute_index": len(minute_summaries),
        "avg_score": round(realtime_data["score"], 1),
        "dominant_posture": realtime_data["posture"],
        "dominant_posture_ratio": round(random.uniform(10, 40), 2),
    })
    print(f"[SIM] minute_summary 추가: {len(minute_summaries)}분")


def _build_overall_summary():
    return {
        "type": "overall_summary",
        "user_id": state["user_id"] or "user_001",
        "session_id": state["session_id"],
        "avg_score": round(realtime_data["score"], 1),
        "total_sitting_sec": round(state["sitting_sec"], 2),
        "dominant_posture": "turtle_neck",
        "dominant_posture_ratio": 24.5,
        "posture_duration_sec": {
            "normal": round(state["sitting_sec"] * 0.3, 2),
            "turtle_neck": round(state["sitting_sec"] * 0.25, 2),
            "forward_lean": round(state["sitting_sec"] * 0.15, 2),
            "reclined": round(state["sitting_sec"] * 0.1, 2),
            "side_slouch": round(state["sitting_sec"] * 0.1, 2),
            "leg_cross_suspect": round(state["sitting_sec"] * 0.05, 2),
            "thinking_pose": round(state["sitting_sec"] * 0.03, 2),
            "perching": round(state["sitting_sec"] * 0.02, 2),
        },
    }


# ─── HTTP 핸들러 ──────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        print(f"[HTTP] {self.address_string()} {format % args}")

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    # ─── GET ──────────────────────────────────────────────────
    def do_GET(self):
        if self.path == "/meta":
            self._send_json(self._build_meta())

        elif self.path == "/status":
            self._send_json(self._build_status())

        elif self.path == "/report":
            self._send_json(self._build_report())

        else:
            self._send_json({"error": "not_found"}, 404)

    def _build_meta(self):
        meta = {
            "type": "meta",
            "stage": state["stage"],
            "timestamp": int(time.time()),
        }
        if state["user_id"]:
            meta["user_id"] = state["user_id"]
            meta["user_name"] = state["user_name"]
        if state["calibration_reason"]:
            meta["calibration_reason"] = state["calibration_reason"]
        return meta

    def _build_status(self):
        # STAND 이벤트 상태면 stand_event 반환
        if state["stage"] == "wait_restart_decision":
            return {
                "type": "stand_event",
                "user_id": state["user_id"] or "user_001",
                "timestamp": int(time.time()),
                "message": "사용자가 자리에서 일어났습니다. 측정을 재시작 하시겠습니까?",
                "actions": {
                    "resume": "resume_after_stand",
                    "stop": "decline_resume_after_stand",
                },
            }

        if not state["measuring"]:
            return {"type": "idle"}

        flags = {p: (p == realtime_data["posture"]) for p in [
            "turtle_neck", "forward_lean", "reclined",
            "side_slouch", "leg_cross_suspect", "thinking_pose",
            "perching", "normal",
        ]}

        return {
            "type": "realtime_status",
            "user_id": state["user_id"] or "user_001",
            "timestamp": int(time.time()),
            "posture": {
                "dominant": realtime_data["posture"],
                "flags": flags,
            },
            "score": {
                "current": round(realtime_data["score"], 1),
                "alert": realtime_data["alert"],
                "alert_stage": realtime_data["alert_stage"],
            },
            "monitoring": {
                "loadcell": {
                    "balance_score": realtime_data["loadcell_score"],
                    "balance_level": realtime_data["loadcell_level"],
                },
                "spine_tof": {
                    "score": realtime_data["spine_score"],
                    "level": realtime_data["spine_level"],
                },
                "neck_tof": {
                    "score": realtime_data["neck_score"],
                    "level": realtime_data["neck_level"],
                },
            },
        }

    def _build_report(self):
        if overall_summary:
            return overall_summary
        if minute_summaries:
            return minute_summaries[-1]
        return {"type": "no_report"}

    # ─── POST /command ────────────────────────────────────────
    def do_POST(self):
        if self.path != "/command":
            self._send_json({"ok": False, "message": "not_found"}, 404)
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            cmd = json.loads(body)
        except Exception:
            self._send_json({"ok": False, "message": "invalid_json"})
            return

        result = self._handle_command(cmd)
        self._send_json(result)

    def _handle_command(self, cmd):
        command = cmd.get("cmd", "")
        print(f"[CMD] {command} | stage={state['stage']}")

        # ─── 신규 프로필 등록 ──────────────────────────────────
        if command == "submit_profile":
            state["user_id"] = cmd.get("user_id", "user_001")
            state["user_name"] = cmd.get("name", "사용자")
            state["stage"] = "profile_loaded"
            print(f"  → 프로필 등록: {state['user_name']} ({state['user_id']})")
            # 1초 후 자동으로 캘리브레이션 결정 단계로 이동
            threading.Timer(1.0, lambda: state.update({"stage": "wait_calibration_decision"})).start()
            return {"ok": True, "message": "profile_loaded"}

        # ─── 기존 프로필 선택 ──────────────────────────────────
        elif command == "select_profile":
            state["user_id"] = cmd.get("user_id", "user_001")
            state["user_name"] = "기존사용자"
            state["stage"] = "profile_loaded"
            threading.Timer(1.0, lambda: state.update({"stage": "wait_calibration_decision"})).start()
            return {"ok": True, "message": "profile_loaded"}

        # ─── 캘리브레이션 시작 ─────────────────────────────────
        elif command == "start_calibration":
            state["stage"] = "wait_sit_for_calibration"
            state["calibration_reason"] = "initial"
            # 3초 후 자동으로 calibrating → calibration_completed
            threading.Timer(2.0, _auto_calibrate).start()
            return {"ok": True, "message": "calibration_starting"}

        # ─── 캘리브레이션 생략 ─────────────────────────────────
        elif command == "skip_calibration":
            state["stage"] = "wait_start_decision"
            return {"ok": True, "message": "calibration_skipped"}

        # ─── 측정 시작 ─────────────────────────────────────────
        elif command == "start_measurement":
            state["stage"] = "wait_sit_for_measure"
            # 2초 후 자동으로 measuring
            threading.Timer(2.0, _auto_start_measuring).start()
            return {"ok": True, "message": "measurement_starting"}

        # ─── 일시정지 ──────────────────────────────────────────
        elif command == "pause_measurement":
            state["measuring"] = False
            state["stage"] = "paused"
            return {"ok": True, "message": "paused"}

        # ─── 재개 ──────────────────────────────────────────────
        elif command == "resume_measurement":
            state["stage"] = "wait_sit_for_measure"
            threading.Timer(1.5, _auto_start_measuring).start()
            return {"ok": True, "message": "resumed"}

        # ─── 측정 종료 ─────────────────────────────────────────
        elif command == "quit_measurement":
            state["measuring"] = False
            state["stage"] = "session_saved"
            global overall_summary
            overall_summary = _build_overall_summary()
            print("[SIM] 세션 종료 → session_saved")
            return {"ok": True, "message": "session_saved"}

        # ─── 재캘리브레이션 요청 ───────────────────────────────
        elif command == "request_recalibration":
            state["measuring"] = False
            state["stage"] = "wait_sit_for_calibration"
            state["calibration_reason"] = "recalibration"
            threading.Timer(2.0, _auto_calibrate).start()
            return {"ok": True, "message": "recalibration_starting"}

        # ─── STAND 후 재시작 ───────────────────────────────────
        elif command == "resume_after_stand":
            state["stage"] = "wait_sit_for_measure"
            threading.Timer(1.5, _auto_start_measuring).start()
            return {"ok": True, "message": "resume_after_stand"}

        # ─── STAND 후 종료 ─────────────────────────────────────
        elif command == "decline_resume_after_stand":
            state["measuring"] = False
            state["stage"] = "session_saved"
            overall_summary = _build_overall_summary()
            return {"ok": True, "message": "session_saved"}

        return {"ok": False, "message": f"unknown_command:{command}"}


# ─── 자동 진행 헬퍼 ──────────────────────────────────────────
def _auto_calibrate():
    print("[SIM] 캘리브레이션 시작...")
    state["stage"] = "calibrating"
    time.sleep(3)
    state["stage"] = "calibration_completed"
    state["calibration_reason"] = None
    print("[SIM] 캘리브레이션 완료")


def _auto_start_measuring():
    print("[SIM] 착석 감지 → 측정 시작")
    state["stage"] = "measuring"
    state["measuring"] = True


# ─── 메인 ────────────────────────────────────────────────────
if __name__ == "__main__":
    sim_thread = threading.Thread(target=simulate_realtime, daemon=True)
    sim_thread.start()

    server = HTTPServer(("0.0.0.0", 8000), Handler)
    print("=" * 50)
    print("  가짜 RPi 서버 실행 중")
    print("  주소: http://localhost:8000")
    print("  Flutter 앱 IP 입력: 127.0.0.1")
    print("=" * 50)
    print()
    print("  stage 흐름:")
    print("  uart_link_ready → profile_loaded")
    print("  → calibration_completed → measuring")
    print("  → (5분 후 stand 이벤트)")
    print("  → session_saved")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료")
