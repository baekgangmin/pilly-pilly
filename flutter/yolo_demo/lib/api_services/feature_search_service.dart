import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart'; 

class FeatureSearchService {
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  Future<Map<String, dynamic>?> fetchPillInfo({
    String? printFront,
    String? printBack,
    String? shape,
    String? colorClass1,
  }) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/v2/feature-search").replace(queryParameters: {
        if (printFront != null) 'print_front': printFront,
        if (printBack != null) 'print_back': printBack,
        if (shape != null) 'drug_shape': shape,
        if (colorClass1 != null) 'color_class1': colorClass1,
      });

      print("📡 요청 URL: $uri"); // 디버그용

      final headers = await ApiHelper.getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('🔴 API 오류: ${response.statusCode}, 본문: ${response.body}');
        return null;
      }
    } catch (e) {
      print('🔴 API 예외 발생: $e');
      return null;
    }
  }
}