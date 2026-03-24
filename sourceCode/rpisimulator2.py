#!/usr/bin/env python3
"""
SPCC Fake RPi Server (Protocol v2)

Flutter 앱 테스트용 가짜 라즈베리파이 서버.
- HTTP POST /command : 앱 명령 수신
- HTTP GET  /meta    : 초기 연결 확인
- WebSocket /ws      : 6종 payload push

실행:
  pip install aiohttp
  python fake_rpi_server.py

기본 포트: 8000 (RPi 실서버와 동일)
"""

import asyncio
import json
import math
import random
import time
from aiohttp import web

# ══════════════════════════════════════════════════════
# Stage 상수
# ══════════════════════════════════════════════════════

STAGES_AUTO_ADVANCE = {
    "boot":                       "uart_link_ready",
    "uart_link_ready":            "wait_profile",
    "profile_loaded":             "wait_calibration_decision",
    "wait_sit_for_calibration":   "calibrating",
    "calibrating":                "calibration_completed",
    "wait_sit_for_measure":       "measuring",
    "measurement_stop_requested": "session_saved",
    "session_saved":              "session_ended",
}

POSTURES = [
    "normal", "turtle_neck", "forward_lean", "reclined",
    "side_slouch", "leg_cross_suspect", "thinking_pose", "perching",
]

POSTURE_KO = {
    "normal": "정자세", "turtle_neck": "거북목",
    "forward_lean": "상체 굽힘", "reclined": "누워 앉기",
    "side_slouch": "새우 자세", "leg_cross_suspect": "다리 꼬기",
    "thinking_pose": "생각하는 사람 자세", "perching": "걸터앉기",
}


# ══════════════════════════════════════════════════════
# 서버 상태
# ══════════════════════════════════════════════════════

