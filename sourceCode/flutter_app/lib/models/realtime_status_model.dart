// lib/models/realtime_status_model.dart
//
// RPi WebSocket type="realtime_status" payload
// 50Hz 매 프레임, 자세 판정 + 집계 점수만 포함
// 개별 센서 데이터는 sensor_distribution_model.dart 참조

class PostureFlags {
  final bool turtleNeck;
  final bool forwardLean;
  final bool reclined;
  final bool sideSlouch;
  final bool legCrossSuspect;
  final bool thinkingPose;
  final bool perching;
  final bool normal;

  PostureFlags({
    required this.turtleNeck, required this.forwardLean,
    required this.reclined, required this.sideSlouch,
    required this.legCrossSuspect, required this.thinkingPose,
    required this.perching, required this.normal,
  });

  factory PostureFlags.fromJson(Map<String, dynamic> json) {
    return PostureFlags(
      turtleNeck:      json['turtle_neck'] ?? false,
      forwardLean:     json['forward_lean'] ?? false,
      reclined:        json['reclined'] ?? false,
      sideSlouch:      json['side_slouch'] ?? false,
      legCrossSuspect: json['leg_cross_suspect'] ?? false,
      thinkingPose:    json['thinking_pose'] ?? false,
      perching:        json['perching'] ?? false,
      normal:          json['normal'] ?? false,
    );
  }
}

class MonitoringMetric {
  final double score;
  final String level;

  MonitoringMetric({required this.score, required this.level});

  factory MonitoringMetric.fromJson(Map<String, dynamic> json) {
    return MonitoringMetric(
      score: (json['score'] ?? json['balance_score'] ?? 0).toDouble(),
      level: json['level'] ?? json['balance_level'] ?? 'good',
    );
  }

  factory MonitoringMetric.empty() =>
      MonitoringMetric(score: 0, level: 'good');
}

class RealtimeStatusModel {
  final String userId;
  final int timestamp;
  final String dominantPosture;
  final PostureFlags flags;
  final double currentScore;
  final bool alert;
  final int alertStage;
  final MonitoringMetric loadcell;
  final MonitoringMetric spineTof;
  final MonitoringMetric neckTof;

  RealtimeStatusModel({
    required this.userId, required this.timestamp,
    required this.dominantPosture, required this.flags,
    required this.currentScore, required this.alert,
    required this.alertStage,
    required this.loadcell, required this.spineTof, required this.neckTof,
  });

  factory RealtimeStatusModel.fromJson(Map<String, dynamic> json) {
    final posture    = json['posture'] as Map<String, dynamic>? ?? {};
    final score      = json['score'] as Map<String, dynamic>? ?? {};
    final monitoring = json['monitoring'] as Map<String, dynamic>? ?? {};

    return RealtimeStatusModel(
      userId:          json['user_id'] ?? '',
      timestamp:       json['timestamp'] ?? 0,
      dominantPosture: posture['dominant'] ?? 'normal',
      flags:           PostureFlags.fromJson(posture['flags'] ?? {}),
      currentScore:    (score['current'] ?? 100).toDouble(),
      alert:           score['alert'] ?? false,
      alertStage:      score['alert_stage'] ?? 0,
      loadcell:  MonitoringMetric.fromJson(monitoring['loadcell'] ?? {}),
      spineTof:  MonitoringMetric.fromJson(monitoring['spine_tof'] ?? {}),
      neckTof:   MonitoringMetric.fromJson(monitoring['neck_tof'] ?? {}),
    );
  }

  static const Map<String, String> postureKo = {
    'normal': '정자세', 'turtle_neck': '거북목',
    'forward_lean': '상체 굽힘', 'reclined': '누워 앉기',
    'side_slouch': '새우 자세', 'leg_cross_suspect': '다리 꼬기',
    'thinking_pose': '생각하는 사람 자세', 'perching': '걸터앉기',
  };

  String get dominantPostureKo =>
      postureKo[dominantPosture] ?? dominantPosture;
}
