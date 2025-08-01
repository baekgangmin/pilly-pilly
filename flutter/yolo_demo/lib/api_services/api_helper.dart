import 'package:yolo_demo/api_services/token_service.dart';

class ApiHelper {
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}