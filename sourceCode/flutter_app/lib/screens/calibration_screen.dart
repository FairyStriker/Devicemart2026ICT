// lib/screens/calibration_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/stage.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final s = app.stage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('캘리브레이션'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildContent(context, s, app),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, String stage, AppStateProvider app) {
    switch (stage) {
      // ─── 캘리브레이션 여부 결정 ─────────────────────────
      case Stage.waitCalibrationDecision:
        return _DecisionView(
          onStart: () => app.api.startCalibration(),
          onSkip:  () => app.api.skipCalibration(),
        );

      // ─── 앉아주세요 안내 ────────────────────────────────
      case Stage.waitSitForCalibration:
        return const _WaitSitView(
          message: '편안한 자세로 의자에 앉아주세요.\n캘리브레이션을 시작합니다.',
        );

      // ─── 캘리브레이션 중 ────────────────────────────────
      case Stage.calibrating:
        return const _CalibratingView();

      // ─── 완료 ────────────────────────────────────────────
      case Stage.calibrationCompleted:
        return _CompletedView(
          onStartMeasurement: () => app.api.startMeasurement(),
        );

      default:
        return Center(
          child: Text('stage: $stage',
              style: const TextStyle(color: Colors.white54)),
        );
    }
  }
}

// ─── 캘리브레이션 여부 선택 ───────────────────────────────────
class _DecisionView extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const _DecisionView({required this.onStart, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.tune, size: 80, color: Color(0xFF2563EB)),
        const SizedBox(height: 24),
        const Text('캘리브레이션이 필요합니다',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 12),
        const Text(
          '캘리브레이션은 사용자의 정자세를 기준으로\n자세를 측정합니다.\n저장된 기준값이 있으면 생략할 수 있습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, height: 1.6),
        ),
        const SizedBox(height: 40),
        _BigButton(
          label: '캘리브레이션 시작',
          color: const Color(0xFF2563EB),
          onPressed: onStart,
        ),
        const SizedBox(height: 12),
        _BigButton(
          label: '이전 기준값으로 시작',
          color: const Color(0xFF334155),
          onPressed: onSkip,
        ),
      ],
    );
  }
}

// ─── 앉아주세요 대기 ──────────────────────────────────────────
class _WaitSitView extends StatelessWidget {
  final String message;
  const _WaitSitView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PulsingIcon(icon: Icons.chair_alt, color: Color(0xFF22C55E)),
        const SizedBox(height: 32),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, color: Colors.white, height: 1.6)),
        const SizedBox(height: 16),
        const Text('의자에 앉으면 자동으로 시작됩니다',
            style: TextStyle(color: Colors.white38)),
      ],
    );
  }
}

// ─── 캘리브레이션 진행 중 ─────────────────────────────────────
class _CalibratingView extends StatelessWidget {
  const _CalibratingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: Color(0xFF2563EB),
          strokeWidth: 4,
        ),
        SizedBox(height: 32),
        Text('캘리브레이션 중...',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 12),
        Text('10초 동안 편안한 정자세를 유지해 주세요',
            style: TextStyle(color: Colors.white60)),
      ],
    );
  }
}

// ─── 완료 뷰 ──────────────────────────────────────────────────
class _CompletedView extends StatelessWidget {
  final VoidCallback onStartMeasurement;
  const _CompletedView({required this.onStartMeasurement});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 80, color: Color(0xFF22C55E)),
        const SizedBox(height: 24),
        const Text('캘리브레이션 완료',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        const Text('정자세 기준이 설정되었습니다.',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 40),
        _BigButton(
          label: '측정 시작',
          color: const Color(0xFF2563EB),
          onPressed: onStartMeasurement,
        ),
      ],
    );
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────
class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _BigButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

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

// ─── 깜빡이는 아이콘 ──────────────────────────────────────────
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Icon(widget.icon, size: 80, color: widget.color),
    );
  }
}
