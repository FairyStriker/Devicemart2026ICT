// lib/widgets/chair_sensor_widget.dart

import 'package:flutter/material.dart';
import '../models/realtime_status_model.dart';

class ChairSensorWidget extends StatelessWidget {
  final RealtimeStatusModel status;

  const ChairSensorWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 범례
        Row(
          children: [
            _Legend(color: const Color(0xFF22C55E), label: '양호'),
            const SizedBox(width: 12),
            _Legend(color: Colors.orangeAccent, label: '주의'),
            const SizedBox(width: 12),
            _Legend(color: Colors.redAccent, label: '위험'),
          ],
        ),
        const SizedBox(height: 16),

        // 좌우 압력 분포 제목
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '좌석 압력 분포',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 좌우 균형 토글 표시
            _BalanceDot(level: status.loadcell.level),
          ],
        ),
        const SizedBox(height: 12),

        // 등받이 섹션
        _BackrestSection(spineTof: status.spineTof, neckTof: status.neckTof),
        const SizedBox(height: 10),

        // 좌석 섹션
        _SeatSection(loadcell: status.loadcell),
      ],
    );
  }
}

// ─── 등받이 (ToF 센서) ────────────────────────────────────────
class _BackrestSection extends StatelessWidget {
  final MonitoringMetric spineTof;
  final MonitoringMetric neckTof;

  const _BackrestSection({
    required this.spineTof,
    required this.neckTof,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E293B),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('등받이',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),

          // 중앙 ToF 센서 (VL53L8CX)
          Center(
            child: _SensorBox(
              label: 'VL53L8CX',
              value: '${neckTof.score.toStringAsFixed(0)}%',
              level: neckTof.level,
              isDashed: true,
            ),
          ),
          const SizedBox(height: 8),

          // 3x2 그리드 (좌상/우상 / 좌중ToF/우중 / 좌하/우하)
          _BackrestGrid(spineTof: spineTof),
        ],
      ),
    );
  }
}

class _BackrestGrid extends StatelessWidget {
  final MonitoringMetric spineTof;

  const _BackrestGrid({required this.spineTof});

  String get _score => spineTof.score.toStringAsFixed(0);
  String get _level => spineTof.level;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SensorBox(label: '좌상', value: '98%', level: 'good')),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorBox(
                label: 'ToF\n$_score%',
                value: '',
                level: _level,
                isDashed: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SensorBox(label: '우상', value: '97%', level: 'good')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _SensorBox(label: '좌중', value: '95%', level: 'good')),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorBox(
                label: 'ToF\n100%',
                value: '',
                level: 'good',
                isDashed: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SensorBox(label: '우중', value: '96%', level: 'good')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _SensorBox(label: '좌하', value: '93%', level: 'good')),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorBox(
                label: 'ToF\n${_score}%',
                value: '',
                level: _level,
                isDashed: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _SensorBox(label: '우하', value: '94%', level: 'good')),
          ],
        ),
      ],
    );
  }
}

// ─── 좌석 (로드셀) ─────────────────────────────────────────────
class _SeatSection extends StatelessWidget {
  final MonitoringMetric loadcell;

  const _SeatSection({required this.loadcell});

  String get _score => loadcell.score.toStringAsFixed(0);
  String get _level => loadcell.level;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E293B),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('좌석',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SensorBox(
                  label: '좌전',
                  value: '$_score%',
                  level: _level,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SensorBox(
                  label: '우전',
                  value: '$_score%',
                  level: _level,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SensorBox(
                  label: '좌후',
                  value: '$_score%',
                  level: _level,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SensorBox(
                  label: '우후',
                  value: '$_score%',
                  level: _level,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 센서 박스 ────────────────────────────────────────────────
class _SensorBox extends StatelessWidget {
  final String label;
  final String value;
  final String level;
  final bool isDashed;

  const _SensorBox({
    required this.label,
    required this.value,
    required this.level,
    this.isDashed = false,
  });

  Color get _color {
    switch (level) {
      case 'good':    return const Color(0xFF22C55E);
      case 'warning': return Colors.orangeAccent;
      case 'danger':  return Colors.redAccent;
      default:        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: isDashed
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _color,
                width: 1.5,
                style: BorderStyle.solid,
              ),
              color: _color.withOpacity(0.08),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _color.withOpacity(0.85),
            ),
      child: Center(
        child: Text(
          value.isEmpty ? label : '$label\n$value',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDashed ? _color : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

// ─── 공통 위젯 ────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _BalanceDot extends StatelessWidget {
  final String level;
  const _BalanceDot({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level == 'good'
        ? const Color(0xFF22C55E)
        : level == 'warning'
            ? Colors.orangeAccent
            : Colors.redAccent;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
