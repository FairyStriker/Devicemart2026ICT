#!/bin/bash
# patch_measurement_runtime.sh
# build_sensor_distribution_payload 호출에 baseline 파라미터 추가
# 사용법: cd ~/posture_ai && bash tools/patch_measurement_runtime.sh

TARGET="src/runtime/measurement_runtime.py"

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

# --- build_sensor_distribution_payload 호출에 baseline 추가 ---
OLD_CALL = '''            distribution_payload = build_sensor_distribution_payload(
                user_id=current_profile["user_id"],
                session_id=session_id,
                sample_index=sample_index,
                raw_packet=raw_packet,
                feature_map=feature_map,
                semantic_packet=semantic_packet,
            )'''

NEW_CALL = '''            distribution_payload = build_sensor_distribution_payload(
                user_id=current_profile["user_id"],
                session_id=session_id,
                sample_index=sample_index,
                raw_packet=raw_packet,
                feature_map=feature_map,
                semantic_packet=semantic_packet,
                baseline=baseline,
            )'''

if "baseline=baseline," not in content.split("build_sensor_distribution_payload")[1][:300]:
    content = content.replace(OLD_CALL, NEW_CALL)
    print("[PATCH] Added baseline parameter to build_sensor_distribution_payload call")
else:
    print("[SKIP] baseline parameter already exists in call")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"[DONE] {path} patched successfully")
PYEOF
