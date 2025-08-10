import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

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
  int _currentAnchor = 0; // 현재 앵커 위치
  bool _autoJumpPending = false; // 첫 입력 시 자동 점프 플래그
  int _lastMatchCount = 0; // 직전 프레임의 매치 개수(카운터/버튼 상태용)

  // 검색 상태
  String _query = '';
  int _currentSectionHit = 0; // 섹션 단위 점프용
  late final Map<String, GlobalKey> _sectionKeys;

  // 섹션 텍스트(검색용) + 섹션 라벨
  late final Map<String, String> _sectionTexts; // 검색에 쓰는 순수 텍스트(섹션 요약)
  // 실제 렌더에 쓰는 원본 데이터는 기존 메서드들이 그대로 처리

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

    // 검색용 텍스트(섹션별 존재 여부 판단)
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
        _currentAnchor = 0; // ✅ 매치 인덱스 리셋
        _matchAnchors.clear(); // ✅ 매치 앵커 초기화
        _autoJumpPending = true; // 다음 프레임에 첫 매치로 자동 점프
      });
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 섹션 중 검색어 포함된 섹션 목록
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

  /// List/Map/String 어떤 타입이 와도 검색용 "문장"으로 뽑아냄
  String _takeText(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) return v.values.map(_takeText).join('\n');
    if (v is List) return v.map(_takeText).join('\n');
    return v.toString();
  }

  /// null, 빈 문자열, 빈 리스트 처리
  String _safeValue(dynamic value) {
    if (value == null) return '정보 없음';

    if (value is List) {
      if (value.isEmpty) return '정보 없음';
      return value.map((e) => e.toString()).join('\n');
    }

    if (value is String && value.trim().isEmpty) return '정보 없음';

    return value.toString();
  }

  /// HTML 데이터 전처리 (escape 제거 + table 감싸기)
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

    // <table> 구조 보정
    if (!cleaned.contains("<table") && (cleaned.contains("<tbody") || cleaned.contains("<tr"))) {
      cleaned = "<table><thead></thead>$cleaned</table>";
    } else if (cleaned.contains("<table") && !cleaned.contains("<thead")) {
      cleaned = cleaned.replaceFirst("<table>", "<table><thead></thead>");
    }
    return cleaned;
  }

  /// 하이라이트 + 매치 앵커 부착 버전
  Widget _highlightedTextAnchored(String text) {
    if (_query.isEmpty || text.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 14, height: 1.5));
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
      _matchAnchors.add(key); // ✅ 매치마다 앵커 저장
      final matchStr = text.substring(idx, idx + _query.length);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            key: key, // ✅ 앵커 부착
            color: Colors.yellow.withOpacity(0.55),
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
            child: Text(
              matchStr,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      );

      start = idx + _query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
        children: spans,
      ),
    );
  }

  /// 테이블(커스텀) 위젯: 각 셀도 하이라이트 적용
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

    return Table(
      border: TableBorder.all(color: Colors.black),
      columnWidths: const {},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: safeHeaders
              .map((header) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _highlightedTextAnchored(header),
                  ))
              .toList(),
        ),
        ...normalizedRows.map(
          (row) => TableRow(
            children: row
                .map(
                  (cell) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _highlightedTextAnchored(cell),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// HTML/리스트/문자열 모두 처리 (하이라이트 적용)
  Widget _buildContent(dynamic data) {
    if (data == null) return const Text("정보 없음");

    // 리스트 처리
    if (data is List) {
      if (data.isEmpty) return const Text("정보 없음");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.map((item) {
          if (item is String) {
            return _highlightedTextAnchored(item);
          } else if (item is Map && item.containsKey("table")) {
            final table = item["table"];
            final headers = (table["headers"] as List? ?? []).map((e) => e.toString()).toList();

            final rows = (table["rows"] as List? ?? [])
                .map<List<String>>((row) => (row as List).map((cell) => cell.toString()).toList())
                .toList();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildTableWidget(headers, rows),
            );
          } else if (item is Map && item.containsKey("html")) {
            // HTML 조각이 리스트에 섞여있는 경우
            final html = _prepareHtml(item['html']?.toString());
            // flutter_html 과 하이라이트 병행은 복잡해질 수 있어
            // 우선 HTML은 원본 그대로 렌더링(검색은 섹션 점프/텍스트 매치로 보완)
            return Html(data: html);
          }
          return _highlightedTextAnchored(item.toString());
        }).toList(),
      );
    }

    // 문자열 처리
    if (data is String) {
      return _highlightedTextAnchored(_safeValue(data));
    }

    // 맵/기타
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

  /// 섹션 타이틀
  Widget _buildSectionTitle(String title, {Key? key}) {
    final hit = _query.isNotEmpty && (_sectionTexts[title]?.toLowerCase().contains(_query.toLowerCase()) ?? false);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (hit) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('매치', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  /// 섹션 내용
  Widget _buildSectionContent(String label, dynamic content, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _buildContent(content),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 새 프레임마다 앵커 재수집: 중복 누적 방지
    _matchAnchors.clear();

    // final matchText = _query.isEmpty
    //     ? '이 페이지에서 검색…'
    //     : (_hitSections.isEmpty ? '일치 섹션 없음' : '${_currentSectionHit + 1}/${_hitSections.length}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newCount = _matchAnchors.length;
      if (newCount != _lastMatchCount) {
        setState(() {
          _lastMatchCount = newCount;
          // 현재 인덱스가 범위를 넘지 않도록 보정
          if (_lastMatchCount == 0) {
            _currentAnchor = 0;
          } else if (_currentAnchor >= _lastMatchCount) {
            _currentAnchor = _lastMatchCount - 1;
          }
        });
      }
      // 첫 입력 후 자동으로 첫 매치로 점프
      if (_autoJumpPending && _lastMatchCount > 0) {
        _autoJumpPending = false;
        _currentAnchor = 0;
        _scrollToMatch(0);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("효능효과/용법용량/사용상의주의사항"),
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
      ),
      body: Column(
        children: [
          // 🔎 인페이지 검색 바 + 섹션 내비게이션
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    onSubmitted: (_) => _goNextMatch(),
                    decoration: InputDecoration(
                      hintText: '검색어 입력…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ✅ 고정 너비 카운터로 검색창 레이아웃 흔들림 방지
                SizedBox(
                  width: 60,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _query.isEmpty ? '' : (_lastMatchCount == 0 ? '0/0' : '${_currentAnchor + 1}/$_lastMatchCount'),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '이전',
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: _lastMatchCount == 0 ? null : _goPrevMatch,
                ),
                IconButton(
                  tooltip: '다음',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: _lastMatchCount == 0 ? null : _goNextMatch,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 효능 효과
                  _buildSectionTitle("효능 효과", key: _sectionKeys['효능 효과']),
                  const Divider(),
                  _buildContent(widget.permitDetail['efficacy']),
                  const SizedBox(height: 16),

                  // 용법 용량
                  _buildSectionTitle("용법 용량", key: _sectionKeys['용법 용량']),
                  const Divider(),
                  _buildContent(widget.permitDetail['dosage']),
                  const SizedBox(height: 16),

                  // 사용상의 주의사항(그룹)
                  _buildSectionTitle("사용상의 주의사항", key: _sectionKeys['사용상의 주의사항']),
                  const Divider(),

                  // 금기/경고/주의사항
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
    );
  }
}