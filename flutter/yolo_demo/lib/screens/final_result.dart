import 'package:flutter/material.dart';

class FinalResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedItems;

  const FinalResultScreen({Key? key, required this.selectedItems}) : super(key: key);

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedDrug = widget.selectedItems[selectedIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('결과 화면'),
      ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. 병용금기 안내
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${widget.selectedItems.map((e) => e["name"]).join("과 ")}은\n같이 섭취하시면 안 됩니다.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. 선택된 약 리스트 (가로 스크롤)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.selectedItems.length, (index) {
                  final item = widget.selectedItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedIndex == index
                            ? const Color(0xFFFFD600)
                            : Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      child: Text(item['name'] ?? '이름 없음'),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 아래 전체 묶는 큰 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 즐겨찾기/공유/점 아이콘
                  Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 이미지 박스
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      widget.selectedItems[selectedIndex]['image'] ??
                          'https://via.placeholder.com/120',
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image, size: 80),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 간단 설명 박스
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.selectedItems[selectedIndex]['efcy'] ?? '효능 정보가 없습니다.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 버튼 2개 (정사각형)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Text('약제정보')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('효능효과/용법용량/\n사용상의주의사항', textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // DUR 품목 정보 박스 (고정 높이)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Text('DUR 품목 정보')),
                  ),
                ],
              ),
            ),
          ],
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        foregroundColor: Colors.black,
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}