class ServerState:
    def __init__(self):
        self.stage = "boot"
        self.user_id = None
        self.user_name = None
        self.session_id = 0
        self.minute_index = 0
        self.measure_start = None
        self.calibrated = False
        self.ws_clients: list[web.WebSocketResponse] = []
        self._tick = 0

    def reset_session(self):
        self.minute_index = 0
        self.measure_start = None

    # ── command 처리 ─────────────────────────────────
    def handle_command(self, body: dict) -> dict:
        cmd = body.get("cmd")
        if not cmd:
            return {"ok": False, "message": "invalid_command"}

        handler = getattr(self, f"_cmd_{cmd}", None)
        if handler is None:
            return {"ok": False, "message": "invalid_command"}

        result = handler(body)
        return result

    # ── 개별 command 핸들러 ──────────────────────────

    def _cmd_submit_profile(self, body):
        if self.stage != "wait_profile":
            return {"ok": False, "message": f"invalid_stage: submit_profile not allowed at '{self.stage}'"}
        self.user_id = body.get("user_id", "user_001")
        self.user_name = body.get("name", "unknown")
        self.stage = "profile_loaded"
        return {"ok": True, "message": "command_received"}

    def _cmd_select_profile(self, body):
        if self.stage != "wait_profile":
            return {"ok": False, "message": f"invalid_stage: select_profile not allowed at '{self.stage}'"}
        self.user_id = body.get("user_id", "user_001")
        self.user_name = "기존 사용자"
        self.stage = "profile_loaded"
        return {"ok": True, "message": "command_received"}

    def _cmd_start_calibration(self, body):
        if self.stage not in ("wait_calibration_decision", "paused"):
            return {"ok": False, "message": f"invalid_stage: start_calibration not allowed at '{self.stage}'"}
        self.stage = "wait_sit_for_calibration"
        return {"ok": True, "message": "command_received"}

    def _cmd_skip_calibration(self, body):
        if self.stage != "wait_calibration_decision":
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "wait_start_decision"
        return {"ok": True, "message": "command_received"}

    def _cmd_start_measurement(self, body):
        if self.stage not in ("calibration_completed", "wait_start_decision"):
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "wait_sit_for_measure"
        self.session_id += 1
        self.minute_index = 0
        self.measure_start = time.time()
        return {"ok": True, "message": "command_received"}

    def _cmd_pause_measurement(self, body):
        if self.stage != "measuring":
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "paused"
        return {"ok": True, "message": "command_received"}

    def _cmd_resume_measurement(self, body):
        if self.stage != "paused":
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "measuring"
        return {"ok": True, "message": "command_received"}

    def _cmd_quit_measurement(self, body):
        if self.stage not in ("measuring", "paused", "wait_start_decision"):
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "measurement_stop_requested"
        return {"ok": True, "message": "command_received"}

    def _cmd_request_recalibration(self, body):
        if self.stage not in ("measuring", "paused", "wait_start_decision"):
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "wait_sit_for_calibration"
        return {"ok": True, "message": "command_received"}

    def _cmd_resume_after_stand(self, body):
        if self.stage != "wait_restart_decision":
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "measuring"
        return {"ok": True, "message": "command_received"}

    def _cmd_decline_resume_after_stand(self, body):
        if self.stage != "wait_restart_decision":
            return {"ok": False, "message": f"invalid_stage"}
        self.stage = "measurement_stop_requested"
        return {"ok": True, "message": "command_received"}

    # ── 데이터 생성 ─────────────────────────────────

    def build_meta(self) -> dict:
        d = {
            "type": "meta",
            "stage": self.stage,
            "timestamp": int(time.time()),
        }
        if self.user_id:
            d["user_id"] = self.user_id
            d["user_name"] = self.user_name
        return d

    def build_realtime_status(self) -> dict:
        self._tick += 1
        t = self._tick * 0.5

        # 시간에 따라 자세 변화 시뮬레이션
        phase = int(t / 8) % len(POSTURES)
        dominant = POSTURES[phase]
        flags = {p: (p == dominant or random.random() < 0.15) for p in POSTURES}
        flags["normal"] = dominant == "normal"

        score = max(30, min(100, 75 + 15 * math.sin(t * 0.3) + random.gauss(0, 5)))

        def sensor_val(base, var=15):
            return max(0, min(100, base + random.gauss(0, var)))

        def level(v):
            if v >= 70: return "good"
            if v >= 40: return "warning"
            return "danger"

        # 등판 좌측 (기본 65) / 우측 (기본 55) - 좌우 차이 시뮬
        lt = sensor_val(65, 10)
        lum = sensor_val(68, 10)
        llm = sensor_val(66, 10)
        lb = sensor_val(62, 10)
        rt = sensor_val(55, 12)
        rum = sensor_val(52, 12)
        rlm = sensor_val(50, 12)
        rb = sensor_val(48, 12)

        # 좌석
        rl = sensor_val(80, 8)
        rr = sensor_val(75, 8)
        fl = sensor_val(60, 10)
        fr = sensor_val(58, 10)

        # 척추 ToF (거리 기반 — 정자세에서 낮은 값)
        tof_base = 20 if dominant == "forward_lean" else 45
        su = sensor_val(tof_base + 10, 8)
        sum_ = sensor_val(tof_base, 8)
        slm = sensor_val(tof_base - 5, 8)
        sl = sensor_val(tof_base + 5, 8)

        # 목 ToF
        neck_base = 10 if dominant == "turtle_neck" else 60
        neck_pct = sensor_val(neck_base, 12)

        # 집계 점수
        bal_vals = [lt, lum, llm, lb, rt, rum, rlm, rb]
        left_avg = sum(bal_vals[:4]) / 4
        right_avg = sum(bal_vals[4:]) / 4
        balance = max(0, 100 - abs(left_avg - right_avg) * 2)

        spine_score = (su + sum_ + slm + sl) / 4

        return {
            "type": "realtime_status",
            "user_id": self.user_id or "",
            "timestamp": int(time.time()),
            "posture": {
                "dominant": dominant,
                "flags": flags,
            },
            "score": {
                "current": round(score, 1),
                "alert": score < 50,
                "alert_stage": 2 if score < 30 else (1 if score < 50 else 0),
            },
            "monitoring": {
                "loadcell": {
                    "balance_score": round(balance, 1),
                    "balance_level": level(balance),
                },
                "spine_tof": {
                    "score": round(spine_score, 1),
                    "level": level(spine_score),
                },
                "neck_tof": {
                    "score": round(neck_pct, 1),
                    "level": level(neck_pct),
                },
            },
            "back_pressure": {
                "left_top": round(lt, 1),
                "left_upper_mid": round(lum, 1),
                "left_lower_mid": round(llm, 1),
                "left_bottom": round(lb, 1),
                "right_top": round(rt, 1),
                "right_upper_mid": round(rum, 1),
                "right_lower_mid": round(rlm, 1),
                "right_bottom": round(rb, 1),
            },
            "seat_pressure": {
                "rear_left": round(rl, 1),
                "rear_right": round(rr, 1),
                "front_left": round(fl, 1),
                "front_right": round(fr, 1),
            },
            "spine_tof": {
                "upper": round(su, 1),
                "upper_mid": round(sum_, 1),
                "lower_mid": round(slm, 1),
                "lower": round(sl, 1),
            },
            "head_tof": {
                "overall": {
                    "percent": round(neck_pct, 1),
                }
            },
        }

    def build_minute_summary(self) -> dict:
        idx = self.minute_index
        self.minute_index += 1
        dominant = random.choice(POSTURES)
        return {
            "type": "minute_summary",
            "user_id": self.user_id or "",
            "session_id": self.session_id,
            "minute_index": idx,
            "avg_score": round(random.uniform(60, 95), 1),
            "dominant_posture": dominant,
            "dominant_posture_ratio": round(random.uniform(10, 40), 1),
        }

    def build_overall_summary(self) -> dict:
        elapsed = time.time() - self.measure_start if self.measure_start else 0
        dur = {}
        remaining = elapsed
        for p in POSTURES[:-1]:
            d = random.uniform(0, remaining / (len(POSTURES) - len(dur)))
            dur[p] = round(d, 2)
            remaining -= d
        dur[POSTURES[-1]] = round(max(0, remaining), 2)

        dominant = max(dur, key=dur.get)
        total = sum(dur.values())
        ratio = (dur[dominant] / total * 100) if total > 0 else 0

        return {
            "type": "overall_summary",
            "user_id": self.user_id or "",
            "session_id": self.session_id,
            "avg_score": round(random.uniform(65, 90), 1),
            "total_sitting_sec": round(elapsed, 2),
            "dominant_posture": dominant,
            "dominant_posture_ratio": round(ratio, 1),
            "posture_duration_sec": dur,
        }

    def build_enhanced_report(self) -> dict:
        return {
            "type": "enhanced_report",
            "user_id": self.user_id or "",
            "session_id": str(self.session_id),
            "data": {
                "summary": "시뮬레이션 세션 분석 결과",
                "recommendations": [
                    "허리를 펴고 앉는 습관을 기르세요",
                    "50분마다 스트레칭을 하세요",
                ],
                "posture_transitions": random.randint(5, 30),
                "longest_good_streak_sec": round(random.uniform(30, 300), 1),
            },
        }

    def build_stand_event(self) -> dict:
        return {
            "type": "stand_event",
            "user_id": self.user_id or "",
            "timestamp": int(time.time()),
            "message": "사용자가 자리에서 일어났습니다. 측정을 재시작 하시겠습니까?",
            "actions": {
                "resume": "resume_after_stand",
                "stop": "decline_resume_after_stand",
            },
        }


