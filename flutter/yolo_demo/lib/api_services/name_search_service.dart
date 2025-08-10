import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';

class NameSearchService {
  final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  Future<List<Map<String, dynamic>>> searchByName(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/keyword-search?keyword=$query');
      final headers = await ApiHelper.getAuthHeaders();

      final response = await http.get(
        uri,
        headers: headers,
      );

      debugPrint('📡 NameSearch 응답 코드: ${response.statusCode}');
      debugPrint('📡 NameSearch 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> resultList = decoded['results']['items'];
        return resultList.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ 실패 응답: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❗ 오류 발생: $e');
      return [];
    }
  }
}