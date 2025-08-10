import 'package:yolo_demo/db_helper.dart';

import 'final_result.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_services/feature_search_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';

class FeatureSearchResultScreen extends StatefulWidget {
  final List<String>? shape;
  final List<String> selectedColors;
  final String? frontText;
  final String? backText;
  final List<Map<String, dynamic>> cartItems;
  final void Function(Map<String, dynamic>) onAddToCart;
  final void Function(Map<String, dynamic>) onRemoveFromCart;

  const FeatureSearchResultScreen({
    super.key,
    this.shape,
    required this.selectedColors,
    this.frontText,
    this.backText,
    required this.cartItems,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  State<FeatureSearchResultScreen> createState() => _FeatureSearchResultScreenState();
}

class _FeatureSearchResultScreenState extends State<FeatureSearchResultScreen> {
  final Map<String, List<String>> colorPatterns = {
    '하양': ['하양'],
    '투명': ['투명'],
    '회색': ['회색'],
    '빨강': ['빨강'],
    '분홍': ['분홍'],
    '자주': ['자주'],
    '노랑': ['노랑'],
    '주황': ['주황'],
    '연두': ['연두'],
    '초록': ['초록'],
    '청록': ['청록'],
    '파랑': ['파랑'],
    '남색': ['남색'],
    '보라': ['보라'],
    '갈색': ['갈색'],
    '검정': ['검정'],
  };
  final _api = FeatureSearchService();
  bool isLoading = true;
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchPills();
  }

  Future<void> _searchPills() async {
    debugPrint('=== 검색 시작 ===');
    setState(() {
      isLoading = true;
    });

    final data = await _api.fetchPillInfo(
      printFront: widget.frontText,
      printBack: widget.backText,
      shape: widget.shape?.isNotEmpty == true ? widget.shape!.first : null,
      colorClass1: widget.selectedColors.isNotEmpty ? widget.selectedColors.first : null,
    );

    if (mounted) {
      setState(() {
        isLoading = false;
        final items = data?['results'];
        if (items != null && items is List) {
          final allItems = List<Map<String, dynamic>>.from(items);

          searchResults = allItems.where((item) {
            bool shapeMatch = true;
            bool colorMatch = true;

            if (widget.shape != null && widget.shape!.isNotEmpty) {
              shapeMatch = widget.shape!.contains(item['DRUG_SHAPE']);
            }

            if (widget.selectedColors.isNotEmpty) {
              colorMatch = widget.selectedColors.any((selectedColorKey) {
                final patterns = colorPatterns[selectedColorKey];
                if (patterns == null) return false;

                final value = (item['COLOR_CLASS1'] ?? '').toString();
                return patterns.any((p) => value.contains(p));
              });
            }

            return shapeMatch && colorMatch;
          }).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('검색 결과'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '총 ${searchResults.length}개의 결과가 검색되었습니다',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Expanded(
                  child: searchResults.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            final isInCart = widget.cartItems.any((e) => e['ITEM_SEQ'] == item['ITEM_SEQ']);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () {
                                        widget.onRemoveFromCart(item);
                                        setState(() {});
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Image.network(
                                            item['ITEM_IMAGE'] ?? 'https://via.placeholder.com/120',
                                            height: 100,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.image_not_supported, size: 60),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item['ITEM_NAME'] ?? '이름 없음',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                                      onPressed: () {
                                        widget.onAddToCart(item);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (widget.cartItems.isNotEmpty)
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.cartItems.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cartItem = widget.cartItems[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      cartItem['ITEM_IMAGE'] ?? 'https://via.placeholder.com/60',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () {
                                        widget.onRemoveFromCart(cartItem);
                                        setState(() {});
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: 60,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () async {
                              print("🟢 화살표 버튼 눌림");

                              // Server POST request (for final_result.dart)
                              final itemSeqList = widget.cartItems.map((e) => e['ITEM_SEQ'].toString()).toList();
                              print("🟡 장바구니 itemSeqList: $itemSeqList");

                              if (itemSeqList.isEmpty) {
                                print("⚠️ 장바구니가 비어 있음");
                                return;
                              }

                              try {
                                print("🌐 서버 요청 시작");
                                final uri = Uri.parse('$baseUrl/api/v2/log');

                                final headers = await ApiHelper.getAuthHeaders();
                                final response = await http.post(
                                  uri,
                                  headers: headers,
                                  body: json.encode(itemSeqList),
                                );

                                print("🌐 응답 코드: ${response.statusCode}");
                                print("🌐 응답 본문: ${response.body}");

                                if (response.statusCode == 200) {
                                  final resultData = json.decode(response.body);

                                  print("✅ 응답 디코딩 성공");

                                  // 서버 응답 리스트
                                  final resultMap = resultData['results'] as Map<String, dynamic>;

                                  // SQLite 저장 (최근검색기록))
                                  for (final itemSeq in resultMap.keys) {
                                    final item = resultMap[itemSeq];
                                    final itemName = item['permit']?['permitDetail']?['itemName'];
                                    final timestamp = DateTime.now().toIso8601String();

                                    if (itemName != null) {
                                      await DBHelper.addRecentPill(
                                        itemSeq: itemSeq, 
                                        itemName: itemName, 
                                        userId: 'guest',
                                        timestamp: timestamp,
                                        );
                                        print("✅ 최근 검색 저장됨: $itemName ($itemSeq)");
                                    }
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FinalResultScreen(resultData: resultData),
                                    ),
                                  );
                                } else {
                                  debugPrint('서버 오류: ${response.statusCode}');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('서버 오류: ${response.statusCode}')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('에러 발생: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('오류 발생: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
