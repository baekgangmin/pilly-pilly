// lib/web/admin/admin_audit_panel.dart
// 탭2: 시스템 관리(관리자 권한 작업) + KPI 카드 (action 드롭다운/그리드 레이아웃 고정)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_theme.dart';
import '../admin_api.dart';

class AdminAuditPanel extends StatefulWidget {
  final AdminApi? api;
  final void Function(String, {bool error}) toast;

  const AdminAuditPanel({super.key, required this.api, required this.toast});

  @override
  State<AdminAuditPanel> createState() => _AdminAuditPanelState();
}

class _AdminAuditPanelState extends State<AdminAuditPanel> {
  // --- 상태/폼 컨트롤러 ---
  final _userIdCtrl = TextEditingController();
  bool _busyBlock = false;

  final _targets = ['model_logs', 'search_logs', 'chat_logs', 'user_favorite_logs'];
  String _target = 'search_logs';
  final _delUserIdCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _olderCtrl = TextEditingController(text: '1');
  bool _busyDelete = false;
  Map<String, dynamic>? _result;

  // (변경) action 텍스트필드 -> 드롭다운 상태
  final List<String> _actionOptions = [
    '', // 전체(필터 없음)
    'block_user',
    'unblock_user',
    'delete_data',
  ];
  String _selectedAction = '';
  int _page = 1;
  final _limit = 20;
  bool _busyLogs = false;
  int _total = 0;
  List<Map<String, dynamic>> _logs = [];

  // --- KPI 상태 ---
  bool _loadingKpi = false;
  int? _blockedTotal;                // 현재까지 차단 수 (감사 로그 total)
  DateTime? _lastDeleteAt;           // 최근 DB 삭제 일자 (감사 로그의 최신 timestamp)

