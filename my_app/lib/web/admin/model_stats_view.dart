// 탭1: 모델 성능 통계

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_theme.dart';
import 'widgets.dart';
import '../admin_api.dart';

class ModelStatsView extends StatefulWidget {
  final AdminApi? api;
  final void Function(String, {bool error}) toast;

  const ModelStatsView({super.key, required this.api, required this.toast});

  @override
  State<ModelStatsView> createState() => _ModelStatsViewState();
}

class _ModelStatsViewState extends State<ModelStatsView> {
  DateTimeRange? _pickedRange;
  String? _userIdFilter;
  final TextEditingController _userIdTextCtrl = TextEditingController();

  List<Map<String, dynamic>> _summary = [];
  List<Map<String, dynamic>> _logs = [];
  String? _selectedDateStr;
  bool _loadingSummary = false;
  bool _loadingLogs = false;

  double _yoloAvg = 0, _ocrAvg = 0, _colorAvg = 0;

  static const int _maxTopK = 20;
  int _topK = 1;

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
  double _num(dynamic v) => _toDouble(v);

  String get _topKLabel => _topK == _maxTopK ? 'All' : 'Top-$_topK';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summary.isEmpty) _loadSummary();
  }

  @override
  void dispose() {
    _userIdTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final api = widget.api;
    if (api == null) return widget.toast('Admin Key 먼저 적용', error: true);
    setState(() => _loadingSummary = true);
    try {
      final now = DateTime.now();
      _pickedRange ??= DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      final start = _fmt(_pickedRange!.start);
      final end = _fmt(_pickedRange!.end);

      final r = await api.getModelSummary(userId: _userIdFilter, start: start, end: end);
      final list = (r['summary'] as List?) ?? [];
      _summary = list.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        double y = _num(m['yolo'] ?? m['yoloScore'] ?? m['scores']?['yolo']);
        double o = _num(m['ocr']  ?? m['ocrScore']  ?? m['scores']?['ocr']);
        double c = _num(m['color']?? m['colorScore']?? m['scores']?['color']);
        if (y > 1 || o > 1 || c > 1) { y/=100.0; o/=100.0; c/=100.0; }
        return {
          'date': m['date']?.toString() ?? '',
          'count': (m['count'] as num?)?.toInt() ?? 0,
          'yolo': y.clamp(0, 1.0),
          'ocr':  o.clamp(0, 1.0),
          'color':c.clamp(0, 1.0),
        };
      }).toList();

      if (_summary.isNotEmpty) {
        _selectedDateStr ??= _summary.last['date'] as String;
        await _loadLogsForDate(_selectedDateStr!);
      }
      if (mounted) setState(() {});
    } catch (e) {
      widget.toast('요약 조회 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadLogsForDate(String dateStr) async {
    final api = widget.api;
    if (api == null) return;
    setState(() { _selectedDateStr = dateStr; _loadingLogs = true; });

    final d = DateTime.parse(dateStr);
    final endNext = DateFormat('yyyy-MM-dd').format(d.add(const Duration(days: 1)));

    const pageLimit = 100;
    const maxPages  = 10;
    final all = <Map<String, dynamic>>[];

    try {
      var page = 1;
      while (page <= maxPages) {
        final r = await api.getModelLogs(
          page: page, limit: pageLimit,
          userId: _userIdFilter, start: dateStr, end: endNext,
        );
        final chunk = (r['logs'] as List?)
                ?.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList() ?? <Map<String, dynamic>>[];
        all.addAll(chunk);
        if (chunk.length < pageLimit) break;
        page++;
      }
      _logs = all;

      // ----- 여기부터 Top-K(1/5/10/All) 반영 평균 계산 -----
      double sumY = 0, sumO = 0, sumC = 0;
      int n = 0;
      for (final log in _logs) {
        final tk = log['top_k'] ?? log['topK'] ?? log['top_k_items'];
        if (tk is! List || tk.isEmpty) continue;

        final list = tk as List;
        final kCount = (_topK == _maxTopK) 
            ? (_maxTopK < list.length ? _maxTopK : list.length)
            : (_topK < list.length ? _topK : list.length);
        final use = list.take(kCount);
        double ly = 0, lo = 0, lc = 0; int cnt = 0;
        for (final item in use) {
          final m = Map<String, dynamic>.from(item as Map);
          ly += _toDouble(m['yoloScore'] ?? m['yolo'] ?? 0);
          lo += _toDouble(m['ocrScore']  ?? m['ocr']  ?? 0);
          lc += _toDouble(m['colorScore']?? m['color']?? 0);
          cnt++;
        }
        if (cnt > 0) {
          ly/=cnt; lo/=cnt; lc/=cnt; sumY+=ly; sumO+=lo; sumC+=lc; n++;
        }
      }
      double yAvg=0,oAvg=0,cAvg=0;
      if (n>0) {
        yAvg=sumY/n; oAvg=sumO/n; cAvg=sumC/n;
        if (yAvg>1||oAvg>1||cAvg>1){ yAvg/=100; oAvg/=100; cAvg/=100; }
        final s=yAvg+oAvg+cAvg; if (s>0){ yAvg/=s; oAvg/=s; cAvg/=s; }
      }
      if (mounted) setState(() { _yoloAvg=yAvg; _ocrAvg=oAvg; _colorAvg=cAvg; });
    } catch (e) {
      widget.toast('로그 조회 실패: $e', error: true);
      if (mounted) setState(() { _yoloAvg=0; _ocrAvg=0; _colorAvg=0; });
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 좌측 필터
        SizedBox(
          width: 300,
          child: Container(
            color: AdminPalette.panel,
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text('날짜 범위', style: TextStyle(color: AdminPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _rangeTile(),
                const SizedBox(height: 16),
                const Text('user_id (선택)', style: TextStyle(color: AdminPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _userIdField(),
                const SizedBox(height: 16),
                _applyFiltersBtn(),
                const SizedBox(height: 24),
                _summaryLegend(),
              ],
            ),
          ),
        ),

        // 우측 메인
        Expanded(
          child: Container(
            color: AdminPalette.bg,
            padding: const EdgeInsets.all(16),
            child: _loadingSummary && _summary.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _mainContent(),
          ),
        ),
      ],
    );
  }

  // ------- 좌측 위젯
  Widget _rangeTile() {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final init = _pickedRange ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 1),
          initialDateRange: init,
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AdminPalette.accent,
                  surface: AdminPalette.panel2,
                  onSurface: AdminPalette.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _pickedRange = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AdminPalette.panel2, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickedRange == null ? '선택되지 않음' : '${_fmt(_pickedRange!.start)} ~ ${_fmt(_pickedRange!.end)}',
                style: const TextStyle(color: AdminPalette.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _userIdField() {
    if (_userIdFilter != null && _userIdTextCtrl.text.isEmpty) {
      _userIdTextCtrl.text = _userIdFilter!;
    }
    return TextField(
      controller: _userIdTextCtrl,
      style: const TextStyle(color: AdminPalette.textPrimary),
      decoration: InputDecoration(
        hintText: '예: ff4a-...-55d2a',
        hintStyle: const TextStyle(color: AdminPalette.textSecondary),
        isDense: true,
        filled: true,
        fillColor: AdminPalette.panel2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _applyFiltersBtn() {
    return ElevatedButton(
      onPressed: () async {
        final txt = _userIdTextCtrl.text.trim();
        setState(() => _userIdFilter = txt.isEmpty ? null : txt);
        await _loadSummary();
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: const StadiumBorder(),
        backgroundColor: AdminPalette.accent,
        foregroundColor: Colors.black,
      ),
      child: const Text('적용', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }

  Widget _summaryLegend() {
    String pct(double v) => '${(v.clamp(0, 1) * 100).toStringAsFixed(1)}%';
    final y=_yoloAvg, o=_ocrAvg, c=_colorAvg;

    Widget row(Color color, String label, double value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text(''),
            Text(label, style: const TextStyle(color: AdminPalette.textSecondary)),
            const Spacer(),
            Text(pct(value), style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('지표', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AdminPalette.panel2, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white10)),
            child: Text(_topK == _maxTopK ? 'All' : 'Top-$_topK', style: const TextStyle(color: AdminPalette.textSecondary, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        row(const Color(0xFF3DA3B9), 'YOLO',  y),
        row(const Color(0xFF395682), 'OCR',   o),
        row(const Color.fromARGB(255, 156,187,192), 'Color', c),
      ],
    );
  }

  // ------- 우측 메인
  Widget _mainContent() {
    if (_summary.isEmpty) return _empty('요약 데이터 없음');

    return Column(
      children: [
        // 날짜 카드
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _summary.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final e = _summary[i];
              final date = e['date'] as String;
              final selected = date == _selectedDateStr;
              return InkWell(
                onTap: () => _loadLogsForDate(date),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? AdminPalette.panel2 : AdminPalette.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AdminPalette.accent : Colors.transparent, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('총 ${e['count']}건', style: const TextStyle(color: AdminPalette.textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _topKSelector(),

        Expanded(
          child: Row(
            children: [
              // 도넛
              Container(
                width: 360,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AdminPalette.panel, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('모델 성능 통계', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 260, height: 260,
                          child: PieDonut(
                            yolo: _yoloAvg, ocr: _ocrAvg, colorVal: _colorAvg,
                            yoloColor: const Color(0xFF3DA3B9),
                            ocrColor: const Color(0xFF395682),
                            colorColor: const Color.fromARGB(255, 156, 187, 192),
                            labelBg: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'YOLO ${(_yoloAvg*100).toStringAsFixed(1)}%   '
                      'OCR ${(_ocrAvg*100).toStringAsFixed(1)}%   '
                      'Color ${(_colorAvg*100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: AdminPalette.textSecondary),
                    ),
                  ],
                ),
              ),

              // Top-K 리스트
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AdminPalette.panel, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top-K Items (${_selectedDateStr ?? ''}) • ${_topKLabel}',
                          style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
                      Text('로그 ${_logs.length}건', style: const TextStyle(color: AdminPalette.textSecondary)),
                      const SizedBox(height: 12),
                      Expanded(child: _loadingLogs ? const Center(child: CircularProgressIndicator()) : _topKList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(String msg) => Center(child: Text(msg, style: const TextStyle(color: AdminPalette.textSecondary)));

  Widget _topKList() {
    if (_logs.isEmpty) return _empty('로그 없음');
    final tiles = <Widget>[];

    for (var i = 0; i < _logs.length; i++) {
      final log = Map<String, dynamic>.from(_logs[i]);
      final imageId = (log['image_file_id'] ?? log['imageFileId'])?.toString();
      final ts = log['timestamp']?.toString() ?? '';
      final dt = ts.isNotEmpty ? (DateTime.tryParse(ts)?.toLocal().toString() ?? ts) : '-';
      final tk = (log['top_k'] ?? log['topK'] ?? log['top_k_items']) as List? ?? const [];

      double fSum = 0, ySum = 0, oSum = 0, cSum = 0;
      double best = 0; int cnt = 0;

      final kCount = (_topK == _maxTopK) 
          ? (_maxTopK < tk.length ? _maxTopK : tk.length)
          : (_topK < tk.length ? _topK : tk.length);
      for (final item in tk.take(kCount)) {
        final m = Map<String, dynamic>.from(item as Map);
        final fs = _toDouble(m['finalScore'] ?? m['score'] ?? m['prob']);
        final ys = _toDouble(m['yoloScore'] ?? m['yolo']);
        final os = _toDouble(m['ocrScore']  ?? m['ocr']);
        final cs = _toDouble(m['colorScore']?? m['color']);
        fSum += fs; ySum += ys; oSum += os; cSum += cs;
        if (fs > best) best = fs;
        cnt++;
      }
      final fAvg = cnt > 0 ? fSum / cnt : 0;
      final yAvg = cnt > 0 ? ySum / cnt : 0;
      final oAvg = cnt > 0 ? oSum / cnt : 0;
      final cAvg = cnt > 0 ? cSum / cnt : 0;

      tiles.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          minLeadingWidth: 44,
          leading: (widget.api==null) ? thumbPlaceholder() : ImageThumb(api: widget.api!, imageId: imageId),
          title: Text('로그 ${i+1}', style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text(dt, style: const TextStyle(color: AdminPalette.textSecondary)),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('final avg ${fAvg.toStringAsFixed(3)}  (best ${best.toStringAsFixed(3)})',
                  style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
              Text('y:${yAvg.toStringAsFixed(2)}  o:${oAvg.toStringAsFixed(2)}  c:${cAvg.toStringAsFixed(2)}',
                  style: const TextStyle(color: AdminPalette.textSecondary)),
            ],
          ),
          onTap: () => _showLogDetailModal(log),
        ),
      );
    }

    return ListView.separated(
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  // 상세 모달
  Future<void> _showLogDetailModal(Map<String, dynamic> log) async {
    final api = widget.api;
    final imageId = (log['image_file_id'] ?? log['imageFileId'])?.toString();
    final ts = log['timestamp']?.toString() ?? '';
    final dt = ts.isNotEmpty ? (DateTime.tryParse(ts)?.toLocal().toString() ?? ts) : '-';

    final List tk = (log['top_k'] ?? log['topK'] ?? log['top_k_items']) as List? ?? const [];
    final List sm = (log['summary'] as List?) ?? const [];
    final int n = (tk.length < sm.length) ? tk.length : sm.length;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminPalette.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('로그 상세', style: TextStyle(color: AdminPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (imageId != null && api != null)
                      IconButton(
                        tooltip: '원본 이미지',
                        icon: const Icon(Icons.image),
                        onPressed: () async {
                          try {
                            final res = await api.getModelImage(imageId);
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.black,
                                  content: res.statusCode==200
                                      ? Image.memory(res.bodyBytes)
                                      : const Text('이미지 로드 실패', style: TextStyle(color: Colors.white)),
                                ),
                              );
                            }
                          } catch (_) {}
                        },
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text('user_id: ${log['user_id'] ?? "-"}', style: const TextStyle(color: AdminPalette.textSecondary)),
                  Text('filename: ${log['filename'] ?? "-"}', style: const TextStyle(color: AdminPalette.textSecondary)),
                  Text('timestamp: $dt', style: const TextStyle(color: AdminPalette.textSecondary)),
                  const SizedBox(height: 12),

                  Expanded(
                    child: n == 0
                        ? const Center(child: Text('상세 데이터 없음', style: TextStyle(color: AdminPalette.textSecondary)))
                        : ListView.separated(
                            controller: controller,
                            itemCount: n,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                            itemBuilder: (_, i) {
                              final raw = Map<String, dynamic>.from(tk[i] as Map);
                              final meta = sm[i] is Map ? Map<String, dynamic>.from(sm[i] as Map) : <String, dynamic>{};

                              final fs = _toDouble(raw['finalScore'] ?? raw['score'] ?? raw['prob']);
                              final ys = _toDouble(raw['yoloScore']  ?? raw['yolo']  ?? 0);
                              final os = _toDouble(raw['ocrScore']   ?? raw['ocr']   ?? 0);
                              final cs = _toDouble(raw['colorScore'] ?? raw['color'] ?? 0);
                              final seq = (raw['itemSeq'] ?? raw['item_seq'] ?? '').toString();

                              final name = (meta['itemName'] ?? '-').toString();
                              final entp = (meta['entpName'] ?? '').toString();
                              final img  = meta['imageUrl']?.toString();

                              return ListTile(
                                dense: true,
                                leading: (img != null && img.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(img, width: 44, height: 44, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => thumbPlaceholder(),
                                        ),
                                      )
                                    : thumbPlaceholder(),
                                title: Text(name, style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w600)),
                                subtitle: Text(entp.isEmpty ? 'itemSeq: $seq' : '$entp · itemSeq: $seq',
                                  style: const TextStyle(color: AdminPalette.textSecondary)),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('final ${fs.toStringAsFixed(3)}',
                                        style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
                                    Text('y:${ys.toStringAsFixed(2)}  o:${os.toStringAsFixed(2)}  c:${cs.toStringAsFixed(2)}',
                                        style: const TextStyle(color: AdminPalette.textSecondary)),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                minLeadingWidth: 44,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _topKSelector() {
    final chips = <int>[1, 5, 10, _maxTopK];
    String label(int v) => v == _maxTopK ? 'All' : 'Top-$v';

    return Row(
      children: chips.map((k) {
        final selected = _topK == k;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label(k)),
            selected: selected,
            onSelected: (v) async {
              if (!v) return;
              setState(() => _topK = k);
              if (_selectedDateStr != null) await _loadLogsForDate(_selectedDateStr!);
            },
          ),
        );
      }).toList(),
    );
  }
}
