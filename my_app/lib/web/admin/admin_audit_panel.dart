// 탭2: 관리자 권한 작업

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

  final _actionCtrl = TextEditingController();
  int _page = 1;
  final _limit = 20;
  bool _busyLogs = false;
  int _total = 0;
  List<Map<String, dynamic>> _logs = [];

  AdminApi? get _client => widget.api;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _delUserIdCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _olderCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _block(bool unblock) async {
    final client = _client;
    if (client == null) return widget.toast('Admin Key 먼저 적용', error: true);
    final id = _userIdCtrl.text.trim();
    if (id.isEmpty) return widget.toast('user_id 입력', error: true);
    setState(() => _busyBlock = true);
    try {
      final r = unblock ? await client.unblockUser(id) : await client.blockUser(id);
      widget.toast(r['message']?.toString() ?? '완료');
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      setState(() => _busyBlock = false);
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
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      setState(() => _busyDelete = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    final client = _client;
    if (client == null) return widget.toast('Admin Key 먼저 적용', error: true);
    setState(() => _busyLogs = true);
    try {
      final r = await client.getAuditLogs(
        page: _page, limit: _limit,
        action: _actionCtrl.text.trim().isEmpty ? null : _actionCtrl.text,
      );
      _total = (r['total'] as num?)?.toInt() ?? 0;
      _logs = (r['logs'] as List?)?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      setState(() {});
    } catch (e) {
      widget.toast(e.toString(), error: true);
    } finally {
      setState(() => _busyLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminPalette.bg,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _card(
            title: '사용자 조치',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdCtrl,
                    style: const TextStyle(color: AdminPalette.textPrimary),
                    decoration: _input('user_id'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busyBlock ? null : () => _block(false),
                  style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.accent, foregroundColor: Colors.black),
                  child: _busyBlock
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('차단'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busyBlock ? null : () => _block(true),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AdminPalette.textSecondary)),
                  child: const Text('차단 해제'),
                ),
              ],
            ),
          ),

          _card(
            title: 'Database 로그 정리',
            child: Column(
              children: [
                Row(children: [
                  DropdownButton<String>(
                    value: _target,
                    dropdownColor: AdminPalette.panel2,
                    items: _targets.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: const TextStyle(color: AdminPalette.textPrimary)),
                    )).toList(),
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
                      controller: _startCtrl, readOnly: true,
                      style: const TextStyle(color: AdminPalette.textPrimary),
                      decoration: _input('시작일'),
                      onTap: () => _pick(_startCtrl),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _endCtrl, readOnly: true,
                      style: const TextStyle(color: AdminPalette.textPrimary),
                      decoration: _input('종료일'),
                      onTap: () => _pick(_endCtrl),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _olderCtrl, keyboardType: TextInputType.number,
                      style: const TextStyle(color: AdminPalette.textPrimary),
                      decoration: _input('older_than_days(선택)'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton(
                    onPressed: _busyDelete ? null : () => _delete(false),
                    style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.panel2, foregroundColor: AdminPalette.textPrimary),
                    child: _busyDelete
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('데이터 미리보기'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _busyDelete ? null : () => _delete(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('삭제 실행'),
                  ),
                ]),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AdminPalette.panel2, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(_result!),
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),

          _card(
            title: '관리자 권한 작업 로그 확인',
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _actionCtrl,
                      style: const TextStyle(color: AdminPalette.textPrimary),
                      decoration: _input('action 필터 (예: block_user, delete_data)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _busyLogs ? null : _loadAuditLogs,
                    style: ElevatedButton.styleFrom(backgroundColor: AdminPalette.panel2, foregroundColor: AdminPalette.textPrimary),
                    child: _busyLogs
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('조회'),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                    onPressed: _page > 1 && !_busyLogs ? () { setState(() => _page--); _loadAuditLogs(); } : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Text('$_page / ${(_total / _limit).ceil().clamp(1, 999999)}', style: const TextStyle(color: AdminPalette.textSecondary)),
                  IconButton(
                    onPressed: _page < ((_total / _limit).ceil().clamp(1, 999999)) && !_busyLogs
                        ? () { setState(() => _page++); _loadAuditLogs(); }
                        : null,
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 4),
                _logs.isEmpty
                    ? const Text('데이터 없음', style: TextStyle(color: AdminPalette.textSecondary))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AdminPalette.panel2),
                        itemBuilder: (_, i) {
                          final e = _logs[i];
                          final ts = e['timestamp']?.toString() ?? '';
                          final dt = ts.isNotEmpty ? (DateTime.tryParse(ts)?.toLocal().toString() ?? ts) : '-';
                          return ListTile(
                            dense: true,
                            title: Text('${e['action'] ?? '-'}  •  $dt', style: const TextStyle(color: AdminPalette.textPrimary)),
                            subtitle: Text(
                              'admin=${e['admin_id'] ?? '-'} • endpoint=${e['endpoint'] ?? '-'}\n${jsonEncode(e['details'] ?? {})}',
                              style: const TextStyle(color: AdminPalette.textSecondary),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 공통 카드/인풋
  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdminPalette.panel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AdminPalette.textSecondary),
        isDense: true,
        filled: true,
        fillColor: AdminPalette.panel2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
