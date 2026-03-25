// lib/widgets/chair_sensor_widget.dart
//
// sensor_distribution type 데이터를 시각화
// 시뮬레이터(SPCC-Simulator.jsx)와 동일한 레이아웃:
//   VL53L8CX (목/머리) → 등받이 3열4행 → 좌석 2x2 → 센서바 리스트

import 'package:flutter/material.dart';
import '../models/sensor_distribution_model.dart';

class ChairSensorWidget extends StatelessWidget {
  final SensorDistributionModel? distribution;

  const ChairSensorWidget({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution == null) {
      return const Center(
        child: Text('센서 데이터 대기 중...',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final d = distribution!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 범례
        Row(children: const [
          _Legend(color: Color(0xFF22C55E), label: '양호'),
          SizedBox(width: 12),
          _Legend(color: Colors.orangeAccent, label: '주의'),
          SizedBox(width: 12),
          _Legend(color: Colors.redAccent, label: '위험'),
        ]),
        const SizedBox(height: 16),

        const Text('좌석 압력 분포',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // VL53L8CX (목/머리)
        _HeadTofBox(headTof: d.headTof),
        const SizedBox(height: 8),

        // 등받이 3열4행
        _BackrestSection(
          backPressure: d.backPressure,
          spineTof: d.spineTof,
        ),
        const SizedBox(height: 10),

        // 좌석 2x2
        _SeatSection(seatPressure: d.seatPressure),
        const SizedBox(height: 16),

        // 센서바 리스트
        _SensorListSection(distribution: d),
      ],
    );
  }
}

// ─── VL53L8CX 머리/목 ToF ──────────────────────────────────────
class _HeadTofBox extends StatelessWidget {
  final HeadTofDist headTof;
  const _HeadTofBox({required this.headTof});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SensorBox(
        label: 'VL53L8CX\n${headTof.overallPercent.toStringAsFixed(0)}%',
        level: headTof.overallLevel,
        isDashed: true,
        width: 140,
      ),
    );
  }
}

// ─── 등받이 (좌압력8 + 중앙ToF4) ────────────────────────────────
class _BackrestSection extends StatelessWidget {
  final BackPressureDist backPressure;
  final SpineTofDist spineTof;

  const _BackrestSection({
    required this.backPressure,
    required this.spineTof,
  });

  static const _leftLabels  = ['좌상', '좌중상', '좌중하', '좌하'];
  static const _rightLabels = ['우상', '우중상', '우중하', '우하'];

  @override
  Widget build(BuildContext context) {
    final leftCells  = backPressure.leftCells;
    final rightCells = backPressure.rightCells;
    final tofCells   = spineTof.cells;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E293B),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        const Text('등받이',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 10),
        for (int row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(children: [
            // 좌측 압력
            Expanded(
              child: _SensorBox(
                label: _leftLabels[row],
                value: '${leftCells[row].percent.toStringAsFixed(0)}%',
                level: leftCells[row].level,
              ),
            ),
            const SizedBox(width: 8),
            // 중앙 ToF
            Expanded(
              child: _SensorBox(
                label: 'ToF\n${tofCells[row].percent.toStringAsFixed(0)}%',
                level: tofCells[row].level,
                isDashed: true,
              ),
            ),
            const SizedBox(width: 8),
            // 우측 압력
            Expanded(
              child: _SensorBox(
                label: _rightLabels[row],
                value: '${rightCells[row].percent.toStringAsFixed(0)}%',
                level: rightCells[row].level,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ─── 좌석 2x2 ───────────────────────────────────────────────────
class _SeatSection extends StatelessWidget {
  final SeatPressureDist seatPressure;
  const _SeatSection({required this.seatPressure});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E293B),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        const Text('좌석',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _CellBox(label: '뒤왼', cell: seatPressure.rearLeft)),
          const SizedBox(width: 8),
          Expanded(child: _CellBox(label: '뒤오른', cell: seatPressure.rearRight)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _CellBox(label: '앞왼', cell: seatPressure.frontLeft)),
          const SizedBox(width: 8),
          Expanded(child: _CellBox(label: '앞오른', cell: seatPressure.frontRight)),
        ]),
      ]),
    );
  }
}

