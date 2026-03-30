#!/bin/bash
# patch_feature_extractor.sh
# feature_map에 개별 로드셀 kg 값을 추가 (baseline 저장용)
# 사용법: cd ~/posture_ai && bash tools/patch_feature_extractor.sh

TARGET="src/core/feature_extractor.py"

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

# --- feature_map에 개별 로드셀 kg 추가 ---
OLD_TAIL = '''        "back_total": back_right_total + back_left_total,
        "seat_total": seat_right_total + seat_left_total,
    }'''

NEW_TAIL = '''        "back_total": back_right_total + back_left_total,
        "seat_total": seat_right_total + seat_left_total,
        # 개별 로드셀 kg (baseline 저장 -> sensor_distribution percent 계산용)
        "back_left_top_kg": bl_top,
        "back_left_upper_mid_kg": bl_um,
        "back_left_lower_mid_kg": bl_lm,
        "back_left_bottom_kg": bl_bottom,
        "back_right_top_kg": br_top,
        "back_right_upper_mid_kg": br_um,
        "back_right_lower_mid_kg": br_lm,
        "back_right_bottom_kg": br_bottom,
        "seat_rear_left_kg": sl_rear,
        "seat_rear_right_kg": sr_rear,
        "seat_front_left_kg": sl_front,
        "seat_front_right_kg": sr_front,
    }'''

if "back_left_top_kg" not in content:
    content = content.replace(OLD_TAIL, NEW_TAIL)
    print("[PATCH] Added individual loadcell kg to feature_map")
else:
    print("[SKIP] Individual loadcell kg already exists")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"[DONE] {path} patched successfully")
PYEOF
