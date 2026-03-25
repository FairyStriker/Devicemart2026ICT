// lib/services/api_service.dart
//
// HTTP 통신 서비스
// - POST /command : 앱 → RPi 명령 전송
// - GET /meta     : 초기 연결 확인용 (이후 데이터는 WebSocket으로 수신)

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  String _baseUrl = '';

  void setBaseUrl(String ip) {
    _baseUrl = 'http://$ip:8000';
  }

  String get baseUrl => _baseUrl;
  bool get isConfigured => _baseUrl.isNotEmpty;

  // ─── GET /meta (초기 연결 확인 전용) ────────────────────
  Future<Map<String, dynamic>?> getMeta() async {
    return _get('/meta');
  }

  // ─── POST /command ────────────────────────────────────────
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(command),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['ok'] == true;
      }
      return false;
    } catch (e) {
      print('[ApiService] sendCommand error: $e');
      return false;
    }
  }

  // ─── 편의 메서드 (command 별) ────────────────────────────

  Future<bool> submitProfile({
    required String userId,
    required String name,
    required int heightCm,
    required int weightKg,
    required int restWorkMin,
    required int restBreakMin,
  }) =>
      sendCommand({
        'cmd': 'submit_profile',
        'user_id': userId,
        'name': name,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'rest_work_min': restWorkMin,
        'rest_break_min': restBreakMin,
      });

  Future<bool> selectProfile(String userId) =>
      sendCommand({'cmd': 'select_profile', 'user_id': userId});

  Future<bool> startCalibration() =>
      sendCommand({'cmd': 'start_calibration'});

  Future<bool> skipCalibration() =>
      sendCommand({'cmd': 'skip_calibration'});

  Future<bool> startMeasurement() =>
      sendCommand({'cmd': 'start_measurement'});

  Future<bool> pauseMeasurement() =>
      sendCommand({'cmd': 'pause_measurement'});

  Future<bool> resumeMeasurement() =>
      sendCommand({'cmd': 'resume_measurement'});

  Future<bool> quitMeasurement() =>
      sendCommand({'cmd': 'quit_measurement'});

  Future<bool> requestRecalibration() =>
      sendCommand({'cmd': 'request_recalibration'});

  Future<bool> resumeAfterStand() =>
      sendCommand({'cmd': 'resume_after_stand'});

  Future<bool> declineResumeAfterStand() =>
      sendCommand({'cmd': 'decline_resume_after_stand'});

  // ─── 내부 GET helper ─────────────────────────────────────
  Future<Map<String, dynamic>?> _get(String path) async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[ApiService] GET $path error: $e');
      return null;
    }
  }
}
