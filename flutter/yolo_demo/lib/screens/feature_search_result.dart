import 'final_result.dart';
import 'package:flutter/material.dart';
import '../services/drug_api_service.dart';

class FeatureSearchResultScreen extends StatefulWidget {
  final List<String>? shape;
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
  // 색상 키와 해당하는 한글/영문 표현 매핑
  final Map<String, List<String>> colorPatterns = {
    'white': ['하양', '화이트'],
    'bin': ['투명'],
    'gray': ['회색', '그레이'],
    'red': ['빨강', '적색', '레드'],
    'pink': ['분홍', '핑크'],
    'purple': ['자주', '퍼플'],
    'yellow': ['노랑', '황색'],
    'orange': ['주황', '오렌지'],
    'lightGreen': ['연두'],
    'green': ['초록', '그린'],
    'teal': ['청록'],
    'blue': ['파랑', '블루'],
    'indigo': ['남색', '인디고'],
    'deepPurple': ['보라'],
    'brown': ['갈색', '브라운'],
    'black': ['검정', '블랙'],
  };
  final _api = DrugApiService();
  bool isLoading = true;
  List<Map<String, dynamic>> searchResults = [];

  // 🛒 장바구니 목록
  List<Map<String, dynamic>> cartItems = [];

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

    final data = await _api.fetchPillInfo();
    debugPrint('API 결과: $data');

    if (mounted) {
      setState(() {
        isLoading = false;
        final body = data?['body'];
        final items = body?['items'];
        if (items != null && items is List) {
          final allItems = List<Map<String, dynamic>>.from(items);

          searchResults = allItems.where((item) {
            bool shapeMatch = true;
            bool colorMatch = true;

            if (widget.shape != null && widget.shape!.isNotEmpty) {
              shapeMatch = widget.shape!.contains(item['DRUG_SHAPE']);
            }

            // 색상 필터링: 여러 색상 표현 매핑 대응
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
                // 결과 목록
                Expanded(
                  child: searchResults.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // - 버튼
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          cartItems.removeWhere((element) => element['ITEM_SEQ'] == item['ITEM_SEQ']);
                                        });
                                      },
                                    ),
                                    // 약 이미지 & 이름
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
                                    // + 버튼
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline, color: Colors.teal),
                                      onPressed: () {
                                        setState(() {
                                          // 중복 추가 방지
                                          if (!cartItems.any((e) => e['ITEM_SEQ'] == item['ITEM_SEQ'])) {
                                            cartItems.add(item);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // 장바구니
                if (cartItems.isNotEmpty)
                  Container(
                    height: 100,
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: cartItems.length,
                            separatorBuilder: (_, __) => SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cartItem = cartItems[index];
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
                                        setState(() {
                                          cartItems.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(2),
                                        child: Icon(Icons.close, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Container(
                          height: 60,
                          child: IconButton(
                            icon: Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FinalResultScreen(
                                    selectedItems: cartItems,
                                  ),
                                ),
                              );
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