# ══════════════════════════════════════════════════════
# WebSocket broadcast
# ══════════════════════════════════════════════════════

async def broadcast(state: ServerState, data: dict):
    msg = json.dumps(data, ensure_ascii=False)
    dead = []
    for ws in state.ws_clients:
        try:
            await ws.send_str(msg)
        except Exception:
            dead.append(ws)
    for ws in dead:
        state.ws_clients.remove(ws)


# ══════════════════════════════════════════════════════
# 백그라운드 루프 (데이터 push + auto-advance)
# ══════════════════════════════════════════════════════

async def background_loop(state: ServerState):
    """0.5초 주기로 데이터 push + stage auto-advance"""
    prev_stage = state.stage
    auto_delay = 0  # auto-advance 지연 카운터

    while True:
        await asyncio.sleep(0.5)

        # ── auto-advance (2초 지연) ──────────────────
        if state.stage in STAGES_AUTO_ADVANCE:
            auto_delay += 1
            if auto_delay >= 4:  # 2초(0.5*4)
                next_stage = STAGES_AUTO_ADVANCE[state.stage]
                print(f"  [AUTO] {state.stage} → {next_stage}")
                state.stage = next_stage
                auto_delay = 0
        else:
            auto_delay = 0

        # ── stage 변경 시 meta push ──────────────────
        if state.stage != prev_stage:
            await broadcast(state, state.build_meta())
            print(f"  [META] stage={state.stage}")

            # session_saved → 리포트 데이터 push
            if state.stage == "session_saved":
                await asyncio.sleep(0.3)
                await broadcast(state, state.build_overall_summary())
                print("  [PUSH] overall_summary")
                await asyncio.sleep(0.2)
                await broadcast(state, state.build_enhanced_report())
                print("  [PUSH] enhanced_report")
                # 분별 요약 (쌓인 만큼)
                for i in range(state.minute_index):
                    pass  # 이미 measuring 중에 push됨

            prev_stage = state.stage

        # ── measuring 중 실시간 데이터 ───────────────
        if state.stage == "measuring":
            status = state.build_realtime_status()
            await broadcast(state, status)

            # 60초마다 minute_summary
            if state.measure_start:
                elapsed = time.time() - state.measure_start
                expected_minutes = int(elapsed / 60)
                if expected_minutes > 0 and state.minute_index < expected_minutes:
                    summary = state.build_minute_summary()
                    await broadcast(state, summary)
                    print(f"  [PUSH] minute_summary #{summary['minute_index']}")

            # 랜덤 stand event (약 2% 확률, ~1분에 1번 정도)
            if random.random() < 0.02:
                state.stage = "wait_restart_decision"
                await broadcast(state, state.build_stand_event())
                await broadcast(state, state.build_meta())
                print("  [EVENT] stand_event → wait_restart_decision")
                prev_stage = state.stage


