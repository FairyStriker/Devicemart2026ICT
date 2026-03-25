// lib/screens/report_history_screen.dart
//
// 로컬 저장된 최근 5개 보고서 열람
// RPi 미접속 상태에서도 사용 가능

import 'package:flutter/material.dart';
import '../services/report_storage_service.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<SavedReport>? _reports;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await ReportStorageService.loadAll();
    if (mounted) setState(() => _reports = reports);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('최근 보고서'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _reports == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : _reports!.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('저장된 보고서가 없습니다',
                          style: TextStyle(color: Colors.white38, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('측정을 완료하면 자동으로 저장됩니다',
                          style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _reports![i];
                    return _ReportListTile(
                      report: r,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ReportDetailScreen(report: r),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── 목록 타일 ────────────────────────────────────────────────────

class _ReportListTile extends StatelessWidget {
  final SavedReport report;
  final VoidCallback onTap;
  const _ReportListTile({required this.report, required this.onTap});

  static const Map<String, String> _postureKo = {
    'normal': '정자세', 'turtle_neck': '거북목',
    'forward_lean': '상체 굽힘', 'reclined': '누워 앉기',
    'side_slouch': '새우 자세', 'leg_cross_suspect': '다리 꼬기',
    'thinking_pose': '생각하는 사람 자세', 'perching': '걸터앉기',
  };

  Color get _scoreColor {
    if (report.avgScore >= 80) return const Color(0xFF22C55E);
    if (report.avgScore >= 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // 점수
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _scoreColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _scoreColor),
              ),
              child: Center(
                child: Text(
                  report.avgScore.toStringAsFixed(0),
                  style: TextStyle(
                    color: _scoreColor, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.formattedDate,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${_postureKo[report.dominantPosture] ?? report.dominantPosture}  |  ${report.formattedDuration}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 보고서 상세 화면
// ═══════════════════════════════════════════════════════════════════

class _ReportDetailScreen extends StatelessWidget {
  final SavedReport report;
  const _ReportDetailScreen({required this.report});

  static const Map<String, String> _postureKo = {
    'normal': '정자세', 'turtle_neck': '거북목',
    'forward_lean': '상체 굽힘', 'reclined': '누워 앉기',
    'side_slouch': '새우 자세', 'leg_cross_suspect': '다리 꼬기',
    'thinking_pose': '생각하는 사람 자세', 'perching': '걸터앉기',
  };

  static const Map<String, Color> _postureColors = {
    'normal': Color(0xFF22C55E), 'turtle_neck': Color(0xFFEF4444),
    'forward_lean': Color(0xFFF97316), 'reclined': Color(0xFF8B5CF6),
    'side_slouch': Color(0xFF3B82F6), 'leg_cross_suspect': Color(0xFFEC4899),
    'thinking_pose': Color(0xFF14B8A6), 'perching': Color(0xFFF59E0B),
  };

  static const List<String> _postureOrder = [
    'normal', 'turtle_neck', 'forward_lean', 'reclined',
    'side_slouch', 'leg_cross_suspect', 'thinking_pose', 'perching',
  ];

  Color get _scoreColor {
    if (report.avgScore >= 80) return const Color(0xFF22C55E);
    if (report.avgScore >= 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(report.formattedDate),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── AI 분석 ──────────────────────────────────────
            if (report.summaryText.isNotEmpty) ...[
              _AiCard(report: report),
              const SizedBox(height: 16),
            ],

            // ─── 세션 요약 ────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('세션 요약',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _Stat(value: report.avgScore.toStringAsFixed(1), label: '평균 점수', color: _scoreColor),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _Stat(value: report.formattedDuration, label: '측정 시간', color: const Color(0xFF3B82F6)),
                      Container(width: 1, height: 40, color: Colors.white12),
                      _Stat(
                        value: _postureKo[report.dominantPosture] ?? report.dominantPosture,
                        label: '주요 자세',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── 자세 분포 ────────────────────────────────────
            if (report.postureDurationSec.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('자세 분포',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ..._postureOrder.map((posture) {
                        final sec = report.postureDurationSec[posture] ?? 0.0;
                        final ratio = report.totalSittingSec > 0 ? sec / report.totalSittingSec : 0.0;
                        final pct = (ratio * 100).toStringAsFixed(0);
                        final color = _postureColors[posture] ?? Colors.white54;
                        final label = _postureKo[posture] ?? posture;

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
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── AI 분석 카드 (상세 화면용) ──────────────────────────────────

class _AiCard extends StatelessWidget {
  final SavedReport report;
  const _AiCard({required this.report});

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
            Row(children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('AI 자세 분석',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),

            Text(report.summaryText,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
            const SizedBox(height: 14),

            if (report.trendText.isNotEmpty) ...[
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
                      child: Text(report.trendText,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (report.exerciseRecommendations.isNotEmpty) ...[
              const Text('추천 교정 운동',
                  style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...report.exerciseRecommendations.map((ex) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.fitness_center, color: Color(0xFF60A5FA), size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ex,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
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

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

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
