import 'package:flutter/material.dart';

class FailInferenceFeatureResultScreen extends StatelessWidget {
  final List<dynamic> results;

  const FailInferenceFeatureResultScreen({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For now, assume searchResults is fetched or passed to this screen
    final List<String> searchResults = results.cast<String>();

    debugPrint('이미지 실패 검색 결과 화면 빌드 중...');

    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 실패용 유사 검색 결과'),
      ),
      body: searchResults.isEmpty
          ? const Center(
              child: Text(
                '유사한 검색 결과가 없습니다.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final result = searchResults[index];
                debugPrint('검색 결과 아이템: $result');
                return ListTile(
                  title: Text(result),
                );
              },
            ),
    );
  }
}
