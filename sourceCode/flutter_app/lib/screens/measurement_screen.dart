// lib/screens/measurement_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/realtime_status_model.dart';
import '../models/sensor_distribution_model.dart';
import '../models/stage.dart';
import '../widgets/chair_sensor_widget.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // 다이얼로그 중복 방지 플래그
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // build 아닌 별도 메서드에서만 다이얼로그 트리거
  void _maybeShowStandDialog(AppStateProvider app) {
    if (_dialogShowing) return;
    if (app.pendingStandEvent == null) return;

    _dialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _dialogShowing = false;
        return;
      }
      _showStandDialog(app);
    });
  }

  void _showStandDialog(AppStateProvider app) {
    final event = app.pendingStandEvent;
    if (event == null) {
      _dialogShowing = false;
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('자리 이탈 감지',
            style: TextStyle(color: Colors.white)),
        content: Text(event.message,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              app.api.declineResumeAfterStand();
              app.clearStandEvent();
              _dialogShowing = false;
            },
            child: const Text('종료',
                style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              app.api.resumeAfterStand();
              app.clearStandEvent();
              _dialogShowing = false;
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB)),
            child: const Text('재시작'),
          ),
        ],
      ),
    ).then((_) {
      // 다이얼로그가 어떤 방식으로든 닫히면 플래그 해제
      _dialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final s = app.stage;

    // stand event → 다이얼로그 (중복 없이)
    if (app.pendingStandEvent != null) {
      _maybeShowStandDialog(app);
    }

    if (s == Stage.waitStartDecision) return _WaitStartScaffold(app: app);
    if (s == Stage.waitSitForMeasure) return _WaitSitScaffold();
    if (s == Stage.paused) return _PausedScaffold(app: app);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('실시간 측정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '재캘리브레이션',
            onPressed: () => app.api.requestRecalibration(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '대시보드'),
            Tab(text: '압력 분포'),
            Tab(text: '프로토콜'),
            Tab(text: '로그'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DashboardTab(status: app.realtimeStatus),
          _PressureTab(distribution: app.sensorDistribution),
          _ProtocolTab(stage: s, userId: app.meta.userId),
          _LogTab(logs: app.logs),   // ← provider 누적 로그 전달
        ],
      ),
      bottomNavigationBar: _BottomBar(app: app),
    );
  }
}

// ─── 대시보드 탭 ──────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final RealtimeStatusModel? status;
  const _DashboardTab({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text('데이터 수신 중...', style: TextStyle(color: Colors.white54)),
        ]),
      );
    }
    final st = status!;
    final alertColor = st.alert
        ? (st.alertStage >= 2 ? Colors.redAccent : Colors.orangeAccent)
        : const Color(0xFF22C55E);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('자세 점수',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(st.currentScore.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: alertColor)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (st.alert)
                  const Icon(Icons.warning_amber_rounded,
                      size: 32, color: Colors.orangeAccent),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: alertColor),
                  ),
                  child: Text(st.dominantPostureKo,
                      style: TextStyle(
                          color: alertColor,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _MonitorRow(
            icon: Icons.balance, label: '좌우 균형', metric: st.loadcell),
        const SizedBox(height: 8),
        _MonitorRow(
            icon: Icons.linear_scale, label: '척추 거리', metric: st.spineTof),
        const SizedBox(height: 8),
        _MonitorRow(
            icon: Icons.height, label: '목 거리', metric: st.neckTof),
        const SizedBox(height: 12),
        _FlagsCard(flags: st.flags),
      ]),
    );
  }
}

