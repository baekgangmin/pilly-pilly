import 'package:flutter/material.dart';
import 'package:yolo_demo/screens/feature_search_result.dart';

class FeatureSearchScreen extends StatefulWidget {
  const FeatureSearchScreen({Key? key}) : super(key: key);

  @override
  State<FeatureSearchScreen> createState() => _FeatureSearchScreenState();
}

class _FeatureSearchScreenState extends State<FeatureSearchScreen> {
  // 색상 선택 상태
  Map<String, bool> selectedColors = {};

  // 색상 그룹 선택 상태
  Map<String, bool> groupSelected = {};

  // 텍스트 입력
  TextEditingController frontTextController = TextEditingController();
  TextEditingController backTextController = TextEditingController();

  // 모양 선택
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
    {
      'group': '흰색/투명',
      'colors': ['white', 'bin'],
    },
    {
      'group': '빨강/분홍/자주',
      'colors': ['red', 'pink', 'purple'],
    },
    {
      'group': '노랑/주황',
      'colors': ['yellow', 'orange'],
    },
    {
      'group': '연두/초록/청록',
      'colors': ['lightGreen', 'green', 'teal'],
    },
    {
      'group': '파랑/남색/보라',
      'colors': ['blue', 'indigo', 'deepPurple'],
    },
    {
      'group': '갈색/회색/검정',
      'colors': ['brown', 'gray', 'black'],
    },
  ];

  final Map<String, Color> colorMap = {
    'white': Colors.white,
    'bin': Colors.transparent,
    'gray': Colors.grey,
    'red': Colors.red,
    'pink': Colors.pink,
    'purple': Colors.purple,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'lightGreen': Colors.lightGreen,
    'green': Colors.green,
    'teal': Colors.teal,
    'blue': Colors.blue,
    'indigo': Colors.indigo,
    'deepPurple': Colors.deepPurple,
    'brown': Colors.brown,
    'black': Colors.black,
  };

  final Map<String, String> colorLabels = {
    'white': '흰색',
    'bin': '투명',
    'gray': '회색',
    'red': '빨강',
    'pink': '분홍',
    'purple': '자주',
    'yellow': '노랑',
    'orange': '주황',
    'lightGreen': '연두',
    'green': '초록',
    'teal': '청록',
    'blue': '파랑',
    'indigo': '남색',
    'deepPurple': '보라',
    'brown': '갈색',
    'black': '검정',
  };

  @override
  void initState() {
    super.initState();
    // 초기화
    for (var g in colorGroups) {
      groupSelected[g['group']] = false;
      for (var c in g['colors']) {
        selectedColors[c] = false;
      }
    }
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
            // 선택 초기화
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

            // 모양 선택
            _buildShapeSelector(),

            const SizedBox(height: 16),

            // 글씨 입력
            _buildTextInputRow(),

            const SizedBox(height: 16),

            // 색상 그룹
            _buildColorGroupsBox(),

            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 255, 251, 206),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
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
                    ),
                  ),
                );
              },
              child: const Text('검색하기'),
            ),
          ],
        ),
      ),
    );
  }

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