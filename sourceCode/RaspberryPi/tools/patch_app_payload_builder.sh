#!/bin/bash
# patch_app_payload_builder.sh
# sensor_distribution의 loadcell percent를 baseline 대비 안정도로 변경
# 사용법: cd ~/posture_ai && bash tools/patch_app_payload_builder.sh

TARGET="src/communication/app_payload_builder.py"

if [ ! -f "$TARGET" ]; then
  echo "[ERROR] $TARGET not found. Run from ~/posture_ai"
  exit 1
fi

cp "$TARGET" "${TARGET}.bak"
echo "[BACKUP] ${TARGET}.bak created"

python3 - "$TARGET" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1) _baseline_similarity_percent 함수 + _LOADCELL_CELL_DANGER_KG 추가 ---
OLD_FUNC_SIG = "def build_sensor_distribution_payload("
NEW_BLOCK = '''def _baseline_similarity_percent(current, baseline_val, danger_range):
    """
    baseline 대비 안정도를 0~100%로 반환.
    current == baseline -> 100%, 차이가 danger_range 이상 -> 0%.
    baseline이 0이고 current도 0이면 100% (변화 없음).
    """
    delta = abs(current - baseline_val)
    if danger_range <= 0:
        return 100 if delta == 0 else 0
    score = 100 * (1 - delta / danger_range)
    return int(_clamp(round(score)))


# 로드셀 개별 셀의 baseline 대비 변화 판단용 위험 범위 (kg)
_LOADCELL_CELL_DANGER_KG = 5.0


def build_sensor_distribution_payload('''

if "_baseline_similarity_percent" not in content:
    content = content.replace(OLD_FUNC_SIG, NEW_BLOCK)
    print("[PATCH 1] Added _baseline_similarity_percent + _LOADCELL_CELL_DANGER_KG")
else:
    print("[SKIP 1] _baseline_similarity_percent already exists")

# --- 2) 함수 시그니처에 baseline=None 추가 ---
OLD_SIG = '''    semantic_packet=None,
):
    """
    앱 대시보드용 상세 센서 분포 payload
    - spine ToF는 semantic_packet의 정제/안정화 값 우선 사용
    - head ToF는 비정상 범위값을 제외하고 요약
    """
    semantic_packet = semantic_packet or {}'''

NEW_SIG = '''    semantic_packet=None,
    baseline=None,
):
    """
    앱 대시보드용 상세 센서 분포 payload
    - spine ToF는 semantic_packet의 정제/안정화 값 우선 사용
    - head ToF는 비정상 범위값을 제외하고 요약
    - loadcell percent는 baseline 대비 안정도 (baseline=None이면 절대값 기준)
    """
    semantic_packet = semantic_packet or {}
    baseline = baseline or {}'''

if "baseline=None," not in content.split("build_sensor_distribution_payload")[1][:200]:
    content = content.replace(OLD_SIG, NEW_SIG)
    print("[PATCH 2] Added baseline parameter to function signature")
else:
    print("[SKIP 2] baseline parameter already exists")

# --- 3) back percent 계산을 baseline 대비로 변경 ---
OLD_BACK_CALC = '''    back_total_abs = sum(abs(v) for v in back_ui_values)

    if back_total_abs > 0:
        back_ui_percents = [
            _clamp(int(round((abs(v) / back_total_abs) * 100)))
            for v in back_ui_values
        ]
    else:
        back_ui_percents = [0] * 8'''

NEW_BACK_CALC = '''    # baseline loadcell 개별 값 가져오기 (캘리브레이션 시 저장된 값)
    bl_back = [
        baseline.get("back_left_top_kg", 0.0),
        baseline.get("back_left_upper_mid_kg", 0.0),
        baseline.get("back_left_lower_mid_kg", 0.0),
        baseline.get("back_left_bottom_kg", 0.0),
        baseline.get("back_right_top_kg", 0.0),
        baseline.get("back_right_upper_mid_kg", 0.0),
        baseline.get("back_right_lower_mid_kg", 0.0),
        baseline.get("back_right_bottom_kg", 0.0),
    ]

    # baseline 대비 안정도로 percent 계산
    back_ui_percents = [
        _baseline_similarity_percent(cur, base, _LOADCELL_CELL_DANGER_KG)
        for cur, base in zip(back_ui_values, bl_back)
    ]'''

if "bl_back" not in content:
    content = content.replace(OLD_BACK_CALC, NEW_BACK_CALC)
    print("[PATCH 3] Changed back percent to baseline similarity")
else:
    print("[SKIP 3] back baseline calc already exists")

# --- 4) seat percent 계산을 baseline 대비로 변경 ---
OLD_SEAT_CALC = '''    seat_total_abs = sum(abs(v) for v in seat_ui_values)

    if seat_total_abs > 0:
        seat_ui_percents = [
            _clamp(int(round((abs(v) / seat_total_abs) * 100)))
            for v in seat_ui_values
        ]
    else:
        seat_ui_percents = [0, 0, 0, 0]'''

NEW_SEAT_CALC = '''    bl_seat = [
        baseline.get("seat_rear_left_kg", 0.0),
        baseline.get("seat_rear_right_kg", 0.0),
        baseline.get("seat_front_left_kg", 0.0),
        baseline.get("seat_front_right_kg", 0.0),
    ]

    seat_ui_percents = [
        _baseline_similarity_percent(cur, base, _LOADCELL_CELL_DANGER_KG)
        for cur, base in zip(seat_ui_values, bl_seat)
    ]'''

if "bl_seat" not in content:
    content = content.replace(OLD_SEAT_CALC, NEW_SEAT_CALC)
    print("[PATCH 4] Changed seat percent to baseline similarity")
else:
    print("[SKIP 4] seat baseline calc already exists")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"[DONE] {path} patched successfully")
PYEOF
