// lib/providers/app_state_provider.dart

import 'package:flutter/material.dart';

import '../models/meta_model.dart';
import '../models/realtime_status_model.dart';
import '../models/sensor_distribution_model.dart';
import '../models/summary_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class AppStateProvider extends ChangeNotifier {
  final ApiService api = ApiService();
  late final WebSocketService _ws;

  // ─── 연결 상태 ────────────────────────────────────────────
  bool _connected = false;
  bool get connected => _connected;

  String _serverIp = '';
  String get serverIp => _serverIp;

  // ─── 시스템 stage ─────────────────────────────────────────
  MetaModel _meta = MetaModel.initial();
  MetaModel get meta => _meta;
  String get stage => _meta.stage;

  // ─── 실시간 자세 데이터 (50Hz) ────────────────────────────
  RealtimeStatusModel? _realtimeStatus;
  RealtimeStatusModel? get realtimeStatus => _realtimeStatus;

  // ─── 센서 분포 데이터 (~5Hz) ──────────────────────────────
  SensorDistributionModel? _sensorDistribution;
  SensorDistributionModel? get sensorDistribution => _sensorDistribution;

  // ─── stand event ─────────────────────────────────────────
  StandEvent? _pendingStandEvent;
  StandEvent? get pendingStandEvent => _pendingStandEvent;
  bool _standEventConsumed = false;

  // ─── 세션 결과 ────────────────────────────────────────────
  OverallSummary? _overallSummary;
  OverallSummary? get overallSummary => _overallSummary;

  final List<MinuteSummary> _minuteSummaries = [];
  List<MinuteSummary> get minuteSummaries => List.unmodifiable(_minuteSummaries);

  EnhancedReport? _enhancedReport;
  EnhancedReport? get enhancedReport => _enhancedReport;

  // ─── 실시간 로그 ──────────────────────────────────────────
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void _addLog(String msg) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _logs.insert(0, '[$ts] $msg');
    if (_logs.length > 200) _logs.removeLast();
  }

  AppStateProvider() {
    _ws = WebSocketService();
    _ws.onMeta = _handleMeta;
    _ws.onRealtimeStatus = _handleRealtimeStatus;
    _ws.onSensorDistribution = _handleSensorDistribution;
    _ws.onStandEvent = _handleStandEvent;
    _ws.onMinuteSummary = _handleMinuteSummary;
    _ws.onOverallSummary = _handleOverallSummary;
    _ws.onEnhancedReport = _handleEnhancedReport;
    _ws.onConnectionChanged = _handleConnectionChanged;
  }

  Future<void> init() async {}

  // ─── RPi 연결 ─────────────────────────────────────────────
  Future<bool> connect(String ip) async {
    api.setBaseUrl(ip);
    final data = await api.getMeta();
    if (data == null) {
      _connected = false;
      notifyListeners();
      return false;
    }
    _meta = MetaModel.fromJson(data);
    _connected = true;
    _serverIp = ip;
    _ws.connect(ip);
    _addLog('서버 연결 성공: $ip');
    notifyListeners();
    return true;
  }

  void disconnect() {
    _ws.disconnect();
    _connected = false;
    _meta = MetaModel.initial();
    notifyListeners();
  }

  // ─── WebSocket 연결 상태 변화 ─────────────────────────────
  void _handleConnectionChanged(bool wsConnected) {
    if (!wsConnected && _connected) {
      _addLog('WebSocket 연결 끊김 — 재연결 시도 중');
    } else if (wsConnected && _connected) {
      _addLog('WebSocket 재연결 성공');
    }
    notifyListeners();
  }

  // ─── type별 핸들러 ────────────────────────────────────────

  void _handleMeta(Map<String, dynamic> data) {
    final newStage = data['stage'] ?? '';
    if (newStage != _meta.stage) {
      _addLog('stage 변경: ${_meta.stage} → $newStage');
    }
    _meta = MetaModel.fromJson(data);
    _connected = true;
    notifyListeners();
  }

  void _handleRealtimeStatus(Map<String, dynamic> data) {
    final prev = _realtimeStatus;
    _realtimeStatus = RealtimeStatusModel.fromJson(data);
    if (prev == null ||
        prev.dominantPosture != _realtimeStatus!.dominantPosture) {
      _addLog('자세 변경: ${_realtimeStatus!.dominantPostureKo}');
    }
    if (prev != null && !prev.alert && _realtimeStatus!.alert) {
      _addLog('자세 경고 발생 (stage ${_realtimeStatus!.alertStage})');
    }
    notifyListeners();
  }

  void _handleSensorDistribution(Map<String, dynamic> data) {
    _sensorDistribution = SensorDistributionModel.fromJson(data);
    // 로그는 너무 빈번하므로 생략 (필요시 활성화)
    notifyListeners();
  }

  void _handleStandEvent(Map<String, dynamic> data) {
    if (!_standEventConsumed && _pendingStandEvent == null) {
      _pendingStandEvent = StandEvent.fromJson(data);
      _standEventConsumed = true;
      _addLog('STAND 이벤트 감지');
    }
    notifyListeners();
  }

  void _handleMinuteSummary(Map<String, dynamic> data) {
    final ms = MinuteSummary.fromJson(data);
    final exists =
        _minuteSummaries.any((m) => m.minuteIndex == ms.minuteIndex);
    if (!exists) {
      _minuteSummaries.add(ms);
      _addLog('분 요약 수신: ${ms.minuteIndex + 1}분차');
    }
    notifyListeners();
  }

  void _handleOverallSummary(Map<String, dynamic> data) {
    _overallSummary = OverallSummary.fromJson(data);
    _addLog('세션 결과 수신');
    notifyListeners();
  }

  void _handleEnhancedReport(Map<String, dynamic> data) {
    _enhancedReport = EnhancedReport.fromJson(data);
    _addLog('Enhanced report 수신');
    notifyListeners();
  }

  // ─── stand event 처리 완료 ────────────────────────────────
  void clearStandEvent() {
    _pendingStandEvent = null;
    Future.delayed(const Duration(seconds: 3), () {
      _standEventConsumed = false;
    });
    notifyListeners();
  }

  // ─── 세션 초기화 ─────────────────────────────────────────
  void resetSession() {
    _overallSummary = null;
    _minuteSummaries.clear();
    _realtimeStatus = null;
    _sensorDistribution = null;
    _enhancedReport = null;
    _logs.clear();
    _pendingStandEvent = null;
    _standEventConsumed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}
