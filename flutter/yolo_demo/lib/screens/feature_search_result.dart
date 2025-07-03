import 'package:flutter/material.dart';
import '../services/drug_api_service.dart';

class FeatureSearchResultScreen extends StatefulWidget {
  final String? shape;
  final List<String> selectedColors;
  final String? frontText;
  final String? backText;

  const FeatureSearchResultScreen({
    Key? key,
    this.shape,
    required this.selectedColors,
    this.frontText,
    this.backText,
  }) : super(key: key);

  @override
  State<FeatureSearchResultScreen> createState() => _FeatureSearchResultScreenState();
}

class _FeatureSearchResultScreenState extends State<FeatureSearchResultScreen> {
  final _api = DrugApiService();
  bool isLoading = true;
  List<Map<String, dynamic>> searchResults = [];

  // 색상 패턴 (다양한 표현 대응)
  final Map<String, List<String>> colorPatterns = {
    'white': ['하양', '화이트', 'WHITE'],
    'bin': ['투명'],
    'gray': ['회색', '그레이'],
    'red': ['빨강', '적색', '레드', 'RED'],
    'pink': ['분홍', '핑크'],
    'purple': ['자주', '퍼플'],
    'yellow': ['노랑', '황색', '옐로우'],
    'orange': ['주황', '오렌지'],
    'lightGreen': ['연두', '라이트그린'],
    'green': ['초록', '그린'],
    'teal': ['청록', '틸'],
    'blue': ['파랑', '블루'],
    'indigo': ['남색', '인디고'],
    'deepPurple': ['보라', '딥퍼플'],
    'brown': ['갈색', '브라운'],
    'black': ['검정', '블랙'],
  };

  @override
  void initState() {
    super.initState();
    _searchPills();
  }

  Future<void> _searchPills() async {
    debugPrint('=== 약 검색 시작 ===');
    setState(() {
      isLoading = true;
    });

    final data = await _api.fetchPillInfo();

    if (mounted) {
      setState(() {
        isLoading = false;
        if (data != null) {
          final items = data['body']?['items'];
          debugPrint('=== 응답 아이템 개수: ${items?.length ?? 0} ===');

          if (items != null && items is List) {
            searchResults = List<Map<String, dynamic>>.from(items).where((item) {
              bool shapeMatch = true;
              bool colorMatch = true;

              // shape 조건
              if (widget.shape != null && widget.shape!.isNotEmpty) {
                shapeMatch = item['DRUG_SHAPE'] == widget.shape;
              }

              // color 조건 (여러 표현 대응)
              if (widget.selectedColors.isNotEmpty) {
                colorMatch = widget.selectedColors.any((selectedColorKey) {
                  final patterns = colorPatterns[selectedColorKey];
                  if (patterns == null) return false;

                  final value = item['COLOR_CLASS1']?.toString() ?? '';
                  debugPrint('비교 - 선택: $selectedColorKey / 패턴: $patterns / 값: $value');
                  return patterns.any((p) => value.contains(p));
                });
              }

              return shapeMatch && colorMatch;
            }).toList();

            debugPrint('=== 필터링 후 개수: ${searchResults.length} ===');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('검색 결과'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : searchResults.isEmpty
              ? const Center(child: Text('검색 결과가 없습니다.'))
              : ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final item = searchResults[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Image.network(
                                item['ITEM_IMAGE'] ?? 'https://via.placeholder.com/120',
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported, size: 60),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                item['ITEM_NAME'] ?? '이름 없음',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