  AdminApi? get _client => widget.api;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  @override
  void didUpdateWidget(covariant AdminAuditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      _loadKpis();
    }
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _delUserIdCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _olderCtrl.dispose();
    super.dispose();
  }

  /* ===================== 공통 유틸 ===================== */

  Future<void> _pick(TextEditingController c) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AdminPalette.accent,
            surface: AdminPalette.panel2,
            onSurface: AdminPalette.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) c.text = DateFormat('yyyy-MM-dd').format(d);
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);

  /// 서버에서 내려온 ISO 문자열을 안전하게 DateTime으로 변환.
  /// Z 또는 +09:00/-03:00 같은 타임존 오프셋이 있으면 local로 변환, 없으면 그대로 사용.
  DateTime? _parseServerTs(String ts) {
    try {
      final d = DateTime.parse(ts);
      final hasTz = ts.endsWith('Z') ||
          RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(ts); // +00:00 / -03:00 등
      return hasTz ? d.toLocal() : d;
    } catch (_) {
      return null;
    }
  }

  /* ===================== KPI 로드 ===================== */
  Future<void> _loadKpis() async {
    final client = _client;
    if (client == null) return;
    setState(() => _loadingKpi = true);

    try {
      final rBlock = await client.getAuditLogs(page: 1, limit: 1, action: 'block_user');
      final blockedTotal = (rBlock['total'] as num?)?.toInt();

      final rDelete = await client.getAuditLogs(page: 1, limit: 50, action: 'delete_data');
      DateTime? latest;
      final logs = (rDelete['logs'] as List?)?.cast<Map>() ?? const [];
      for (final e in logs) {
      final ts = e['timestamp']?.toString() ?? '';
      final parsed = _parseServerTs(ts);
      if (parsed != null) {
        if (latest == null || parsed.isAfter(latest!)) latest = parsed;
      }
      }

      if (!mounted) return;
      setState(() {
        _blockedTotal = blockedTotal;
        _lastDeleteAt = latest;
      });
    } catch (e) {
      widget.toast('KPI 로드 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingKpi = false);
    }
  }

  /* ===================== 권한 작업 ===================== */

  Future<void> _block(bool unblock) async {
    final client = _client;
    if (client == null) return widget.toast('Admin Key 먼저 적용', error: true);
    final id = _userIdCtrl.text.trim();
    if (id.isEmpty) return widget.toast('user_id 입력', error: true);
    setState(() => _busyBlock = true);
    try {
      final r = unblock ? await client.unblockUser(id) : await client.blockUser(id);
      widget.toast(r['message']?.toString() ?? '완료');
      _loadKpis();
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyBlock = false);
    }
  }

  Future<void> _delete(bool hard) async {
    final client = _client;
    if (client == null) return widget.toast('Admin Key 먼저 적용', error: true);
    setState(() => _busyDelete = true);
    try {
      final older = int.tryParse(_olderCtrl.text.trim());
      final r = await client.deleteData(
        target: _target,
        dryRun: !hard,
        hard: hard,
        start: _startCtrl.text.isNotEmpty ? _startCtrl.text : null,
        end: _endCtrl.text.isNotEmpty ? _endCtrl.text : null,
        userId: _delUserIdCtrl.text.isNotEmpty ? _delUserIdCtrl.text : null,
        olderThanDays: older,
      );
      setState(() => _result = r);
      widget.toast(r['메시지']?.toString() ?? (hard ? '삭제 완료' : '미리보기 완료'));
      if (hard) _loadKpis();
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyDelete = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    final client = _client;
    if (client == null) return widget.toast('Admin Key 먼저 적용', error: true);
    setState(() => _busyLogs = true);
    try {
      final r = await client.getAuditLogs(
        page: _page,
        limit: _limit,
        action: (_selectedAction.isEmpty) ? null : _selectedAction, // ✓ 드롭다운 값 사용
      );
      _total = (r['total'] as num?)?.toInt() ?? 0;
      _logs = (r['logs'] as List?)
              ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      setState(() {});
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyLogs = false);
    }
  }

  /* ===================== UI ===================== */

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, bx) {
        final maxW = bx.maxWidth;
        const gap = 16.0;

        // 그리드 컬럼 수 결정
        int cols;
        if (maxW >= 1200) cols = 3;
        else if (maxW >= 820) cols = 2;
        else cols = 1;

        // KPI 그리드는 2개만 쓰지만, 같은 규칙으로 폭 계산
        int kpiCols = (cols >= 2) ? 2 : 1;

        return Container(
          color: AdminPalette.bg,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ---------- 상단 KPI (고정 카드 높이) ----------
                _grid(
                  columns: kpiCols,
                  gap: gap,
                  childAspectRatio: 3.8,   // 가로로 넓고 납작한 카드
                  children: [
                    _kpiCard(
                      icon: Icons.block_rounded,
                      label: '현재까지 사용자 차단 수',
                      value: _loadingKpi ? '로딩 중…' : (_blockedTotal?.toString() ?? '-'),
                      trailing: _ghostCTA('새로고침', onTap: _loadingKpi ? null : _loadKpis),
                    ),
                    _kpiCard(
                      icon: Icons.delete_forever_rounded,
                      label: '최근 DB 삭제 일자',
                      value: _loadingKpi ? '로딩 중…' : (_lastDeleteAt != null ? _fmtDate(_lastDeleteAt!) : '-'),
                      trailing: _ghostCTA('새로고침', onTap: _loadingKpi ? null : _loadKpis),
                    ),
                  ],
                ),
                const SizedBox(height: gap),

                // ---------- 메인 섹션 (고정 카드 높이) ----------
                _grid(
                  columns: cols,
                  gap: gap,
                  childAspectRatio: 1.6,   // 카드들의 가로세로 비
                  children: [
                    _section(
                      icon: Icons.verified_user_rounded,
                      title: '사용자 조치',
                      trailing: _primaryCTA(label: '실행', onTap: _openUserActionSheet),
                      child: _inlineUserForm(),
                    ),
                    _section(
                      icon: Icons.storage_rounded,
                      title: 'Database 로그 정리',
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _ghostCTA('미리보기', onTap: _busyDelete ? null : () => _delete(false)),
                        const SizedBox(width: 8),
                        _dangerCTA('삭제 실행', onTap: _busyDelete ? null : () => _delete(true)),
                      ]),
                      child: _cleanupForm(),
                    ),
                    _section(
                      icon: Icons.fact_check_rounded,
                      title: '관리자 권한 작업 로그 확인',
                      trailing: _ghostCTA('조회', onTap: _busyLogs ? null : _loadAuditLogs),
                      child: _auditList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ---------- 공통 그리드 ---------- */
  Widget _grid({
    required int columns,
    required double gap,
    required double childAspectRatio,
    required List<Widget> children,
  }) {
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children
          .map((w) => Container( // 각 셀은 카드가 화면을 “꽉” 채우도록 BoxConstraints 제공
                constraints: const BoxConstraints(minHeight: 220),
                child: w,
              ))
          .toList(),
    );
  }

  /* ---------- KPI 카드 ---------- */
  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPalette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _iconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 수직 가운데 정렬
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      color: AdminPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                      color: AdminPalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    )),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /* ---------- 공통 섹션/CTA ---------- */

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    // 내부 컨텐츠가 적어도 동일 높이를 유지하도록 Column + Expanded
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPalette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _iconBadge(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AdminPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          // 본문은 남는 공간을 채우고 내부 스크롤은 금지(그리드가 스크롤 담당)
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminPalette.panel2),
      ),
      child: Icon(icon, color: AdminPalette.textSecondary),
    );
  }

  Widget _primaryCTA({required String label, VoidCallback? onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminPalette.accent,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _ghostCTA(String label, {VoidCallback? onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminPalette.panel2,
        foregroundColor: AdminPalette.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }

  Widget _dangerCTA(String label, {VoidCallback? onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }

  /* ---------- 사용자 조치 ---------- */
  Widget _inlineUserForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userIdCtrl,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: _input('user_id'),
              ),
            ),
            const SizedBox(width: 8),
            _primaryCTA(
              label: _busyBlock ? '처리 중…' : '차단',
              onTap: _busyBlock ? null : () => _block(false),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busyBlock ? null : () => _block(true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AdminPalette.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('차단 해제'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openUserActionSheet,
            child: const Text('자세히 보기', style: TextStyle(color: AdminPalette.textSecondary)),
          ),
        ),
      ],
    );
  }

  void _openUserActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: const [
              Icon(Icons.verified_user_rounded, color: AdminPalette.textSecondary),
              SizedBox(width: 8),
              Text('사용자 조치 (자세히)', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _userIdCtrl,
              style: const TextStyle(color: AdminPalette.textPrimary),
              decoration: _input('user_id'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _primaryCTA(label: '차단', onTap: _busyBlock ? null : () { Navigator.pop(context); _block(false); })),
                const SizedBox(width: 8),
                Expanded(child: _ghostCTA('차단 해제', onTap: _busyBlock ? null : () { Navigator.pop(context); _block(true); })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- 데이터 정리 ---------- */
  Widget _cleanupForm() {
    // 섹션 내부에서 높이가 고정되므로, 이 위젯 자체가 스크롤 가능해야 함
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            DropdownButton<String>(
              value: _target,
              dropdownColor: AdminPalette.panel2,
              items: _targets
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(color: AdminPalette.textPrimary)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _target = v!),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _delUserIdCtrl,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: _input('user_id(선택)'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: _startCtrl,
                readOnly: true,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: _input('시작일'),
                onTap: () => _pick(_startCtrl),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _endCtrl,
                readOnly: true,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: _input('종료일'),
                onTap: () => _pick(_endCtrl),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _olderCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AdminPalette.textPrimary),
                decoration: _input('older_than_days(선택)'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openCleanupSheet,
              child: const Text('자세히 보기', style: TextStyle(color: AdminPalette.textSecondary)),
            ),
          ),

          // ▼ JSON 미리보기: 고정 높이 + 내부 스크롤
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminPalette.panel2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: 200, // 필요시 160~280 사이로 조정
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_result!),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AdminPalette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openCleanupSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: const [
              Icon(Icons.storage_rounded, color: AdminPalette.textSecondary),
              SizedBox(width: 8),
              Text('Database 로그 정리 (자세히)', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            _cleanupForm(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _ghostCTA('미리보기', onTap: _busyDelete ? null : () { Navigator.pop(context); _delete(false); })),
                const SizedBox(width: 8),
                Expanded(child: _dangerCTA('삭제 실행', onTap: _busyDelete ? null : () { Navigator.pop(context); _delete(true); })),
              ],
            ),
          ],
        ),
      ),
    );
  }

