// lib/models/stage.dart
// RPi session_state.py 와 동일한 stage 이름

class Stage {
  static const String boot                   = 'boot';
  static const String uartLinkReady          = 'uart_link_ready';
  static const String waitWifiClient         = 'wait_wifi_client';
  static const String waitProfile            = 'wait_profile';
  static const String profileLoaded          = 'profile_loaded';
  static const String waitCalibrationDecision = 'wait_calibration_decision';
  static const String waitSitForCalibration  = 'wait_sit_for_calibration';
  static const String calibrating            = 'calibrating';
  static const String calibrationCompleted   = 'calibration_completed';
  static const String waitStartDecision      = 'wait_start_decision';
  static const String waitSitForMeasure      = 'wait_sit_for_measure';
  static const String measuring              = 'measuring';
  static const String paused                 = 'paused';
  static const String waitRestartDecision    = 'wait_restart_decision';
  static const String measurementStopRequested = 'measurement_stop_requested';
  static const String sessionSaved           = 'session_saved';
  static const String sessionEnded           = 'session_ended';
}
