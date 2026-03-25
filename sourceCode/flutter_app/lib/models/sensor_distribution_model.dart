// lib/models/sensor_distribution_model.dart
//
// RPi WebSocket type="sensor_distribution" payload
// ~10프레임마다 1회 push, 개별 센서 {percent, level, raw} 구조

class SensorCell {
  final double percent;
  final String level;
  final double raw;

  SensorCell({required this.percent, required this.level, required this.raw});

  factory SensorCell.fromJson(Map<String, dynamic> json) {
    return SensorCell(
      percent: (json['percent'] ?? 0).toDouble(),
      level: json['level'] ?? 'danger',
      raw: (json['raw'] ?? json['raw_mm'] ?? 0).toDouble(),
    );
  }

  factory SensorCell.empty() => SensorCell(percent: 0, level: 'danger', raw: 0);
}

// ─── 등판 압력 (HX711 x8) ─────────────────────────────────────

class BackPressureDist {
  final SensorCell leftTop;
  final SensorCell leftUpperMid;
  final SensorCell leftLowerMid;
  final SensorCell leftBottom;
  final SensorCell rightTop;
  final SensorCell rightUpperMid;
  final SensorCell rightLowerMid;
  final SensorCell rightBottom;
  final double leftTotalPercent;
  final double rightTotalPercent;
  final double balancePercent;

  BackPressureDist({
    required this.leftTop, required this.leftUpperMid,
    required this.leftLowerMid, required this.leftBottom,
    required this.rightTop, required this.rightUpperMid,
    required this.rightLowerMid, required this.rightBottom,
    required this.leftTotalPercent, required this.rightTotalPercent,
    required this.balancePercent,
  });

  factory BackPressureDist.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    return BackPressureDist(
      leftTop:      SensorCell.fromJson(json['left_top'] ?? {}),
      leftUpperMid: SensorCell.fromJson(json['left_upper_mid'] ?? {}),
      leftLowerMid: SensorCell.fromJson(json['left_lower_mid'] ?? {}),
      leftBottom:   SensorCell.fromJson(json['left_bottom'] ?? {}),
      rightTop:      SensorCell.fromJson(json['right_top'] ?? {}),
      rightUpperMid: SensorCell.fromJson(json['right_upper_mid'] ?? {}),
      rightLowerMid: SensorCell.fromJson(json['right_lower_mid'] ?? {}),
      rightBottom:   SensorCell.fromJson(json['right_bottom'] ?? {}),
      leftTotalPercent:  (s['left_total_percent'] ?? 0).toDouble(),
      rightTotalPercent: (s['right_total_percent'] ?? 0).toDouble(),
      balancePercent:    (s['balance_percent'] ?? 0).toDouble(),
    );
  }

  factory BackPressureDist.empty() => BackPressureDist(
    leftTop: SensorCell.empty(), leftUpperMid: SensorCell.empty(),
    leftLowerMid: SensorCell.empty(), leftBottom: SensorCell.empty(),
    rightTop: SensorCell.empty(), rightUpperMid: SensorCell.empty(),
    rightLowerMid: SensorCell.empty(), rightBottom: SensorCell.empty(),
    leftTotalPercent: 0, rightTotalPercent: 0, balancePercent: 0,
  );

  List<SensorCell> get leftCells =>
      [leftTop, leftUpperMid, leftLowerMid, leftBottom];
  List<SensorCell> get rightCells =>
      [rightTop, rightUpperMid, rightLowerMid, rightBottom];
}

// ─── 좌석 압력 (HX711 x4) ─────────────────────────────────────

class SeatPressureDist {
  final SensorCell rearLeft;
  final SensorCell rearRight;
  final SensorCell frontLeft;
  final SensorCell frontRight;
  final double rearTotalPercent;
  final double frontTotalPercent;
  final double balancePercent;
  final double centerShiftFb;
  final double centerShiftLr;

  SeatPressureDist({
    required this.rearLeft, required this.rearRight,
    required this.frontLeft, required this.frontRight,
    required this.rearTotalPercent, required this.frontTotalPercent,
    required this.balancePercent,
    required this.centerShiftFb, required this.centerShiftLr,
  });

  factory SeatPressureDist.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    final cs = s['center_shift'] as Map<String, dynamic>? ?? {};
    return SeatPressureDist(
      rearLeft:  SensorCell.fromJson(json['rear_left'] ?? {}),
      rearRight: SensorCell.fromJson(json['rear_right'] ?? {}),
      frontLeft: SensorCell.fromJson(json['front_left'] ?? {}),
      frontRight:SensorCell.fromJson(json['front_right'] ?? {}),
      rearTotalPercent:  (s['rear_total_percent'] ?? 0).toDouble(),
      frontTotalPercent: (s['front_total_percent'] ?? 0).toDouble(),
      balancePercent:    (s['balance_percent'] ?? 0).toDouble(),
      centerShiftFb: (cs['fb'] ?? 0).toDouble(),
      centerShiftLr: (cs['lr'] ?? 0).toDouble(),
    );
  }

  factory SeatPressureDist.empty() => SeatPressureDist(
    rearLeft: SensorCell.empty(), rearRight: SensorCell.empty(),
    frontLeft: SensorCell.empty(), frontRight: SensorCell.empty(),
    rearTotalPercent: 0, frontTotalPercent: 0, balancePercent: 0,
    centerShiftFb: 0, centerShiftLr: 0,
  );
}

