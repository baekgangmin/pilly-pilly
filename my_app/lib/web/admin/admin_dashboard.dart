// 엔트리(웰컴 + 대시보드/탭 컨테이너)

import 'package:flutter/material.dart';
import '../constants.dart';
import '../admin_api.dart';
import 'admin_theme.dart';
import 'widgets.dart';
import 'model_stats_view.dart';
import 'admin_audit_panel.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _adminKeyCtrl = TextEditingController();
  final _keyVisible = ValueNotifier<bool>(false);
  AdminApi? _api;
  late TabController _tab;

  bool get _authed => _api != null;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _adminKeyCtrl.dispose();
    _keyVisible.dispose();
    super.dispose();
  }

  void _applyKey() {
    final k = _adminKeyCtrl.text.trim();
    if (k.isEmpty) {
      _toast('Admin Key를 입력하세요', error: true);
      return;
    }
    setState(() => _api = AdminApi(k));
    _toast('Admin Key 설정 완료');
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _applyKey(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _applyKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('적용', style: TextStyle(fontWeight: FontWeight.w700)),
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
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  AdminPalette.panel.withOpacity(.55),
                  AdminPalette.textSecondary.withOpacity(.10),
                ],
              ),
              border: const Border(bottom: BorderSide(color: AdminPalette.panel2, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('대시보드',
                    style: TextStyle(
                      color: AdminPalette.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: const [
                    HeaderTile(icon: Icons.pie_chart_rounded, label: '모델 성능', color: AdminPalette.textSecondary),
                    HeaderTile(icon: Icons.verified_user_rounded, label: '시스템 관리', color: AdminPalette.textPrimary),
                  ],
                ),
                const SizedBox(height: 16),
                PillTabs(
                  tabController: _tab,
                  bg: AdminPalette.panel2,
                  active: Colors.white,
                  border: AdminPalette.panel2,
                  textActive: AdminPalette.textPrimary,
                  textInactive: AdminPalette.textSecondary,
                  labels: const ['모델 성능 통계', '시스템 관리'],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                ModelStatsView(api: _api, toast: _toast),
                AdminAuditPanel(api: _api, toast: _toast),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
