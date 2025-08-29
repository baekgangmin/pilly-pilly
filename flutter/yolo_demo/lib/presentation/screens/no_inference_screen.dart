// lib/presentation/screens/no_inference_screen.dart
import 'package:flutter/material.dart';
import 'package:yolo_demo/api_services/feature_search_service.dart';
import 'package:yolo_demo/utils/image_utils.dart';
import 'loading_screen.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/screens/feature_search_result.dart';

class NoInferenceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> summary; // topK: [{itemSeq, imageUrl, ...}, ...]
  final String? initialFrontText; // ✅ OCR로 전달된 초기 앞면 글씨(없으면 null)

  const NoInferenceScreen({
    Key? key,
    required this.summary,
    this.initialFrontText,
  }) : super(key: key);

  @override
  State<NoInferenceScreen> createState() => _NoInferenceScreenState();
}

class _NoInferenceScreenState extends State<NoInferenceScreen> {
  final _frontCtrl = TextEditingController();
  final _backCtrl  = TextEditingController();

  final _svc = FeatureSearchService();

  int? selectedIdx;
  String? selectedItemSeq;

  // 감지/확정된 값
  String? shape;        // 예: "원형"
  String? colorClass1;  // 예: "초록"
  bool fetchingMeta = false;

  // 편집용 옵션 (필요 시 확장)
  final List<String> shapeOptions = [
    '원형','타원형','장방형','삼각형','사각형','마름모형','오각형','육각형','팔각형','기타'
  ];
  final List<String> colorOptions = [
    '하양','투명','회색','빨강','분홍','자주','노랑','주황','연두','초록','청록','파랑','남색','보라','갈색','검정'
  ];

  @override
  void initState() {
    super.initState();
    // ✅ OCR 프리필: 전달된 값이 있으면 앞글씨 입력칸에 채워넣기
    final seed = (widget.initialFrontText ?? '').trim();
    if (seed.isNotEmpty) {
      _frontCtrl.text = seed;
    }
  }

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSelect(int index) async {
    setState(() {
      selectedIdx = index;
      fetchingMeta = true;
      shape = null;
      colorClass1 = null;
    });

    final raw = widget.summary[index];
    final Map<String, dynamic> map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final dynamic rawSeq = map['itemSeq'] ?? map['ITEM_SEQ'];
    final String itemSeq = (rawSeq is String || rawSeq is num) ? rawSeq.toString() : '';
    selectedItemSeq = itemSeq.isNotEmpty ? itemSeq : null;

    if (selectedItemSeq == null) {
      fetchingMeta = false;
      setState(() {});
      return;
    }

    // 선택 즉시 meta 조회해서 배지 채우기
    try {
      final meta = await _svc.fetchShapeAndColorByItemSeq(selectedItemSeq!);
      // meta 구조 방어적 파싱 (null-safe)
      Map<String, dynamic> firstObj;
      if (meta != null &&
          meta is Map &&
          (meta['results'] is List) &&
          ((meta['results'] as List?)?.isNotEmpty ?? false)) {
        firstObj = Map<String, dynamic>.from((meta['results'] as List).first);
      } else if (meta is Map<String, dynamic>) {
        firstObj = meta;
      } else {
        firstObj = {};
      }

      shape = (firstObj['drug_shape'] ?? firstObj['DRUG_SHAPE'] ?? '').toString().trim();
      colorClass1 = (firstObj['color_class1'] ?? firstObj['COLOR_CLASS1'] ?? '').toString().trim();
    } catch (_) {
      // 무시하고 사용자가 직접 편집할 수 있도록 둠
    } finally {
      fetchingMeta = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _editShape() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChoiceSheet(title: '모양 선택', options: shapeOptions, initial: shape),
    );
    if (chosen != null) setState(() => shape = chosen);
  }

