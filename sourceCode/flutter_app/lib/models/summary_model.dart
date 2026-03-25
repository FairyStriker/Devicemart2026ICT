// lib/models/summary_model.dart

class MinuteSummary {
  final int minuteIndex;
  final double avgScore;
  final String dominantPosture;
  final double dominantPostureRatio;

  MinuteSummary({
    required this.minuteIndex,
    required this.avgScore,
    required this.dominantPosture,
    required this.dominantPostureRatio,
  });

  factory MinuteSummary.fromJson(Map<String, dynamic> json) {
    return MinuteSummary(
      minuteIndex:         json['minute_index'] ?? 0,
      avgScore:            (json['avg_score'] ?? 0).toDouble(),
      dominantPosture:     json['dominant_posture'] ?? 'normal',
      dominantPostureRatio:(json['dominant_posture_ratio'] ?? 0).toDouble(),
    );
  }
}

class OverallSummary {
  final double avgScore;
  final double totalSittingSec;
  final String dominantPosture;
  final double dominantPostureRatio;
  final Map<String, double> postureDurationSec;

  OverallSummary({
    required this.avgScore,
    required this.totalSittingSec,
    required this.dominantPosture,
    required this.dominantPostureRatio,
    required this.postureDurationSec,
  });

  factory OverallSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['posture_duration_sec'] as Map<String, dynamic>? ?? {};
    final durations = raw.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    return OverallSummary(
      avgScore:            (json['avg_score'] ?? 0).toDouble(),
      totalSittingSec:     (json['total_sitting_sec'] ?? 0).toDouble(),
      dominantPosture:     json['dominant_posture'] ?? 'normal',
      dominantPostureRatio:(json['dominant_posture_ratio'] ?? 0).toDouble(),
      postureDurationSec:  durations,
    );
  }
}

class StandEvent {
  final String userId;
  final String message;
  final String resumeAction;
  final String stopAction;

  StandEvent({
    required this.userId,
    required this.message,
    required this.resumeAction,
    required this.stopAction,
  });

  factory StandEvent.fromJson(Map<String, dynamic> json) {
    final actions = json['actions'] ?? {};
    return StandEvent(
      userId:       json['user_id'] ?? '',
      message:      json['message'] ?? '사용자가 자리에서 일어났습니다.',
      resumeAction: actions['resume'] ?? 'resume_after_stand',
      stopAction:   actions['stop'] ?? 'decline_resume_after_stand',
    );
  }
}

/// RPi report_service.build_enhanced_report 결과
/// 서버가 보내는 enhanced_report payload를 그대로 저장
class EnhancedReport {
  final String userId;
  final String sessionId;
  final Map<String, dynamic> data;

  EnhancedReport({
    required this.userId,
    required this.sessionId,
    required this.data,
  });

  factory EnhancedReport.fromJson(Map<String, dynamic> json) {
    return EnhancedReport(
      userId:    json['user_id'] ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      data:      json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}
