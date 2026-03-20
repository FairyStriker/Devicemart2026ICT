// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'models/stage.dart';
import 'screens/splash_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/calibration_screen.dart';
import 'screens/measurement_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = AppStateProvider();
  await provider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const PostureApp(),
    ),
  );
}

class PostureApp extends StatelessWidget {
  const PostureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POSTURE AI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const RootNavigator(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
}

// ─── stage → 화면 라우팅 ──────────────────────────────────────
class RootNavigator extends StatelessWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();

    // 연결 안 됨 → Splash (IP 입력)
    if (!app.connected) {
      return const SplashScreen();
    }

    final s = app.stage;

    // 프로필 단계
    if (s == Stage.uartLinkReady ||
        s == Stage.waitProfile ||
        s == Stage.profileLoaded ||
        s == Stage.boot) {
      return const ProfileScreen();
    }

    // 캘리브레이션 단계
    if (s == Stage.waitCalibrationDecision ||
        s == Stage.waitSitForCalibration ||
        s == Stage.calibrating ||
        s == Stage.calibrationCompleted) {
      return const CalibrationScreen();
    }

    // 측정 단계
    if (s == Stage.waitStartDecision ||
        s == Stage.waitSitForMeasure ||
        s == Stage.measuring ||
        s == Stage.paused ||
        s == Stage.waitRestartDecision ||
        s == Stage.measurementStopRequested) {
      return const MeasurementScreen();
    }

    // 결과 단계
    if (s == Stage.sessionSaved || s == Stage.sessionEnded) {
      return const ReportScreen();
    }

    // fallback
    return const SplashScreen();
  }
}
