// lib/services/polling_service.dart

import 'dart:async';
import 'api_service.dart';

typedef JsonCallback = void Function(Map<String, dynamic> data);

class PollingService {
  final ApiService api;

  Timer? _metaTimer;
  Timer? _statusTimer;
  Timer? _reportTimer;

  JsonCallback? onMeta;
  JsonCallback? onStatus;
  JsonCallback? onReport;

  PollingService({required this.api});

  void start() {
    _metaTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _pollMeta(),
    );
    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollStatus(),
    );
    _reportTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollReport(),
    );
  }

  void stop() {
    _metaTimer?.cancel();
    _statusTimer?.cancel();
    _reportTimer?.cancel();
  }

  Future<void> _pollMeta() async {
    final data = await api.getMeta();
    if (data != null) onMeta?.call(data);
  }

  Future<void> _pollStatus() async {
    final data = await api.getStatus();
    if (data != null && data['type'] != null) onStatus?.call(data);
  }

  Future<void> _pollReport() async {
    final data = await api.getReport();
    if (data != null && data['type'] != null) onReport?.call(data);
  }
}
