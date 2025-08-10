// token_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static const String tokenKey = 'jwt_token';
  static const String userIdKey = 'user_id';  // ✅ 추가

  // 토큰 + 사용자 ID 발급 및 저장
  Future<bool> fetchToken() async {
    final url = Uri.parse('$baseUrl/auth/token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final userId = data['user_id'];  // ✅ user_id 추출

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      await prefs.setString(userIdKey, userId);  // ✅ 저장
      print("✅ 토큰 발급 성공: $token, 사용자 ID: $userId");
      return true;
    } else {
      print("❌ 토큰 발급 실패: ${response.statusCode}, ${response.body}");
      return false;
    }
  }

  // 저장된 토큰 가져오기
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  // 저장된 사용자 ID 가져오기
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey);
  }
}