# ══════════════════════════════════════════════════════
# HTTP 핸들러
# ══════════════════════════════════════════════════════

async def handle_meta(request):
    state: ServerState = request.app["state"]
    return web.json_response(state.build_meta())


async def handle_command(request):
    state: ServerState = request.app["state"]
    try:
        body = await request.json()
    except Exception:
        return web.json_response(
            {"ok": False, "message": "invalid_json"}, status=400
        )

    cmd = body.get("cmd", "?")
    result = state.handle_command(body)

    status_icon = "✓" if result["ok"] else "✗"
    print(f"  [CMD] {status_icon} {cmd} → stage={state.stage}")

    # command 처리 후 즉시 meta broadcast
    if result["ok"]:
        await broadcast(state, state.build_meta())

    return web.json_response(result)


async def handle_websocket(request):
    state: ServerState = request.app["state"]
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    state.ws_clients.append(ws)
    peer = request.remote
    print(f"  [WS] 클라이언트 연결: {peer} (총 {len(state.ws_clients)})")

    # 연결 직후 현재 meta 전송
    await ws.send_str(json.dumps(state.build_meta(), ensure_ascii=False))

    try:
        async for msg in ws:
            pass  # 클라이언트→서버 WS 메시지는 무시 (command는 HTTP)
    finally:
        if ws in state.ws_clients:
            state.ws_clients.remove(ws)
        print(f"  [WS] 클라이언트 해제: {peer} (총 {len(state.ws_clients)})")

    return ws


