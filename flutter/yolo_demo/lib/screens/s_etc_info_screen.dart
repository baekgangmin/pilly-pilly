import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:yolo_demo/notifiers/home_button.dart';

class SEtcInfoScreen extends StatefulWidget {
  final Map<String, dynamic> permitDetail;

  const SEtcInfoScreen({
    Key? key,
    required this.permitDetail,
  }) : super(key: key);

  @override
  State<SEtcInfoScreen> createState() => _SEtcInfoScreenState();
}

class _SEtcInfoScreenState extends State<SEtcInfoScreen> {
  final _searchCtl = TextEditingController();
  final _scrollController = ScrollController();
  final List<GlobalKey> _matchAnchors = [];
  int _currentAnchor = 0;
  bool _autoJumpPending = false;
  int _lastMatchCount = 0;

  String _query = '';
  int _currentSectionHit = 0;
  late final Map<String, GlobalKey> _sectionKeys;
  late final Map<String, String> _sectionTexts;

  @override
  void initState() {
    super.initState();
    _sectionKeys = {
      '효능 효과': GlobalKey(),
      '용법 용량': GlobalKey(),
      '사용상의 주의사항': GlobalKey(),
      '금기 사항': GlobalKey(),
      '경고': GlobalKey(),
      '주의사항': GlobalKey(),
    };

    _sectionTexts = {
      '효능 효과': _takeText(widget.permitDetail['efficacy']),
      '용법 용량': _takeText(widget.permitDetail['dosage']),
      '사용상의 주의사항': _takeText(widget.permitDetail['precautions']),
      '금기 사항': _takeText(widget.permitDetail['precautions']?['contraindications']),
      '경고': _takeText(widget.permitDetail['precautions']?['warnings']),
      '주의사항': _takeText(widget.permitDetail['precautions']?['cautions']),
    };

    _searchCtl.addListener(() {
      setState(() {
        _query = _searchCtl.text.trim();
        _currentSectionHit = 0;
        _currentAnchor = 0;
        _matchAnchors.clear();
        _autoJumpPending = true;
      });
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _hitSections {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return _sectionTexts.entries
        .where((e) => e.value.toLowerCase().contains(q))
        .map((e) => e.key)
        .toList();
  }

  void _goPrevSection() {
    if (_hitSections.isEmpty) return;
    setState(() {
      _currentSectionHit =
          (_currentSectionHit - 1) < 0 ? _hitSections.length - 1 : _currentSectionHit - 1;
    });
    _scrollToSection(_hitSections[_currentSectionHit]);
  }

  void _goNextSection() {
    if (_hitSections.isEmpty) return;
    setState(() {
      _currentSectionHit = (_currentSectionHit + 1) % _hitSections.length;
    });
    _scrollToSection(_hitSections[_currentSectionHit]);
  }

  void _scrollToSection(String label) {
    final key = _sectionKeys[label];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.05,
      curve: Curves.easeInOut,
    );
  }

  String _takeText(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return v.values.map(_takeText).join('\n');
    if (v is List) return v.map(_takeText).join('\n');
    return v.toString();
  }

  String _safeValue(dynamic value) {
    if (value == null) return '정보 없음';

    if (value is List) {
      if (value.isEmpty) return '정보 없음';
      return value.map((e) => e.toString()).join('\n');
    }

    if (value is String && value.trim().isEmpty) return '정보 없음';

    return value.toString();
  }

  String _prepareHtml(String? data) {
    if (data == null) return "정보 없음";

    String cleaned = data
        .replaceAll('\\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\\"', '"')
        .replaceAll('\\', '')
        .replaceAll('<tbody><tbody>', '<tbody>')
        .replaceAll('</tbody></tbody>', '</tbody>')
        .trim();

    if (!cleaned.contains("<table") && (cleaned.contains("<tbody") || cleaned.contains("<tr"))) {
      cleaned = "<table><thead></thead>$cleaned</table>";
    } else if (cleaned.contains("<table") && !cleaned.contains("<thead")) {
      cleaned = cleaned.replaceFirst("<table>", "<table><thead></thead>");
    }
    return cleaned;
  }

  Widget _highlightedTextAnchored(String text) {
    if (_query.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
      );
    }
    final lower = text.toLowerCase();
    final q = _query.toLowerCase();

    final spans = <InlineSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }

      final key = GlobalKey();
      _matchAnchors.add(key);
      final matchStr = text.substring(idx, idx + _query.length);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            key: key,
            color: Colors.yellow.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              matchStr,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ),
      );

      start = idx + _query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
        children: spans,
      ),
    );
  }

  Widget _buildTableWidget(List<String> headers, List<List<String>> rows) {
    final columnCount = headers.isEmpty ? 1 : headers.length;
    final safeHeaders = headers.isEmpty ? [''] : headers;
    final normalizedRows = rows.map((row) {
      final cells = List<String>.from(row);
      while (cells.length < columnCount) {
        cells.add('');
      }
      if (cells.length > columnCount) {
        cells.removeRange(columnCount, cells.length);
      }
      return cells;
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {},
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              children: safeHeaders
                  .map((header) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          header,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            ...normalizedRows.map(
              (row) => TableRow(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                children: row
                    .map(
                      (cell) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          cell,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(dynamic data) {
    if (data == null) return const Text("정보 없음");

    if (data is List) {
      if (data.isEmpty) return const Text("정보 없음");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.map((item) {
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _highlightedTextAnchored(item),
            );
          } else if (item is Map && item.containsKey("table")) {
            final table = item["table"];
            final headers = (table["headers"] as List? ?? []).map((e) => e.toString()).toList();

            final rows = (table["rows"] as List? ?? [])
                .map<List<String>>((row) => (row as List).map((cell) => cell.toString()).toList())
                .toList();

            return _buildTableWidget(headers, rows);
          } else if (item is Map && item.containsKey("html")) {
            final html = _prepareHtml(item['html']?.toString());
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Html(data: html),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _highlightedTextAnchored(item.toString()),
          );
        }).toList(),
      );
    }

    if (data is String) {
      return _highlightedTextAnchored(_safeValue(data));
    }

    return _highlightedTextAnchored(_safeValue(data));
  }

  void _scrollToMatch(int idx) {
    if (_matchAnchors.isEmpty) return;
    if (idx < 0 || idx >= _matchAnchors.length) return;

    final ctx = _matchAnchors[idx].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.1,
      curve: Curves.easeInOut,
    );
  }

  void _goPrevMatch() {
    if (_lastMatchCount == 0) return;
    setState(() {
      _currentAnchor = (_currentAnchor - 1) < 0 ? _lastMatchCount - 1 : _currentAnchor - 1;
    });
    _scrollToMatch(_currentAnchor);
  }

  void _goNextMatch() {
    if (_lastMatchCount == 0) return;
    setState(() {
      _currentAnchor = (_currentAnchor + 1) % _lastMatchCount;
    });
    _scrollToMatch(_currentAnchor);
  }

  Widget _buildSectionTitle(String title, {Key? key}) {
    final hit = _query.isNotEmpty && (_sectionTexts[title]?.toLowerCase().contains(_query.toLowerCase()) ?? false);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hit
              ? [
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ]
              : [
                  Colors.white,
                  Colors.grey.shade50,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hit
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getSectionIcon(title),
            color: hit
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: hit
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black87,
              ),
            ),
          ),
          if (hit) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '매치',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    switch (title) {
      case '효능 효과':
        return Icons.healing_rounded;
      case '용법 용량':
        return Icons.medication_rounded;
      case '사용상의 주의사항':
        return Icons.warning_amber_rounded;
      case '금기 사항':
        return Icons.block_rounded;
      case '경고':
        return Icons.error_outline;
      case '주의사항':
        return Icons.info_outline;
      default:
        return Icons.article_rounded;
    }
  }

  Widget _buildSectionContent(String label, dynamic content, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getContentIcon(label),
                color: _getContentColor(label),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getContentColor(label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContent(content),
        ],
      ),
    );
  }

  IconData _getContentIcon(String label) {
    switch (label) {
      case "금기 사항":
        return Icons.block_rounded;
      case "경고":
        return Icons.error_outline;
      case "주의사항":
        return Icons.info_outline;
      default:
        return Icons.article_rounded;
    }
  }

  Color _getContentColor(String label) {
    switch (label) {
      case "금기 사항":
        return Colors.red.shade600;
      case "경고":
        return Colors.orange.shade600;
      case "주의사항":
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    _matchAnchors.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newCount = _matchAnchors.length;
      if (newCount != _lastMatchCount) {
        setState(() {
          _lastMatchCount = newCount;
          if (_lastMatchCount == 0) {
            _currentAnchor = 0;
          } else if (_currentAnchor >= _lastMatchCount) {
            _currentAnchor = _lastMatchCount - 1;
          }
        });
      }
      if (_autoJumpPending && _lastMatchCount > 0) {
        _autoJumpPending = false;
        _currentAnchor = 0;
        _scrollToMatch(0);
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("효능효과/용법용량/사용상의주의사항"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '내용 검색',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtl,
                        onSubmitted: (_) => _goNextMatch(),
                        decoration: InputDecoration(
                          hintText: '검색어를 입력하세요...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _query.isEmpty
                            ? Colors.grey.shade200
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _query.isEmpty
                              ? Colors.grey.shade300
                              : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _query.isEmpty ? '0/0' : '${_currentAnchor + 1}/$_lastMatchCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _query.isEmpty
                              ? Colors.grey.shade600
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '이전',
                      icon: Icon(
                        Icons.keyboard_arrow_up,
                        color: _lastMatchCount == 0
                            ? Colors.grey.shade400
                            : Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _lastMatchCount == 0 ? null : _goPrevMatch,
                    ),
                    IconButton(
                      tooltip: '다음',
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: _lastMatchCount == 0
                            ? Colors.grey.shade400
                            : Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _lastMatchCount == 0 ? null : _goNextMatch,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("효능 효과", key: _sectionKeys['효능 효과']),
                  _buildContent(widget.permitDetail['efficacy']),
                  const SizedBox(height: 24),

                  _buildSectionTitle("용법 용량", key: _sectionKeys['용법 용량']),
                  _buildContent(widget.permitDetail['dosage']),
                  const SizedBox(height: 24),

                  _buildSectionTitle("사용상의 주의사항", key: _sectionKeys['사용상의 주의사항']),
                  
                  _buildSectionContent(
                    "금기 사항",
                    widget.permitDetail['precautions']?['contraindications'],
                    key: _sectionKeys['금기 사항'],
                  ),
                  _buildSectionContent(
                    "경고",
                    widget.permitDetail['precautions']?['warnings'],
                    key: _sectionKeys['경고'],
                  ),
                  _buildSectionContent(
                    "주의사항",
                    widget.permitDetail['precautions']?['cautions'],
                    key: _sectionKeys['주의사항'],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}