/* ---------- 감사 로그 ---------- */
Widget _auditList() {
  return Column(
    children: [
      // 액션 필터 + 조회 버튼
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedAction,
            dropdownColor: AdminPalette.panel2,
            decoration: _input('action 필터 선택'),
            items: _actionOptions.map((a) {
              final label = a.isEmpty ? '전체 (필터 없음)' : a;
              return DropdownMenuItem(
                value: a,
                child: Text(label, style: const TextStyle(color: AdminPalette.textPrimary)),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedAction = v ?? ''),
          ),
        ),
        const SizedBox(width: 8),
        _ghostCTA('조회', onTap: _busyLogs ? null : _loadAuditLogs),
      ]),

      const SizedBox(height: 10),

      // 페이지네이션
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(
          onPressed: _page > 1 && !_busyLogs
              ? () {
                  setState(() => _page--);
                  _loadAuditLogs();
                }
              : null,
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Text(
          '$_page / ${(_total / _limit).ceil().clamp(1, 999999)}',
          style: const TextStyle(color: AdminPalette.textSecondary),
        ),
        IconButton(
          onPressed: _page < ((_total / _limit).ceil().clamp(1, 999999)) && !_busyLogs
              ? () {
                  setState(() => _page++);
                  _loadAuditLogs();
                }
              : null,
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ]),

      const SizedBox(height: 6),

      // 리스트(스크롤 가능)
      Expanded(
        child: _logs.isEmpty
            ? const Center(
                child: Text('데이터 없음', style: TextStyle(color: AdminPalette.textSecondary)),
              )
            : ListView.separated(
                physics: const ClampingScrollPhysics(),
                shrinkWrap: false,
                itemCount: _logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AdminPalette.panel2),
                itemBuilder: (_, i) {
                  final e = _logs[i];
                  final ts = e['timestamp']?.toString() ?? '';
                  final d  = ts.isNotEmpty ? _parseServerTs(ts) : null;
                  final dt = d != null ? _fmtDate(d) : '-';

                  return ListTile(
                    dense: true,
                    title: Text(
                      '${e['action'] ?? '-'}  •  $dt',
                      style: const TextStyle(color: AdminPalette.textPrimary),
                    ),
                    subtitle: Text(
                      'admin=${e['admin_id'] ?? '-'} • endpoint=${e['endpoint'] ?? '-'}'
                      '\n${jsonEncode(e['details'] ?? {})}',
                      style: const TextStyle(color: AdminPalette.textSecondary, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

  /* ---------- 공통 인풋 ---------- */
  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AdminPalette.textSecondary),
        isDense: true,
        filled: true,
        fillColor: AdminPalette.panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