  Future<void> _editColor() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChoiceSheet(title: '색상 선택', options: colorOptions, initial: colorClass1),
    );
    if (chosen != null) setState(() => colorClass1 = chosen);
  }

    void _goNext() {
      final front = _frontCtrl.text.trim();
      final back = _backCtrl.text.trim();

      // 사용자가 썸네일을 고르지 않은 경우 + 텍스트/모양/색상 중 하나라도 있으면
      final bool hasFilters = front.isNotEmpty ||
          back.isNotEmpty ||
          ((shape ?? '').trim().isNotEmpty) ||
          ((colorClass1 ?? '').trim().isNotEmpty);

      if ((selectedItemSeq == null || selectedItemSeq!.isEmpty) && hasFilters) {
        // ✅ 특징기반 결과로 바로 이동 (LoadingScreen 경유 X)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeatureSearchResultScreen(
              shape: (shape != null && shape!.trim().isNotEmpty) ? [shape!.trim()] : null,
              selectedColors: (colorClass1 != null && colorClass1!.trim().isNotEmpty) ? [colorClass1!.trim()] : const [],
              frontText: front.isEmpty ? null : front,
              backText: back.isEmpty ? null : back,
            ),
          ),
        );
        return;
      }

    // 그 외(썸네일 선택하여 itemSeq가 있는 경우)는 기존처럼 서버 재조회 경로
    final String itemSeqVal = selectedItemSeq?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(
          itemSeq: itemSeqVal,
          printFront: front.isEmpty ? null : front,
          printBack: back.isEmpty ? null : back,
          overrideShape: shape,
          overrideColor: colorClass1,
        ),
      ),
    );
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기
  Future<String?> _getImageWithCrawling(Map<String, dynamic> item) async {
    final originalImage = item['imageUrl'];
    
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }

    // placeholder인 경우 크롤링 시도
    final itemSeq = item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString();
    if (itemSeq != null && itemSeq.isNotEmpty) {
      try {
        final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq});
        if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
          print("🖼️ [NoInference] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          return crawledImageUrl;
        }
      } catch (e) {
        print("❌ [NoInference] 이미지 크롤링 실패: $itemSeq - $e");
      }
    }

    // 크롤링 실패시 기본 이미지 반환
    return 'assets/no_image.png';
  }

  @override
  Widget build(BuildContext context) {
    final validSummary = widget.summary.where((e) {
      final Map<String, dynamic> map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final dynamic imgRaw = map['imageUrl'] ?? map['ITEM_IMAGE'];
      final dynamic seqRaw = map['itemSeq'] ?? map['ITEM_SEQ'];
      final String img = (imgRaw is String) ? imgRaw : '';
      final String seq = (seqRaw is String || seqRaw is num) ? seqRaw.toString() : '';
      return img.isNotEmpty || seq.isNotEmpty;
    }).toList();

    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1200 ? 8 : width >= 900 ? 6 : width >= 600 ? 4 : 2;

    final bool canSearch = (selectedItemSeq != null) ||
        _frontCtrl.text.trim().isNotEmpty ||
        _backCtrl.text.trim().isNotEmpty ||
        ((shape ?? '').trim().isNotEmpty) ||
        ((colorClass1 ?? '').trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('유사한 알약을 선택해주세요'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 그리드
            Expanded(
              child: GridView.builder(
                itemCount: validSummary.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, index) {
                  final raw = validSummary[index];
                  final Map<String, dynamic> map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                  final dynamic imgRaw = map['imageUrl'] ?? map['ITEM_IMAGE'];
                  final String imageUrl = (imgRaw is String) ? imgRaw : '';
                  final isSelected = selectedIdx == index;

                  return GestureDetector(
                    onTap: () => _onSelect(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: FutureBuilder<String?>(
                          future: _getImageWithCrawling({'imageUrl': imageUrl, 'itemSeq': map['itemSeq'] ?? map['ITEM_SEQ']}),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            
                            final finalImageUrl = snapshot.data;
                            if (finalImageUrl != null && !ImageUtils.isPlaceholder(finalImageUrl)) {
                              return Image.network(
                                finalImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                              );
                            } else {
                              return const Center(child: Icon(Icons.image_not_supported));
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 색상/모양 배지 (편집)
            Row(
              children: [
                Expanded(
                  child: _MetaBadge(
                    label: '색상',
                    value: colorClass1,
                    loading: fetchingMeta && selectedIdx != null,
                    onEdit: _editColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetaBadge(
                    label: '모양',
                    value: shape,
                    loading: fetchingMeta && selectedIdx != null,
                    onEdit: _editShape,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 앞/뒤 글씨 입력 (선택)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _frontCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '앞글씨 입력 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _backCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '뒷글씨 입력 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSearch ? _goNext : null,
                child: const Text('검색하기'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final String? value;
  final bool loading;
  final VoidCallback onEdit;

  const _MetaBadge({
    Key? key,
    required this.label,
    required this.value,
    required this.loading,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final v = (value ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: loading
                ? const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : Text(v.isEmpty ? '—' : v, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            tooltip: '$label 편집',
          ),
        ],
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? initial;

  const _ChoiceSheet({
    Key? key,
    required this.title,
    required this.options,
    required this.initial,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? current = initial;
    return StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 48, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((op) {
                final selected = current == op;
                return ChoiceChip(
                  label: Text(op),
                  selected: selected,
                  onSelected: (_) => setState(() => current = op),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, current),
                child: const Text('선택'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}