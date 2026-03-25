// lib/services/report_storage_service.dart
//
// 최근 보고서 5개를 SharedPreferences에 저장/로드
// RPi 미접속 상태에서도 열람 가능

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedReport {
  final String userId;
  final String sessionId;
  final int timestamp;
  final double avgScore;
  final double totalSittingSec;
  final String dominantPosture;
  final double dominantPostureRatio;
  final Map<String, double> postureDurationSec;
  final String summaryText;
  final String trendText;
  final List<String> exerciseRecommendations;

  SavedReport({
    required this.userId,
    required this.sessionId,
    required this.timestamp,
    required this.avgScore,
    required this.totalSittingSec,
    required this.dominantPosture,
    required this.dominantPostureRatio,
    required this.postureDurationSec,
    required this.summaryText,
    required this.trendText,
    required this.exerciseRecommendations,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'session_id': sessionId,
    'timestamp': timestamp,
    'avg_score': avgScore,
    'total_sitting_sec': totalSittingSec,
    'dominant_posture': dominantPosture,
    'dominant_posture_ratio': dominantPostureRatio,
    'posture_duration_sec': postureDurationSec,
    'summary_text': summaryText,
    'trend_text': trendText,
    'exercise_recommendations': exerciseRecommendations,
  };

  factory SavedReport.fromJson(Map<String, dynamic> json) {
    final rawDur = json['posture_duration_sec'] as Map<String, dynamic>? ?? {};
    final dur = rawDur.map((k, v) => MapEntry(k, (v as num).toDouble()));
    final rawExercise = json['exercise_recommendations'] as List<dynamic>? ?? [];
    final exercises = rawExercise.map((e) => e.toString()).toList();

    return SavedReport(
      userId: json['user_id'] ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      timestamp: json['timestamp'] ?? 0,
      avgScore: (json['avg_score'] ?? 0).toDouble(),
      totalSittingSec: (json['total_sitting_sec'] ?? 0).toDouble(),
      dominantPosture: json['dominant_posture'] ?? 'normal',
      dominantPostureRatio: (json['dominant_posture_ratio'] ?? 0).toDouble(),
      postureDurationSec: dur,
      summaryText: json['summary_text'] ?? '',
      trendText: json['trend_text'] ?? '',
      exerciseRecommendations: exercises,
    );
  }

  String get formattedDate {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final m = totalSittingSec ~/ 60;
    final s = (totalSittingSec % 60).toInt();
    return '${m}분 ${s}초';
  }
}

class ReportStorageService {
  static const _key = 'saved_reports';
  static const _maxCount = 5;

  /// 보고서 저장 (최근 5개 유지)
  static Future<void> save(SavedReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAll();

    // 같은 session_id 중복 방지
    list.removeWhere((r) => r.sessionId == report.sessionId);

    list.insert(0, report);

    // 최대 5개 유지
    while (list.length > _maxCount) {
      list.removeLast();
    }

    final jsonList = list.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  /// 저장된 보고서 전체 로드
  static Future<List<SavedReport>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];

    return jsonList.map((s) {
      try {
        return SavedReport.fromJson(jsonDecode(s));
      } catch (_) {
        return null;
      }
    }).whereType<SavedReport>().toList();
  }

  /// 전체 삭제
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
