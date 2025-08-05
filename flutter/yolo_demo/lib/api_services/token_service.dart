// token_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static const String tokenKey = 'jwt_token';

  // 토큰 발급
  Future<bool> fetchToken() async {
    final url = Uri.parse('$baseUrl/auth/token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final token = jsonDecode(response.body)['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);
      print("✅ 토큰 발급 성공: $token");
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
}