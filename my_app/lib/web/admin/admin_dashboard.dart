// lib/web/admin/admin_dashboard.dart
// 엔트리(웰컴 + 대시보드/탭 컨테이너)

import 'package:flutter/material.dart';
import '../constants.dart';
import '../admin_api.dart';
import 'admin_theme.dart';
import 'widgets.dart';
import 'model_stats_view.dart';
import 'admin_audit_panel.dart';
// 새 탭(시스템 통계)
import 'system_stats_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _adminKeyCtrl = TextEditingController();
  final _keyVisible = ValueNotifier<bool>(false);
  AdminApi? _api;
  late TabController _tab;

  // UI 중복 클릭 방지를 위한 상태 변수
  bool _isApplyingKey = false;

  bool get _authed => _api != null;

  @override
  void initState() {
    super.initState();
    // 탭 순서: 시스템 통계(새 탭) -> 모델 성능 -> 시스템 관리
    _tab = TabController(length: 3, vsync: this);
    
    // 탭 변경 시 인증 상태 확인
    _tab.addListener(() {
      if (!_authed && _tab.index != 0) {
        // 인증되지 않은 상태에서 다른 탭으로 이동 시도 시 첫 번째 탭으로 강제 이동
        _tab.animateTo(0);
        _toast('Admin Key 인증이 필요합니다', error: true);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _adminKeyCtrl.dispose();
    _keyVisible.dispose();
    super.dispose();
  }

  void _applyKey() async {
    // 중복 클릭 방지
    if (_isApplyingKey) {
      _toast('이미 처리 중입니다. 잠시 기다려주세요.', error: true);
      return;
    }
    
    final k = _adminKeyCtrl.text.trim();
    if (k.isEmpty) {
      _toast('Admin Key를 입력하세요', error: true);
      return;
    }
    
    setState(() {
      _isApplyingKey = true;
    });
    
    try {
      setState(() => _api = AdminApi(k));
      
      // 간단한 API 호출로 인증 테스트 (예: 오늘 통계 조회)
      await _api!.getStatsToday(tzOffsetMinutes: 540); // KST 기준
      _toast('Admin Key 인증 완료');
      // 인증 성공 시 첫 번째 탭으로 이동
      _tab.animateTo(0);
    } catch (e) {
      setState(() => _api = null); // 인증 실패 시 API 제거
      _toast(e.toString(), error: true);
    } finally {
      setState(() {
        _isApplyingKey = false;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  void _goHome() => Navigator.of(context).pushReplacementNamed('/');

  @override
  Widget build(BuildContext context) {
    if (!_authed) {
      return WelcomeBlock(
        adminKeyCtrl: _adminKeyCtrl,
        keyVisible: _keyVisible,
        onApply: _applyKey,
      );
    }

    return Scaffold(
      backgroundColor: AdminPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: AdminPalette.accent.withOpacity(.15),
            child: const Icon(Icons.shield_outlined, color: AdminPalette.accent),
          ),
        ),
        title: const Text(
          'PillyPilly Admin',
          style: TextStyle(
            color: AdminPalette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '홈으로',
            icon: const Icon(Icons.home_outlined, color: AdminPalette.textPrimary),
            onPressed: _goHome,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: TextField(
                controller: _adminKeyCtrl,
                obscureText: true,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'X-ADMIN-KEY',
                  hintStyle: const TextStyle(color: AdminPalette.textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: AdminPalette.panel2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _applyKey(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isApplyingKey ? null : _applyKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isApplyingKey
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('인증', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AdminPalette.panel.withOpacity(.55),
                  AdminPalette.textSecondary.withOpacity(.10),
                ],
              ),
              border: const Border(
                  bottom: BorderSide(color: AdminPalette.panel2, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('관리자 페이지',
                    style: TextStyle(
                      color: AdminPalette.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    HeaderTile(
                        icon: Icons.query_stats_rounded,
                        label: '시스템 통계',
                        color: AdminPalette.textPrimary),
                    HeaderTile(
                        icon: Icons.pie_chart_rounded,
                        label: '모델 성능',
                        color: AdminPalette.textSecondary),
                    HeaderTile(
                        icon: Icons.verified_user_rounded,
                        label: '시스템 관리',
                        color: AdminPalette.textPrimary),
                  ],
                ),
                const SizedBox(height: 16),
                // 인증된 상태에서만 탭 표시
                PillTabs(
                  tabController: _tab,
                  bg: AdminPalette.panel2,
                  active: Colors.white,
                  border: AdminPalette.panel2,
                  textActive: AdminPalette.textPrimary,
                  textInactive: AdminPalette.textSecondary,
                  labels: const ['시스템 통계', '모델 성능 통계', '시스템 관리'],
                ),
              ],
            ),
          ),
          // 인증된 상태에서만 탭 내용 표시
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // (1) 시스템 통계 — 새 탭 (첫 번째)
                SystemStatsView(api: _api, toast: _toast),
                // (2) 모델 성능 통계
                ModelStatsView(api: _api, toast: _toast),
                // (3) 시스템 관리
                AdminAuditPanel(api: _api, toast: _toast),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