// ─── 척추 ToF (VL53L0X x4) ────────────────────────────────────

class SpineTofDist {
  final SensorCell upper;
  final SensorCell upperMid;
  final SensorCell lowerMid;
  final SensorCell lower;
  final double overallPercent;
  final double curveScore;

  SpineTofDist({
    required this.upper, required this.upperMid,
    required this.lowerMid, required this.lower,
    required this.overallPercent, required this.curveScore,
  });

  factory SpineTofDist.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    return SpineTofDist(
      upper:    SensorCell.fromJson(json['upper'] ?? {}),
      upperMid: SensorCell.fromJson(json['upper_mid'] ?? {}),
      lowerMid: SensorCell.fromJson(json['lower_mid'] ?? {}),
      lower:    SensorCell.fromJson(json['lower'] ?? {}),
      overallPercent: (s['overall_percent'] ?? 0).toDouble(),
      curveScore:     (s['curve_score'] ?? 0).toDouble(),
    );
  }

  factory SpineTofDist.empty() => SpineTofDist(
    upper: SensorCell.empty(), upperMid: SensorCell.empty(),
    lowerMid: SensorCell.empty(), lower: SensorCell.empty(),
    overallPercent: 0, curveScore: 0,
  );

  List<SensorCell> get cells => [upper, upperMid, lowerMid, lower];
}

// ─── 머리/목 ToF (VL53L8CX x2) ────────────────────────────────

class HeadTofDist {
  final double overallPercent;
  final String overallLevel;
  final double leftMeanMm;
  final double rightMeanMm;

  HeadTofDist({
    required this.overallPercent, required this.overallLevel,
    required this.leftMeanMm, required this.rightMeanMm,
  });

  factory HeadTofDist.fromJson(Map<String, dynamic> json) {
    final overall = json['overall'] as Map<String, dynamic>? ?? {};
    final left = json['left_sensor'] as Map<String, dynamic>? ?? {};
    final right = json['right_sensor'] as Map<String, dynamic>? ?? {};
    return HeadTofDist(
      overallPercent: (overall['percent'] ?? 0).toDouble(),
      overallLevel:   overall['level'] ?? 'danger',
      leftMeanMm:     (left['mean_mm'] ?? 0).toDouble(),
      rightMeanMm:    (right['mean_mm'] ?? 0).toDouble(),
    );
  }

  factory HeadTofDist.empty() => HeadTofDist(
    overallPercent: 0, overallLevel: 'danger',
    leftMeanMm: 0, rightMeanMm: 0,
  );
}

// ─── IMU ────────────────────────────────────────────────────────

class ImuData {
  final double pitchLeftDeg;
  final double pitchRightDeg;
  final double pitchFusedDeg;
  final double pitchLrDiffDeg;

  ImuData({
    required this.pitchLeftDeg, required this.pitchRightDeg,
    required this.pitchFusedDeg, required this.pitchLrDiffDeg,
  });

  factory ImuData.fromJson(Map<String, dynamic> json) {
    return ImuData(
      pitchLeftDeg:   (json['pitch_left_deg'] ?? 0).toDouble(),
      pitchRightDeg:  (json['pitch_right_deg'] ?? 0).toDouble(),
      pitchFusedDeg:  (json['pitch_fused_deg'] ?? 0).toDouble(),
      pitchLrDiffDeg: (json['pitch_lr_diff_deg'] ?? 0).toDouble(),
    );
  }

  factory ImuData.empty() => ImuData(
    pitchLeftDeg: 0, pitchRightDeg: 0,
    pitchFusedDeg: 0, pitchLrDiffDeg: 0,
  );
}

// ─── 메인 모델 ──────────────────────────────────────────────────

class SensorDistributionModel {
  final String userId;
  final int sessionId;
  final int timestamp;
  final int frameIndex;
  final BackPressureDist backPressure;
  final SeatPressureDist seatPressure;
  final SpineTofDist spineTof;
  final HeadTofDist headTof;
  final ImuData imu;

  SensorDistributionModel({
    required this.userId, required this.sessionId,
    required this.timestamp, required this.frameIndex,
    required this.backPressure, required this.seatPressure,
    required this.spineTof, required this.headTof,
    required this.imu,
  });

  factory SensorDistributionModel.fromJson(Map<String, dynamic> json) {
    return SensorDistributionModel(
      userId:     json['user_id'] ?? '',
      sessionId:  json['session_id'] ?? 0,
      timestamp:  json['timestamp'] ?? 0,
      frameIndex: json['frame_index'] ?? 0,
      backPressure: BackPressureDist.fromJson(json['back_pressure'] ?? {}),
      seatPressure: SeatPressureDist.fromJson(json['seat_pressure'] ?? {}),
      spineTof:     SpineTofDist.fromJson(json['spine_tof'] ?? {}),
      headTof:      HeadTofDist.fromJson(json['head_tof'] ?? {}),
      imu:          ImuData.fromJson(json['imu'] ?? {}),
    );
  }
}
