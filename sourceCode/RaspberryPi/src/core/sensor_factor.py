from copy import deepcopy

from src.config.settings import FACTOR_ENABLE, LOADCELL_CALIBRATION


LOADCELL_ORDER = [
    "back_right_top",
    "back_right_upper_mid",
    "back_right_lower_mid",
    "back_right_bottom",
    "back_left_top",
    "back_left_upper_mid",
    "back_left_lower_mid",
    "back_left_bottom",
    "seat_rear_right",
    "seat_front_right",
    "seat_rear_left",
    "seat_front_left",
]


def convert_loadcell_to_kg(raw_value, offset, count_per_kg, noise_floor_kg=0.2):
    delta = raw_value - offset
    magnitude = abs(delta)
    weight_kg = magnitude / count_per_kg if count_per_kg else 0.0

    if weight_kg < noise_floor_kg:
        return 0.0

    return round(weight_kg, 4)


def apply_sensor_factors(raw_packet: dict) -> dict:
    """
    raw_packet에 센서 보정을 적용한 새 dict를 반환한다.

    현재는 loadcell만 실제 calibration(offset/count_per_kg) 기반으로 변환하고,
    ToF / MPU는 기존 값을 그대로 유지한다.
    """
    if not FACTOR_ENABLE:
        return raw_packet

    corrected = deepcopy(raw_packet)

    loadcell = corrected.get("loadcell", [])
    if isinstance(loadcell, list) and loadcell:
        new_loadcell = []
        for idx, value in enumerate(loadcell):
            if idx < len(LOADCELL_ORDER):
                key = LOADCELL_ORDER[idx]
                calib = LOADCELL_CALIBRATION.get(key, {})
                offset = calib.get("offset", 0)
                count_per_kg = calib.get("count_per_kg", 1.0)
                converted = convert_loadcell_to_kg(
                    raw_value=value,
                    offset=offset,
                    count_per_kg=count_per_kg,
                )
            else:
                converted = value

            new_loadcell.append(converted)

        corrected["loadcell"] = new_loadcell

    return corrected