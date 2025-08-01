import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart'; // ✅ JWT 인증 헤더 불러오기

class FavoriteDbService {
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  /// 즐겨찾기 추가 (POST /api/v2/favorite)
  static Future<bool> sendFavorite({
    required String folderName,
    required String itemSeq,
    required String itemName,
    required String imageUrl,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v2/favorite');

    final Map<String, dynamic> data = {
      "folder_name": folderName,
      "item_seq": itemSeq,
      "item_name": itemName,
      "image_url": imageUrl,
      "source": "app",
    };

    try {
      final headers = await ApiHelper.getAuthHeaders();

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ 즐겨찾기 저장 성공!');
        return true;
      } else {
        debugPrint('❌ 즐겨찾기 저장 실패: ${response.statusCode}');
        debugPrint('응답 내용: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 예외 발생 (즐겨찾기 저장): $e');
      return false;
    }
  }

  /// 즐겨찾기 삭제 (DELETE /api/v2/favorite)
  static Future<bool> deleteFavorite({
    required String folderName,
    required String itemSeq,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v2/favorite');
    final headers = await ApiHelper.getAuthHeaders();

    try {
      // DELETE + body 전송 (http.Request 사용)
      final request = http.Request('DELETE', url)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          "folder_name": folderName,
          "item_seq": itemSeq,
        });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        debugPrint('✅ 즐겨찾기 삭제 성공');
        return true;
      } else {
        debugPrint('❌ 서버 삭제 실패: ${response.statusCode} → $responseBody');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 삭제 중 예외 발생: $e');
      return false;
    }
  }

  /// 폴더 삭제 (POST /api/v2/favorite/folder/delete)
  static Future<bool> deleteFolder(String folderName) async {
    final url = Uri.parse('$_baseUrl/api/v2/favorite/folder/delete');
    final headers = await ApiHelper.getAuthHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"folder_name": folderName}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ 폴더 삭제 성공');
        return true;
      } else {
        debugPrint('❌ 폴더 삭제 실패: ${response.statusCode} → ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('🔥 폴더 삭제 중 예외 발생: $e');
      return false;
    }
  }
}