# ══════════════════════════════════════════════════════
# 터미널 제어 (키보드 입력)
# ══════════════════════════════════════════════════════

async def terminal_control(state: ServerState):
    """터미널에서 명령 입력으로 서버 제어"""
    loop = asyncio.get_event_loop()

    print("\n" + "=" * 50)
    print("  SPCC Fake RPi Server — 터미널 명령어")
    print("=" * 50)
    print("  s : STAND 이벤트 발생 (measuring 중)")
    print("  r : stage 리셋 (boot부터 재시작)")
    print("  m : 현재 상태 출력")
    print("  q : 서버 종료")
    print("=" * 50 + "\n")

    while True:
        try:
            line = await loop.run_in_executor(None, input, "")
        except (EOFError, KeyboardInterrupt):
            break

        line = line.strip().lower()

        if line == "s":
            if state.stage == "measuring":
                state.stage = "wait_restart_decision"
                await broadcast(state, state.build_stand_event())
                await broadcast(state, state.build_meta())
                print("  [MANUAL] stand_event 발생")
            else:
                print(f"  [MANUAL] measuring 상태가 아닙니다 (현재: {state.stage})")

        elif line == "r":
            state.stage = "boot"
            state.user_id = None
            state.user_name = None
            state.reset_session()
            await broadcast(state, state.build_meta())
            print("  [MANUAL] 서버 상태 리셋 → boot")

        elif line == "m":
            print(f"\n  stage      : {state.stage}")
            print(f"  user_id    : {state.user_id}")
            print(f"  session_id : {state.session_id}")
            print(f"  ws_clients : {len(state.ws_clients)}")
            if state.measure_start:
                elapsed = time.time() - state.measure_start
                print(f"  elapsed    : {elapsed:.1f}s")
            print()

        elif line == "q":
            print("  서버 종료")
            raise SystemExit(0)


# ══════════════════════════════════════════════════════
# 앱 시작
# ══════════════════════════════════════════════════════

async def on_startup(app):
    state = app["state"]
    app["bg_task"] = asyncio.create_task(background_loop(state))
    app["terminal_task"] = asyncio.create_task(terminal_control(state))


async def on_cleanup(app):
    app["bg_task"].cancel()
    app["terminal_task"].cancel()


def main():
    state = ServerState()

    app = web.Application()
    app["state"] = state

    # CORS 허용 미들웨어
    @web.middleware
    async def cors_middleware(request, handler):
        if request.method == "OPTIONS":
            resp = web.Response()
        else:
            resp = await handler(request)
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        return resp

    app.middlewares.append(cors_middleware)

    app.router.add_get("/meta", handle_meta)
    app.router.add_post("/command", handle_command)
    app.router.add_get("/ws", handle_websocket)

    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)

    host = "0.0.0.0"
    port = 8000

    print()
    print("╔══════════════════════════════════════════════╗")
    print("║     SPCC Fake RPi Server (Protocol v2)      ║")
    print("╠══════════════════════════════════════════════╣")
    print(f"║  HTTP  : http://{host}:{port}                 ║")
    print(f"║  WS    : ws://{host}:{port}/ws                ║")
    print(f"║  POST  : http://{host}:{port}/command         ║")
    print("╠══════════════════════════════════════════════╣")
    print("║  Flutter 앱에서 이 PC의 IP를 입력하세요     ║")
    print("╚══════════════════════════════════════════════╝")
    print()

    web.run_app(app, host=host, port=port, print=None)


if __name__ == "__main__":
    main()
