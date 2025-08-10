// lib/screens/no_inference_screen.dart
import 'package:yolo_demo/api_services/feature_search_service.dart';
import 'package:flutter/material.dart';
import 'loading_screen.dart';

class NoInferenceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> summary;

  const NoInferenceScreen({Key? key, required this.summary}) : super(key: key);

  @override
  State<NoInferenceScreen> createState() => _NoInferenceScreenState();
}

class _NoInferenceScreenState extends State<NoInferenceScreen> {
  int? selectedIdx;
  late final List<Map<String, dynamic>> validSummary;
  final TextEditingController _textController = TextEditingController();

  final FeatureSearchService _featureSearchService = FeatureSearchService();

  @override
  void initState() {
    super.initState();
    validSummary = widget.summary.where((item) {
      final imageUrl = item['imageUrl'];
      return imageUrl != null && imageUrl.toString().isNotEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('유사한 알약을 선택해주세요'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '유사한 알약 중 하나를 선택해주세요!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: validSummary.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final item = validSummary[index];
                  final imageUrl = item['imageUrl'] ?? '';
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedIdx = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedIdx == index ? Colors.blue : Colors.grey,
                          width: selectedIdx == index ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '찾으시는 알약에 쓰여있는 글씨가 있나요?',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '(선택)',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            ElevatedButton(
              onPressed: selectedIdx != null
                  ? () {
                      final selectedItem = validSummary[selectedIdx!];
                      final selectedItemSeq = selectedItem['itemSeq'];
                      final userTypedText = _textController.text;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoadingScreen(
                            itemSeq: selectedItemSeq,
                            userTypedText: userTypedText,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('이 알약 선택하기'),
            ),
          ],
        ),
      ),
    );
  }
}