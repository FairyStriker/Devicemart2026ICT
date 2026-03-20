// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/stage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // 신규 프로필 폼
  final _userIdCtrl     = TextEditingController();
  final _nameCtrl       = TextEditingController();
  final _heightCtrl     = TextEditingController();
  final _weightCtrl     = TextEditingController();
  final _restWorkCtrl   = TextEditingController(text: '60');
  final _restBreakCtrl  = TextEditingController(text: '10');

  // 기존 프로필 선택
  final _existingIdCtrl = TextEditingController();

  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _userIdCtrl.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _restWorkCtrl.dispose();
    _restBreakCtrl.dispose();
    _existingIdCtrl.dispose();
    super.dispose();
  }

  // ─── 신규 등록 ────────────────────────────────────────────
  Future<void> _submitNewProfile() async {
    final app = context.read<AppStateProvider>();
    setState(() { _loading = true; _message = null; });

    final ok = await app.api.submitProfile(
      userId:       _userIdCtrl.text.trim(),
      name:         _nameCtrl.text.trim(),
      heightCm:     int.tryParse(_heightCtrl.text) ?? 170,
      weightKg:     int.tryParse(_weightCtrl.text) ?? 65,
      restWorkMin:  int.tryParse(_restWorkCtrl.text) ?? 60,
      restBreakMin: int.tryParse(_restBreakCtrl.text) ?? 10,
    );

    setState(() {
      _loading = false;
      _message = ok ? '프로필 등록 완료!' : '등록 실패 — 입력값을 확인해 주세요';
    });
  }

  // ─── 기존 선택 ────────────────────────────────────────────
  Future<void> _selectProfile() async {
    final app = context.read<AppStateProvider>();
    setState(() { _loading = true; _message = null; });

    final ok = await app.api.selectProfile(_existingIdCtrl.text.trim());

    setState(() {
      _loading = false;
      _message = ok ? '프로필 로드 완료!' : '프로필을 찾을 수 없습니다';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final s = app.stage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('프로필 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_off),
            tooltip: '연결 해제',
            onPressed: () => app.disconnect(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '신규 등록'),
            Tab(text: '기존 선택'),
          ],
        ),
      ),
      body: Column(
        children: [
          // stage 상태 배너
          _StageBanner(stage: s),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _NewProfileTab(
                  userIdCtrl:    _userIdCtrl,
                  nameCtrl:      _nameCtrl,
                  heightCtrl:    _heightCtrl,
                  weightCtrl:    _weightCtrl,
                  restWorkCtrl:  _restWorkCtrl,
                  restBreakCtrl: _restBreakCtrl,
                  loading:       _loading,
                  message:       _message,
                  onSubmit:      _submitNewProfile,
                ),
                _SelectProfileTab(
                  idCtrl:   _existingIdCtrl,
                  loading:  _loading,
                  message:  _message,
                  onSelect: _selectProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── stage 배너 ───────────────────────────────────────────────
class _StageBanner extends StatelessWidget {
  final String stage;
  const _StageBanner({required this.stage});

  @override
  Widget build(BuildContext context) {
    final stageLabels = {
      Stage.boot:          '시스템 부팅 중...',
      Stage.uartLinkReady: 'UART 연결 완료 — 프로필을 설정해 주세요',
      Stage.profileLoaded: '프로필 로드 완료',
    };
    final label = stageLabels[stage] ?? 'stage: $stage';

    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A5F),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(label,
          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13)),
    );
  }
}

// ─── 신규 등록 탭 ─────────────────────────────────────────────
class _NewProfileTab extends StatelessWidget {
  final TextEditingController userIdCtrl, nameCtrl, heightCtrl, weightCtrl,
      restWorkCtrl, restBreakCtrl;
  final bool loading;
  final String? message;
  final VoidCallback onSubmit;

  const _NewProfileTab({
    required this.userIdCtrl,
    required this.nameCtrl,
    required this.heightCtrl,
    required this.weightCtrl,
    required this.restWorkCtrl,
    required this.restBreakCtrl,
    required this.loading,
    required this.message,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(ctrl: userIdCtrl,    label: 'User ID',        hint: 'user_001'),
          _Field(ctrl: nameCtrl,      label: '이름'),
          _Field(ctrl: heightCtrl,    label: '키 (cm)',          keyboardType: TextInputType.number),
          _Field(ctrl: weightCtrl,    label: '몸무게 (kg)',       keyboardType: TextInputType.number),
          _Field(ctrl: restWorkCtrl,  label: '착석 알림 시간 (분)', keyboardType: TextInputType.number),
          _Field(ctrl: restBreakCtrl, label: '휴식 시간 (분)',     keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!,
                  style: TextStyle(
                      color: message!.contains('완료')
                          ? Colors.greenAccent
                          : Colors.redAccent)),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('프로필 등록',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 기존 선택 탭 ─────────────────────────────────────────────
class _SelectProfileTab extends StatelessWidget {
  final TextEditingController idCtrl;
  final bool loading;
  final String? message;
  final VoidCallback onSelect;

  const _SelectProfileTab({
    required this.idCtrl,
    required this.loading,
    required this.message,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _Field(ctrl: idCtrl, label: 'User ID', hint: 'user_001'),
          const SizedBox(height: 24),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!,
                  style: TextStyle(
                      color: message!.contains('완료')
                          ? Colors.greenAccent
                          : Colors.redAccent)),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('프로필 선택',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 공통 입력 필드 ───────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
