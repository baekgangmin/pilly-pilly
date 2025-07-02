import 'package:flutter/material.dart';

class FeatureSearchScreen extends StatefulWidget {
  const FeatureSearchScreen({Key? key}) : super(key: key);

  @override
  State<FeatureSearchScreen> createState() => _FeatureSearchScreenState();
}

class _FeatureSearchScreenState extends State<FeatureSearchScreen> {
  // 색상 선택 상태
  Map<String, bool> selectedColor = {
    'white': false,
    'gray': false,
    'red': false,
    'pink': false,
    'purple': false,
    'yellow': false,
    'orange': false,
    'lightGreen': false,
    'green': false,
    'teal': false,
    'blue': false,
    'indigo': false,
    'deepPurple': false,
    'brown': false,
    'black': false,
  };

  // 텍스트 입력 상태
  TextEditingController frontTextController = TextEditingController();
  TextEditingController backTextController = TextEditingController();

  // 모양 선택 상태
  int? selectedShapeIndex;

  final List<String> shapeNames = [
    '원형',
    '타원형',
    '장방형',
    '반원',
    '삼각형',
    '사각형',
    '마름모',
    '오각형',
    '육각형',
    '팔각형',
    '기타',
  ];

  final List<IconData> shapeIcons = [
    Icons.circle,
    Icons.circle_outlined, // Note: Flutter does not have Icons.ellipse, use Icons.circle_outlined as a substitute
    Icons.rectangle,
    Icons.crop_square, // Using crop_square as a placeholder for 반원
    Icons.change_history,
    Icons.crop_din,
    Icons.diamond,
    Icons.star, // Using star as a placeholder for 오각형
    Icons.hexagon, // Flutter does not have hexagon icon, use hexagon_outlined if available or custom icon
    Icons.stop, // Using stop as a placeholder for 팔각형 (octagon)
    Icons.more_horiz,
  ];

  final Map<String, Color> colorMap = {
    'white': Colors.white,
    'bin': Colors.white,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('특징 기반 검색'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 선택 초기화 버튼
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedColor.updateAll((key, value) => false);
                    selectedShapeIndex = null;
                    frontTextController.clear();
                    backTextController.clear();
                  });
                },
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(60, 30)),
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                  foregroundColor: MaterialStateProperty.all(Colors.grey),
                  elevation: MaterialStateProperty.all(0),
                  shadowColor: MaterialStateProperty.all(Colors.transparent),
                ),
                child: const Text('선택 초기화'),
              ),
            ),
            const SizedBox(height: 8),

            // 알약 모양 선택 리스트
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: shapeNames.length,
                  itemBuilder: (context, index) {
                    IconData iconData;
                    switch (shapeNames[index]) {
                      case '원형':
                        iconData = Icons.circle;
                        break;
                      case '타원형':
                        iconData = Icons.circle_outlined;
                        break;
                      case '장방형':
                        iconData = Icons.rectangle;
                        break;
                      case '반원':
                        iconData = Icons.crop_square;
                        break;
                      case '삼각형':
                        iconData = Icons.change_history;
                        break;
                      case '사각형':
                        iconData = Icons.crop_din;
                        break;
                      case '마름모':
                        iconData = Icons.diamond;
                        break;
                      case '오각형':
                        iconData = Icons.star;
                        break;
                      case '육각형':
                        iconData = Icons.hexagon_outlined;
                        break;
                      case '팔각형':
                        iconData = Icons.stop;
                        break;
                      default:
                        iconData = Icons.more_horiz;
                        break;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            selectedShapeIndex = index;
                          });
                        },
                        icon: Icon(
                          iconData,
                          color: selectedShapeIndex == index ? Colors.grey : Colors.black,
                        ),
                        label: Text(
                          shapeNames[index],
                          style: TextStyle(
                            color: selectedShapeIndex == index ? Colors.grey : Colors.black,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selectedShapeIndex == index ? Colors.grey.shade300 : Colors.transparent,
                          side: BorderSide(
                            color: selectedShapeIndex == index ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 로고/문자 입력 한 줄 배치
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],  
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: frontTextController,
                      decoration: const InputDecoration(
                        labelText: '앞 글씨',
                        labelStyle: TextStyle(fontSize: 12),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: backTextController,
                      decoration: const InputDecoration(
                        labelText: '뒷 글씨',
                        labelStyle: TextStyle(fontSize: 12),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // 앞 로고 선택 로직
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 36),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.grey,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('앞 로고 선택'),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () {
                          // 뒷 로고 선택 로직
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 36),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.grey,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('뒷 로고 선택'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 색상 선택 영역: 6줄로 나누고 각 줄마다 Row로 구성
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],  
              ),
              child: Column(
                children: [
                  _buildColorRow(
                    ['white', 'bin'],
                    "1",
                  ),
                  _buildColorRow(
                    ['red', 'pink', 'purple'],
                    "2",
                  ),
                  _buildColorRow(
                    ['yellow', 'orange'],
                    "3",
                  ),
                  _buildColorRow(
                    ['lightGreen', 'green', 'teal'],
                    "4",
                  ),
                  _buildColorRow(
                    ['blue', 'indigo', 'deepPurple'],
                    "5",
                  ),
                  _buildColorRow(
                    ['brown', 'gray', 'black'],
                    "6",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 검색하기 버튼 width: 200으로 변경
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FeatureSearchResultScreen(),
                    ),
                  );
                },
                child: const Text('검색하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 색상 줄별로 색상 key 리스트를 받아 Row로 반환
  Widget _buildColorRow(List<String> colorKeys, String rowId) {
    // 줄별 체크박스 상태: 모두 선택됐는지 확인
    bool allSelected = colorKeys.every((k) => selectedColor[k] == true);
    bool someSelected = colorKeys.any((k) => selectedColor[k] == true);
    // 줄별 label
    List<Widget> colorWidgets = [];
    for (final k in colorKeys) {
      colorWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              selectedColor[k] = !(selectedColor[k] ?? false);
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorMap[k],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor[k] == true ? const Color.fromARGB(255, 255, 0, 0) : Colors.black,
                    width: selectedColor[k] == true ? 2 : 1,
                  ),
                ),
                child: selectedColor[k] == true
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                colorLabels[k] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
      colorWidgets.add(const SizedBox(width: 8));
    }
    // Remove last SizedBox
    if (colorWidgets.isNotEmpty) colorWidgets.removeLast();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(children: colorWidgets),
          const SizedBox(width: 12),
          Checkbox(
            value: allSelected
                ? true
                : (someSelected ? null : false),
            tristate: true,
            onChanged: (val) {
              setState(() {
                bool newVal = !(allSelected || someSelected);
                for (var k in colorKeys) {
                  selectedColor[k] = newVal;
                }
              });
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}

// 검색 결과 화면은 임시로 간단히 정의
class FeatureSearchResultScreen extends StatelessWidget {
  const FeatureSearchResultScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('검색 결과')
        ),
      body: const Center(child: Text('검색 결과 화면')),
    );
  }
}