class _CellBox extends StatelessWidget {
  final String label;
  final SensorCell cell;
  const _CellBox({required this.label, required this.cell});

  @override
  Widget build(BuildContext context) {
    return _SensorBox(
      label: label,
      value: '${cell.percent.toStringAsFixed(0)}%',
      level: cell.level,
    );
  }
}

// ─── 센서바 리스트 ───────────────────────────────────────────────
class _SensorListSection extends StatelessWidget {
  final SensorDistributionModel distribution;
  const _SensorListSection({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final bp = distribution.backPressure;
    final sp = distribution.seatPressure;
    final tof = distribution.spineTof;
    final head = distribution.headTof;

    final items = <_BarItem>[
      _BarItem('등 좌상',    bp.leftTop),
      _BarItem('등 좌중상',  bp.leftUpperMid),
      _BarItem('등 좌중하',  bp.leftLowerMid),
      _BarItem('등 좌하',    bp.leftBottom),
      _BarItem('등 우상',    bp.rightTop),
      _BarItem('등 우중상',  bp.rightUpperMid),
      _BarItem('등 우중하',  bp.rightLowerMid),
      _BarItem('등 우하',    bp.rightBottom),
      _BarItem('좌석 뒤왼',  sp.rearLeft),
      _BarItem('좌석 뒤오른', sp.rearRight),
      _BarItem('좌석 앞왼',  sp.frontLeft),
      _BarItem('좌석 앞오른', sp.frontRight),
      _BarItem('척추 상',    tof.upper),
      _BarItem('척추 중상',  tof.upperMid),
      _BarItem('척추 중하',  tof.lowerMid),
      _BarItem('척추 하',    tof.lower),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text('밀어서 척추 분석',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _SensorBar(item: item)),
        // 목 ToF 별도 표시
        _SensorBarSimple(
          label: '목 ToF',
          percent: head.overallPercent,
          level: head.overallLevel,
        ),
      ],
    );
  }
}

class _BarItem {
  final String label;
  final SensorCell cell;
  _BarItem(this.label, this.cell);
}

class _SensorBar extends StatelessWidget {
  final _BarItem item;
  const _SensorBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(item.cell.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        SizedBox(width: 80,
            child: Text(item.label,
                style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item.cell.percent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36,
            child: Text('${item.cell.percent.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontSize: 12))),
      ]),
    );
  }
}

class _SensorBarSimple extends StatelessWidget {
  final String label;
  final double percent;
  final String level;
  const _SensorBarSimple({
    required this.label, required this.percent, required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        SizedBox(width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36,
            child: Text('${percent.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontSize: 12))),
      ]),
    );
  }
}

// ─── 센서 박스 ────────────────────────────────────────────────────
class _SensorBox extends StatelessWidget {
  final String label;
  final String? value;
  final String level;
  final bool isDashed;
  final double? width;

  const _SensorBox({
    required this.label, this.value, required this.level,
    this.isDashed = false, this.width,
  });

  Color get _color => _levelColor(level);

  @override
  Widget build(BuildContext context) {
    final text = (value != null && value!.isNotEmpty)
        ? '$label\n$value' : label;
    return Container(
      height: 52,
      width: width,
      decoration: isDashed
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _color, width: 1.5),
              color: _color.withOpacity(0.08),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _color.withOpacity(0.85),
            ),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDashed ? _color : Colors.white,
              fontSize: 11, fontWeight: FontWeight.bold, height: 1.3,
            )),
      ),
    );
  }
}

// ─── 공통 ────────────────────────────────────────────────────────

Color _levelColor(String level) {
  switch (level) {
    case 'good':    return const Color(0xFF22C55E);
    case 'warning': return Colors.orangeAccent;
    case 'danger':  return Colors.redAccent;
    default:        return Colors.white54;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}
