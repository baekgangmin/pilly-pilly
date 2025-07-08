import 'package:flutter/material.dart';
import 'dart:io';

class InferenceResultScreen extends StatefulWidget {
  final List<String> bboxImagePaths;
  final List<dynamic> inferenceResults;
  final String resultsJson;

  const InferenceResultScreen({
    Key? key,
    required this.bboxImagePaths,
    required this.inferenceResults,
    required this.resultsJson,
  }) : super(key: key);

  @override
  State<InferenceResultScreen> createState() => _InferenceResultScreenState();
}

class _InferenceResultScreenState extends State<InferenceResultScreen> {
  late List<dynamic> imageResults;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    imageResults = widget.inferenceResults;
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = imageResults.isNotEmpty ? imageResults[selectedIndex] : null;
    final predictions = selectedItem?['result'] ?? [];

    predictions.sort((a, b) => (b['confidence'] as num).compareTo(a['confidence'] as num));
    final topPredictions = predictions.take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('분류 결과'),
      ),
      body: Column(
        children: [
          // 썸네일 스크롤 영역
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.bboxImagePaths.length,
              itemBuilder: (context, index) {
                final bboxPath = widget.bboxImagePaths[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: selectedIndex == index ? Colors.blue : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.file(
                      File(bboxPath),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          // 결과 리스트
          Expanded(
            child: ListView.builder(
              itemCount: topPredictions.length,
              itemBuilder: (context, index) {
                final pred = topPredictions[index];
                final String label = pred['class'] ?? '알 수 없음';
                final double confidence = (pred['confidence'] as num).toDouble();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.medication),
                  title: Text(label),
                  subtitle: Text('신뢰도: ${(confidence * 100).toStringAsFixed(2)}%'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}