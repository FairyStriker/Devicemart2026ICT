// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/summary_model.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  static const Map<String, String> _postureKo = {
    'normal':           '정자세',
    'turtle_neck':      '거북목',
    'forward_lean':     '상체 굽힘',
    'reclined':         '누워 앉기',
    'side_slouch':      '새우 자세',
    'leg_cross_suspect':'다리 꼬기',
    'thinking_pose':    '생각하는 사람 자세',
    'perching':         '걸터앉기',
  };

  static const List<String> _postureOrder = [
    'normal', 'turtle_neck', 'forward_lean', 'reclined',
    'side_slouch', 'leg_cross_suspect', 'thinking_pose', 'perching',
  ];

  static const Map<String, Color> _postureColors = {
    'normal':           Color(0xFF22C55E),
    'turtle_neck':      Color(0xFFEF4444),
    'forward_lean':     Color(0xFFF97316),
    'reclined':         Color(0xFF8B5CF6),
    'side_slouch':      Color(0xFF3B82F6),
    'leg_cross_suspect':Color(0xFFEC4899),
    'thinking_pose':    Color(0xFF14B8A6),
    'perching':         Color(0xFFF59E0B),
  };

  String _formatSec(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
    return '${(sec ~/ 60)}분 ${(sec % 60).toInt()}초';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final overall = app.overallSummary;
    final minutes = app.minuteSummaries;

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
          : _buildReport(context, overall, minutes),
    );
  }

  Widget _buildReport(
    BuildContext context,
    OverallSummary overall,
    List<MinuteSummary> minutes,
  ) {
    // 총 샘플 수 (초당 50샘플 기준)
    final totalSamples = (overall.totalSittingSec * 50).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 세션 요약 카드 ────────────────────────────────
          Card(
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
                      _SummaryStatItem(
                        value: overall.avgScore.toStringAsFixed(1),
                        label: '평균 점수',
                        color: const Color(0xFF22C55E),
                      ),
                      _Divider(),
                      _SummaryStatItem(
                        value: _formatSec(overall.totalSittingSec),
                        label: '수집 시간',
                        color: const Color(0xFF3B82F6),
                      ),
                      _Divider(),
                      _SummaryStatItem(
                        value: totalSamples.toString(),
                        label: '총 샘플',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 자세 분포 ─────────────────────────────────────
          Card(
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
                  ..._postureOrder.map((posture) {
                    final sec =
                        overall.postureDurationSec[posture] ?? 0.0;
                    final ratio = overall.totalSittingSec > 0
                        ? sec / overall.totalSittingSec
                        : 0.0;
                    final pct = (ratio * 100).toStringAsFixed(0);
                    final color = _postureColors[posture] ??
                        Colors.white54;
                    final label = _postureKo[posture] ?? posture;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          // 색상 점
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          // 자세명
                          SizedBox(
                            width: 120,
                            child: Text(label,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ),
                          // 바
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: Colors.white12,
                                color: color,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 퍼센트
                          SizedBox(
                            width: 38,
                            child: Text('$pct%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          // 초
                          SizedBox(
                            width: 52,
                            child: Text(
                                '${sec.toStringAsFixed(1)}s',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 분별 히스토리 ─────────────────────────────────
          if (minutes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '분별 히스토리 (${minutes.length}건)',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: Column(
                children: List.generate(minutes.length, (i) {
                  final m = minutes[i];
                  final color = _postureColors[m.dominantPosture] ??
                      Colors.white54;
                  final label =
                      _postureKo[m.dominantPosture] ?? m.dominantPosture;
                  final isLast = i == minutes.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          // 인덱스
                          SizedBox(
                            width: 32,
                            child: Text('#${m.minuteIndex}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 13)),
                          ),
                          // 점수
                          Text(
                            m.avgScore.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          // 자세 뱃지
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color, width: 1),
                            ),
                            child: Text(
                              '$label ${m.dominantPostureRatio.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          // 샘플 수
                          Text(
                            '${(60 * 50).toString()}샘플',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ]),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: Colors.white12),
                    ],
                  );
                }),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────
class _SummaryStatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.white12);
  }
}
