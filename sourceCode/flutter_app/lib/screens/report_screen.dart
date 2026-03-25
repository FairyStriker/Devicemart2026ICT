// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/summary_model.dart';
import '../services/report_storage_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _saved = false;

  static const Map<String, String> _postureKo = {
    'normal': '정자세', 'turtle_neck': '거북목',
    'forward_lean': '상체 굽힘', 'reclined': '누워 앉기',
    'side_slouch': '새우 자세', 'leg_cross_suspect': '다리 꼬기',
    'thinking_pose': '생각하는 사람 자세', 'perching': '걸터앉기',
  };

  static const List<String> _postureOrder = [
    'normal', 'turtle_neck', 'forward_lean', 'reclined',
    'side_slouch', 'leg_cross_suspect', 'thinking_pose', 'perching',
  ];

  static const Map<String, Color> _postureColors = {
    'normal': Color(0xFF22C55E), 'turtle_neck': Color(0xFFEF4444),
    'forward_lean': Color(0xFFF97316), 'reclined': Color(0xFF8B5CF6),
    'side_slouch': Color(0xFF3B82F6), 'leg_cross_suspect': Color(0xFFEC4899),
    'thinking_pose': Color(0xFF14B8A6), 'perching': Color(0xFFF59E0B),
  };

  /// enhanced_report + overall_summary를 로컬에 저장
  void _saveReportLocally(AppStateProvider app) {
    if (_saved) return;
    final overall = app.overallSummary;
    final enhanced = app.enhancedReport;
    if (overall == null) return;

    _saved = true;

    final data = enhanced?.data ?? {};
    final report = SavedReport(
      userId: app.meta.userId ?? '',
      sessionId: enhanced?.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      avgScore: overall.avgScore,
      totalSittingSec: overall.totalSittingSec,
      dominantPosture: overall.dominantPosture,
      dominantPostureRatio: overall.dominantPostureRatio,
      postureDurationSec: overall.postureDurationSec,
      summaryText: data['summary_text'] ?? '',
      trendText: data['trend_text'] ?? '',
      exerciseRecommendations: (data['exercise_recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

    ReportStorageService.save(report);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final overall = app.overallSummary;
    final enhanced = app.enhancedReport;
    final minutes = app.minuteSummaries;

    // 데이터 도착하면 자동 저장
    if (overall != null && !_saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveReportLocally(app);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('세션 결과'),
        actions: [
          TextButton(
            onPressed: () {
              app.resetSession();
              app.disconnect();
            },
            child: const Text('처음으로',
                style: TextStyle(color: Color(0xFF2563EB))),
          ),
        ],
      ),
      body: overall == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text('결과 불러오는 중...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _buildReport(context, overall, enhanced, minutes),
    );
  }

  Widget _buildReport(
    BuildContext context,
    OverallSummary overall,
    EnhancedReport? enhanced,
    List<MinuteSummary> minutes,
  ) {
    final enhancedData = enhanced?.data ?? {};
    final summaryText = enhancedData['summary_text'] as String? ?? '';
    final trendText = enhancedData['trend_text'] as String? ?? '';
    final rawExercise = enhancedData['exercise_recommendations'] as List<dynamic>? ?? [];
    final exercises = rawExercise.map((e) => e.toString()).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── AI 분석 요약 ──────────────────────────────────
          if (summaryText.isNotEmpty) ...[
            _EnhancedReportCard(
              summaryText: summaryText,
              trendText: trendText,
              exercises: exercises,
            ),
            const SizedBox(height: 16),
          ],

          // ─── 세션 요약 카드 ────────────────────────────────
          _OverallCard(overall: overall, postureKo: _postureKo),
          const SizedBox(height: 16),

          // ─── 자세 분포 ─────────────────────────────────────
          _PostureDistCard(
            overall: overall,
            postureOrder: _postureOrder,
            postureKo: _postureKo,
            postureColors: _postureColors,
          ),
          const SizedBox(height: 16),

          // ─── 분별 히스토리 ─────────────────────────────────
          if (minutes.isNotEmpty)
            _MinuteHistoryCard(
              minutes: minutes,
              postureKo: _postureKo,
              postureColors: _postureColors,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Enhanced Report 카드 (LLM 보고서)
// ═══════════════════════════════════════════════════════════════════

class _EnhancedReportCard extends StatelessWidget {
  final String summaryText;
  final String trendText;
  final List<String> exercises;

  const _EnhancedReportCard({
    required this.summaryText,
    required this.trendText,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF162033),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2563EB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              const Text('AI 자세 분석',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),

            // 요약
            Text(summaryText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.6)),
            const SizedBox(height: 14),

            // 추이
            if (trendText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(trendText,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 추천 운동
            if (exercises.isNotEmpty) ...[
              const Text('추천 교정 운동',
                  style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...exercises.map((ex) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.fitness_center,
                              color: Color(0xFF60A5FA), size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ex,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 세션 요약 카드
// ═══════════════════════════════════════════════════════════════════

class _OverallCard extends StatelessWidget {
  final OverallSummary overall;
  final Map<String, String> postureKo;
  const _OverallCard({required this.overall, required this.postureKo});

  @override
  Widget build(BuildContext context) {
    final m = overall.totalSittingSec ~/ 60;
    final s = (overall.totalSittingSec % 60).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('세션 요약',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  value: overall.avgScore.toStringAsFixed(1),
                  label: '평균 점수',
                  color: const Color(0xFF22C55E),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _StatItem(
                  value: '${m}분 ${s}초',
                  label: '측정 시간',
                  color: const Color(0xFF3B82F6),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _StatItem(
                  value: postureKo[overall.dominantPosture] ?? overall.dominantPosture,
                  label: '주요 자세',
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// 자세 분포 카드
// ═══════════════════════════════════════════════════════════════════

class _PostureDistCard extends StatelessWidget {
  final OverallSummary overall;
  final List<String> postureOrder;
  final Map<String, String> postureKo;
  final Map<String, Color> postureColors;
  const _PostureDistCard({
    required this.overall, required this.postureOrder,
    required this.postureKo, required this.postureColors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('자세 분포',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...postureOrder.map((posture) {
              final sec = overall.postureDurationSec[posture] ?? 0.0;
              final ratio = overall.totalSittingSec > 0
                  ? sec / overall.totalSittingSec : 0.0;
              final pct = (ratio * 100).toStringAsFixed(0);
              final color = postureColors[posture] ?? Colors.white54;
              final label = postureKo[posture] ?? posture;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  SizedBox(width: 100,
                      child: Text(label,
                          style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio, backgroundColor: Colors.white12,
                        color: color, minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 38,
                      child: Text('$pct%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white54, fontSize: 12))),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 분별 히스토리
// ═══════════════════════════════════════════════════════════════════

class _MinuteHistoryCard extends StatelessWidget {
  final List<MinuteSummary> minutes;
  final Map<String, String> postureKo;
  final Map<String, Color> postureColors;
  const _MinuteHistoryCard({
    required this.minutes, required this.postureKo, required this.postureColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('분별 히스토리 (${minutes.length}건)',
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: List.generate(minutes.length, (i) {
              final m = minutes[i];
              final color = postureColors[m.dominantPosture] ?? Colors.white54;
              final label = postureKo[m.dominantPosture] ?? m.dominantPosture;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 32,
                        child: Text('#${m.minuteIndex}',
                            style: const TextStyle(color: Colors.white38, fontSize: 13))),
                    Text(m.avgScore.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Text(
                        '$label ${m.dominantPostureRatio.toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
                if (i < minutes.length - 1)
                  const Divider(height: 1, color: Colors.white12),
              ]);
            }),
          ),
        ),
      ],
    );
  }
}
