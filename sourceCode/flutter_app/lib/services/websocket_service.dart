// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef JsonCallback = void Function(Map<String, dynamic> data);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  String _wsUrl = '';
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 10;

  // ─── type별 콜백 (7종) ───────────────────────────────────
  JsonCallback? onMeta;
  JsonCallback? onRealtimeStatus;
  JsonCallback? onSensorDistribution;   // ← 추가
  JsonCallback? onStandEvent;
  JsonCallback? onMinuteSummary;
  JsonCallback? onOverallSummary;
  JsonCallback? onEnhancedReport;

  void Function(bool connected)? onConnectionChanged;

  void connect(String ip) {
    _wsUrl = 'ws://$ip:8000/ws';
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    _cleanup();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      print('[WS] 연결 성공: $_wsUrl');
    } catch (e) {
      print('[WS] 연결 실패: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'meta':
          onMeta?.call(data);
          break;
        case 'realtime_status':
          onRealtimeStatus?.call(data);
          break;
        case 'sensor_distribution':
          onSensorDistribution?.call(data);
          break;
        case 'stand_event':
          onStandEvent?.call(data);
          break;
        case 'minute_summary':
          onMinuteSummary?.call(data);
          break;
        case 'overall_summary':
          onOverallSummary?.call(data);
          break;
        case 'enhanced_report':
          onEnhancedReport?.call(data);
          break;
        default:
          print('[WS] 알 수 없는 type: $type');
      }
    } catch (e) {
      print('[WS] 메시지 파싱 실패: $e');
    }
  }

  void _onError(Object error) {
    print('[WS] 에러: $error');
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }

  void _onDone() {
    print('[WS] 연결 종료');
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectAttempts++;
    final delay = _reconnectAttempts <= 4
        ? (1 << (_reconnectAttempts - 1))
        : _maxReconnectDelay;
    print('[WS] ${delay}초 후 재연결 시도 (#$_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_shouldReconnect) _doConnect();
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    print('[WS] 연결 해제');
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  bool get isConnected => _channel != null;
}