// ─── 압력 분포 탭 ─────────────────────────────────────────────
class _PressureTab extends StatelessWidget {
  final SensorDistributionModel? distribution;
  const _PressureTab({required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution == null) {
      return const Center(
          child: Text('센서 데이터 수신 중...',
              style: TextStyle(color: Colors.white54)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ChairSensorWidget(distribution: distribution),
    );
  }
}

// ─── 프로토콜 탭 ──────────────────────────────────────────────
class _ProtocolTab extends StatelessWidget {
  final String stage;
  final String? userId;
  const _ProtocolTab({required this.stage, required this.userId});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _ProtoRow(k: 'stage', v: stage),
      _ProtoRow(k: 'user_id', v: userId ?? '-'),
      _ProtoRow(k: 'connection', v: 'WebSocket'),
      _ProtoRow(k: 'command', v: 'HTTP POST /command'),
      _ProtoRow(k: 'ws_endpoint', v: 'ws://<IP>:8000/ws'),
      _ProtoRow(k: 'payload_types', v: '6종 (meta, status, ...)'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('현재 통신 상태',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

class _ProtoRow extends StatelessWidget {
  final String k, v;
  const _ProtoRow({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(v,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── 로그 탭 (누적) ───────────────────────────────────────────
class _LogTab extends StatelessWidget {
  final List<String> logs;
  const _LogTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('로그 대기 중...', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final log = logs[i];
        Color color = const Color(0xFF22C55E);
        if (log.contains('⚠') || log.contains('경고')) {
          color = Colors.orangeAccent;
        } else if (log.contains('stage 변경')) {
          color = const Color(0xFF60A5FA);
        } else if (log.contains('세션') || log.contains('분 요약')) {
          color = const Color(0xFFA78BFA);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            log,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}

// ─── 하단 버튼 ────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final AppStateProvider app;
  const _BottomBar({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => app.api.pauseMeasurement(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('일시정지',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => app.api.quitMeasurement(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('측정 종료',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────
class _MonitorRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final MonitoringMetric metric;
  const _MonitorRow(
      {required this.icon, required this.label, required this.metric});

  Color get _color {
    switch (metric.level) {
      case 'good':    return const Color(0xFF22C55E);
      case 'warning': return Colors.orangeAccent;
      default:        return Colors.redAccent;
    }
  }

  String get _levelKo {
    switch (metric.level) {
      case 'good':    return '양호';
      case 'warning': return '주의';
      default:        return '위험';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Text(metric.score.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _color, width: 1),
            ),
            child: Text(_levelKo,
                style: TextStyle(
                    color: _color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

class _FlagsCard extends StatelessWidget {
  final PostureFlags flags;
  const _FlagsCard({required this.flags});

  @override
  Widget build(BuildContext context) {
    final active = <String>[];
    if (flags.turtleNeck) active.add('거북목');
    if (flags.forwardLean) active.add('상체 굽힘');
    if (flags.reclined) active.add('누워 앉기');
    if (flags.sideSlouch) active.add('새우 자세');
    if (flags.legCrossSuspect) active.add('다리 꼬기');
    if (flags.thinkingPose) active.add('생각하는 자세');
    if (flags.perching) active.add('걸터앉기');

    if (active.isEmpty) {
      return Card(
        color: const Color(0xFF1A2E1A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: const [
            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
            SizedBox(width: 8),
            Text('활성 자세 경고 없음',
                style: TextStyle(color: Color(0xFF22C55E))),
          ]),
        ),
      );
    }

    return Card(
      color: const Color(0xFF3B1F1F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('감지된 자세',
              style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: active
                .map((a) => Chip(
                      label: Text(a,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white)),
                      backgroundColor:
                          Colors.redAccent.withOpacity(0.25),
                      side: const BorderSide(color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
}

// ─── 대기/정지 스캐폴드 ───────────────────────────────────────
class _WaitStartScaffold extends StatelessWidget {
  final AppStateProvider app;
  const _WaitStartScaffold({required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('측정 준비')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.play_circle_outline,
                size: 80, color: Color(0xFF2563EB)),
            const SizedBox(height: 24),
            const Text('측정을 시작할까요?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 40),
            _Btn(
                label: '측정 시작',
                color: const Color(0xFF2563EB),
                onPressed: () => app.api.startMeasurement()),
            const SizedBox(height: 12),
            _Btn(
                label: '취소',
                color: const Color(0xFF334155),
                onPressed: () => app.api.quitMeasurement()),
          ]),
        ),
      ),
    );
  }
}

class _WaitSitScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('착석 대기')),
      body: const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chair_alt, size: 80, color: Color(0xFF22C55E)),
              SizedBox(height: 24),
              Text('의자에 앉아주세요',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 12),
              Text('착석이 감지되면 자동으로 측정이 시작됩니다',
                  style: TextStyle(color: Colors.white60)),
            ]),
      ),
    );
  }
}

class _PausedScaffold extends StatelessWidget {
  final AppStateProvider app;
  const _PausedScaffold({required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('일시정지')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.pause_circle_outline,
                size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text('측정 일시정지',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 40),
            _Btn(
                label: '측정 재개',
                color: const Color(0xFF2563EB),
                onPressed: () => app.api.resumeMeasurement()),
            const SizedBox(height: 12),
            _Btn(
                label: '재캘리브레이션',
                color: const Color(0xFF334155),
                onPressed: () => app.api.requestRecalibration()),
            const SizedBox(height: 12),
            _Btn(
                label: '측정 종료',
                color: Colors.redAccent,
                onPressed: () => app.api.quitMeasurement()),
          ]),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _Btn(
      {required this.label,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
