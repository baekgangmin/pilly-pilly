import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';

class ImageSearchService {
  final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  Future<String?> sendImage(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/image-search');

      final headers = await ApiHelper.getAuthHeaders();
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file', // 서버에서 지정한 form-data 키 이름
            imageFile.path,
            filename: basename(imageFile.path),
          ),
        );

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      debugPrint('📡 ImageSearch 응답 코드: ${response.statusCode}');
      debugPrint('📡 ImageSearch 응답 본문: $responseBody');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        return decoded['data']; // 백엔드가 {'result': 'itemseq'} 식으로 응답 시
      } else {
        print('❌ 서버 응답 실패: ${response.statusCode}, ${await response.stream.bytesToString()}');
        return null;
      }
    } catch (e) {
      print('❗ 오류 발생: $e');
      return null;
    }
  }
}