import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/db_helper.dart';
import 'final_result.dart';

class NameSearchScreen extends StatelessWidget {
  final List<Map<String, dynamic>> searchResults;
  final String searchKeyword;

  const NameSearchScreen({
    Key? key,
    required this.searchResults,
    required this.searchKeyword,
  }) : super(key: key);

  Future<void> _openDetail(BuildContext context, Map<String, dynamic> item) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final itemSeq = item['itemSeq']?.toString();
    final itemName = item['itemName']?.toString();

    if (itemSeq == null || itemSeq.isEmpty) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode([itemSeq]), // 단일 itemSeq도 리스트로 전달 (서버 규격 맞춤)
      );

      Navigator.of(context).pop(); // 로딩 닫기

      if (resp.statusCode == 200) {
        final resultData = jsonDecode(resp.body);

        // 최근 검색 저장 (이름 존재 시)
        if (itemName != null) {
          final timestamp = DateTime.now().toIso8601String();
          await DBHelper.addRecentPill(
            itemSeq: itemSeq,
            itemName: itemName,
            userId: 'guest',
            timestamp: timestamp,
          );
        }

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FinalResultScreen(resultData: resultData),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('상세 조회 실패 (${resp.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 닫기 (예외 시)
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: searchResults.isEmpty
            ? Center(child: Text('검색 결과가 없습니다.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔍 검색어
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: Colors.grey[700]),
                        SizedBox(width: 6),
                        Text(
                          searchKeyword,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📊 개수 안내
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '${searchResults.length}개의 검색결과가 있습니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),

                  // 🔄 리스트
                  Expanded(
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final item = searchResults[index];
                        final imageUrl = item['imageUrl'];
                        final itemName = item['itemName'];
                        final entpName = item['entpName'];

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openDetail(context, item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.asset(
                                          'assets/no_image.png',
                                          fit: BoxFit.contain,
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    itemName ?? '이름 없음',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                                  child: Text(
                                    '제약회사: ${entpName ?? '정보 없음'}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                ),
                                Divider(color: Colors.grey[300], thickness: 1),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}