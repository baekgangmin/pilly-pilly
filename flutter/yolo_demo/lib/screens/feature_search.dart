import 'package:flutter/material.dart';
import 'feature_search_result.dart';

class FeatureSearchScreen extends StatefulWidget {
  const FeatureSearchScreen({super.key});

  @override
  State<FeatureSearchScreen> createState() => _FeatureSearchScreenState();
}

class _FeatureSearchScreenState extends State<FeatureSearchScreen> {
  List<Map<String, dynamic>> cartItems = [];

  void addToCart(Map<String, dynamic> item) {
    if (!cartItems.any((e) => e['ITEM_SEQ'] == item['ITEM_SEQ'])) {
      setState(() {
        cartItems.add(item);
      });
    }
  }

  void removeFromCart(Map<String, dynamic> item) {
    setState(() {
      cartItems.removeWhere((e) => e['ITEM_SEQ'] == item['ITEM_SEQ']);
    });
  }

  Map<String, bool> selectedColors = {};
  Map<String, bool> groupSelected = {};
  TextEditingController frontTextController = TextEditingController();
  TextEditingController backTextController = TextEditingController();
  List<int> selectedShapeIndices = [];

  final List<Map<String, dynamic>> shapeList = [
    {'name': '원형', 'icon': Icons.circle},
    {'name': '타원형', 'icon': Icons.egg},
    {'name': '장방형', 'icon': Icons.crop_16_9},
    {'name': '반원', 'icon': Icons.circle_outlined},
    {'name': '삼각형', 'icon': Icons.change_history},
    {'name': '사각형', 'icon': Icons.crop_square},
    {'name': '마름모', 'icon': Icons.diamond},
    {'name': '오각형', 'icon': Icons.pentagon},
    {'name': '육각형', 'icon': Icons.hexagon},
    {'name': '팔각형', 'icon': Icons.stop},
    {'name': '기타', 'icon': Icons.help_outline},
  ];

  final List<Map<String, dynamic>> colorGroups = [
    {'group': '흰색/투명', 'colors': ['하양', '투명']},
    {'group': '빨강/분홍/자주', 'colors': ['빨강', '분홍', '자주']},
    {'group': '노랑/주황', 'colors': ['노랑', '주황']},
    {'group': '연두/초록/청록', 'colors': ['연두', '초록', '청록']},
    {'group': '파랑/남색/보라', 'colors': ['파랑', '남색', '보라']},
    {'group': '갈색/회색/검정', 'colors': ['갈색', '회색', '검정']},
  ];

  final Map<String, Color> colorMap = {
    '하양': Colors.white,
    '투명': Colors.transparent,
    '회색': Colors.grey,
    '빨강': Colors.red,
    '분홍': Colors.pink,
    '자주': Colors.purple,
    '노랑': Colors.yellow,
    '주황': Colors.orange,
    '연두': Colors.lightGreen,
    '초록': Colors.green,
    '청록': Colors.teal,
    '파랑': Colors.blue,
    '남색': Colors.indigo,
    '보라': Colors.deepPurple,
    '갈색': Colors.brown,
    '검정': Colors.black,
  };

  final Map<String, String> colorLabels = {
    '하양': '흰색',
    '투명': '투명',
    '회색': '회색',
    '빨강': '빨강',
    '분홍': '분홍',
    '자주': '자주',
    '노랑': '노랑',
    '주황': '주황',
    '연두': '연두',
    '초록': '초록',
    '청록': '청록',
    '파랑': '파랑',
    '남색': '남색',
    '보라': '보라',
    '갈색': '갈색',
    '검정': '검정',
  };

  @override
  void initState() {
    super.initState();
    // 초기 상태: 모든 그룹/색상 false로 설정
    for (var g in colorGroups) {
      groupSelected[g['group']] = false;
      for (var c in g['colors']) {
        selectedColors[c] = false;
      }
    }
  }

  bool get hasSelection {
    // 최소 하나라도 선택되었는지 체크 → 검색 버튼 활성화 여부
    return selectedColors.containsValue(true) ||
        selectedShapeIndices.isNotEmpty ||
        frontTextController.text.isNotEmpty ||
        backTextController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('특징 기반 검색'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    selectedShapeIndices.clear();
                    frontTextController.clear();
                    backTextController.clear();
                    groupSelected.updateAll((key, value) => false);
                    selectedColors.updateAll((key, value) => false);
                  });
                },
                child: const Text('선택 초기화', style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 8),
            _buildShapeSelector(),
            const SizedBox(height: 16),
            _buildTextInputRow(),
            const SizedBox(height: 16),
            _buildColorGroupsBox(),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelection
                    ? const Color.fromARGB(255, 255, 251, 206)
                    : Colors.grey.shade300,
                foregroundColor: Colors.black,
              ),
              onPressed: hasSelection
                  ? () {
                      final selectedColorKeys = selectedColors.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeatureSearchResultScreen(
                            shape: selectedShapeIndices.isNotEmpty
                                ? selectedShapeIndices.map((i) => shapeList[i]['name'] as String).toList()
                                : null,
                            selectedColors: selectedColorKeys,
                            frontText: frontTextController.text.trim().isEmpty
                                ? null
                                : frontTextController.text.trim(),
                            backText: backTextController.text.trim().isEmpty
                                ? null
                                : backTextController.text.trim(),
                            cartItems: cartItems,
                            onAddToCart: addToCart,
                            onRemoveFromCart: removeFromCart,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('검색하기'),
            ),
          ],
        ),
      ),
    );
  }

  // 기타 빌더 위젯 생략 - 기존 코드 유지

  Widget _buildShapeSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(shapeList.length, (index) {
          final selected = selectedShapeIndices.contains(index);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              selected: selected,
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFFFD600),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(shapeList[index]['icon'], size: 16),
                  const SizedBox(width: 4),
                  Text(shapeList[index]['name']),
                ],
              ),
              onSelected: (bool sel) {
                setState(() {
                  if (sel) {
                    selectedShapeIndices.add(index);
                  } else {
                    selectedShapeIndices.remove(index);
                  }
                });
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextInputRow() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: frontTextController,
              decoration: const InputDecoration(
                hintText: '앞글씨',
                border: UnderlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: backTextController,
              decoration: const InputDecoration(
                hintText: '뒷글씨',
                border: UnderlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorGroupsBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: colorGroups.map((group) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: group['colors'].map<Widget>((colorKey) {
                      final selected = selectedColors[colorKey]!;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColors[colorKey] = !selected;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorMap[colorKey],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected ? const Color(0xFFFFD600) : Colors.black,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                colorLabels[colorKey]!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Checkbox(
                  value: groupSelected[group['group']],
                  onChanged: (bool? value) {
                    setState(() {
                      groupSelected[group['group']] = value!;
                      for (var c in group['colors']) {
                        selectedColors[c] = value;
                      }
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}