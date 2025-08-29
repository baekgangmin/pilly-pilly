// lib/api_services/api_helper.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/token_service.dart';

class ApiHelper {
  static final AuthService _auth = AuthService();

  /// 매 호출마다 유효한 access를 가져와 Authorization 헤더를 만든다.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _auth.getValidToken(); // 만료면 refresh만 시도, 실패 시 null
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }


  /// (옵션) 공통 GET: 401 나오면 refresh 후 1회 재시도, 403은 권한 없음 처리
  static Future<http.Response> getWithAuth(Uri uri) async {
    var headers = await getAuthHeaders();
    var res = await http.get(uri, headers: headers);

    if (res.statusCode == 401) {
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) {
        headers = {
          ...headers,
          'Authorization': 'Bearer $newToken',
        };
        res = await http.get(uri, headers: headers);
      }
    } else if (res.statusCode == 403) {
      // 🚀 403 Forbidden: 권한 없음 (자동 복구 불가)
      print("🚫 [ApiHelper] 403 Forbidden - 권한 없음: ${uri.path}");
      // 403은 토큰 갱신으로 해결되지 않으므로 그대로 반환
    } else if (res.statusCode == 408) {
      // 🚀 408 Timeout: 요청 시간 초과 - 자동 재시도
      print("⏰ [ApiHelper] 408 Timeout - 자동 재시도: ${uri.path}");
      try {
        // 짧은 지연 후 재시도
        await Future.delayed(const Duration(milliseconds: 500));
        res = await http.get(uri, headers: headers);
        if (res.statusCode == 200) {
          print("✅ [ApiHelper] 408 재시도 성공: ${uri.path}");
        }
      } catch (e) {
        print("❌ [ApiHelper] 408 재시도 실패: ${uri.path} - $e");
      }
    } else if (res.statusCode == 422) {
      // 🚀 422 Unprocessable Entity: 이미지 추론 실패 (bbox 인식 실패)
      print("🖼️ [ApiHelper] 422 Unprocessable Entity - 이미지 추론 실패: ${uri.path}");
      // 422는 이미지 품질 문제이므로 그대로 반환
    }
    // 🚀 404는 API별로 다르게 처리하므로 여기서는 로깅만
    return res;
  }


  /// (옵션) 공통 POST도 필요하면 추가
  static Future<http.Response> postWithAuth(Uri uri, {Object? body}) async {
    var headers = await getAuthHeaders();
    var res = await http.post(uri, headers: headers, body: body);

    if (res.statusCode == 401) {
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) {
        headers = {
          ...headers,
          'Authorization': 'Bearer $newToken',
        };
        res = await http.post(uri, headers: headers, body: body);
      }
    } else if (res.statusCode == 403) {
      // 🚀 403 Forbidden: 권한 없음 (자동 복구 불가)
      print("🚫 [ApiHelper] 403 Forbidden - 권한 없음: ${uri.path}");
      // 403은 토큰 갱신으로 해결되지 않으므로 그대로 반환
    } else if (res.statusCode == 408) {
      // 🚀 408 Timeout: 요청 시간 초과 - 자동 재시도
      print("⏰ [ApiHelper] 408 Timeout - 자동 재시도: ${uri.path}");
      try {
        // 짧은 지연 후 재시도
        await Future.delayed(const Duration(milliseconds: 500));
        res = await http.post(uri, headers: headers, body: body);
        if (res.statusCode == 200) {
          print("✅ [ApiHelper] 408 재시도 성공: ${uri.path}");
        }
      } catch (e) {
        print("❌ [ApiHelper] 408 재시도 실패: ${uri.path} - $e");
      }
    } else if (res.statusCode == 422) {
      // 🚀 422 Unprocessable Entity: 이미지 추론 실패 (bbox 인식 실패)
      print("🖼️ [ApiHelper] 422 Unprocessable Entity - 이미지 추론 실패: ${uri.path}");
      // 422는 이미지 품질 문제이므로 그대로 반환
    }
    // 🚀 404는 API별로 다르게 처리하므로 여기서는 로깅만
    return res;
  }

  /// (옵션) 공통 DELETE도 필요하면 추가
  static Future<http.Response> deleteWithAuth(Uri uri, {Object? body}) async {
    var headers = await getAuthHeaders();
    var res = await http.delete(uri, headers: headers, body: body);

    if (res.statusCode == 403) {
      // 🚀 403 Forbidden: 권한 없음 (자동 복구 불가)
      print("🚫 [ApiHelper] 403 Forbidden - 권한 없음: ${uri.path}");
      // 403은 토큰 갱신으로 해결되지 않으므로 그대로 반환
    } else if (res.statusCode == 408) {
      // 🚀 408 Timeout: 요청 시간 초과 - 자동 재시도
      print("⏰ [ApiHelper] 408 Timeout - 자동 재시도: ${uri.path}");
      try {
        // 짧은 지연 후 재시도
        await Future.delayed(const Duration(milliseconds: 500));
        res = await http.delete(uri, headers: headers, body: body);
        if (res.statusCode == 200) {
          print("✅ [ApiHelper] 408 재시도 성공: ${uri.path}");
        }
      } catch (e) {
        print("❌ [ApiHelper] 408 재시도 실패: ${uri.path} - $e");
      }
    } else if (res.statusCode == 422) {
      // 🚀 422 Unprocessable Entity: 이미지 추론 실패 (bbox 인식 실패)
      print("🖼️ [ApiHelper] 422 Unprocessable Entity - 이미지 추론 실패: ${uri.path}");
      // 422는 이미지 품질 문제이므로 그대로 반환
    } else if (res.statusCode == 401) {
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) {
        headers = {
          ...headers,
          'Authorization': 'Bearer $newToken',
        };
        res = await http.delete(uri, headers: headers, body: body);
      }
    }
    return res;
  }

  /// 이미지 크롤링 API 호출 (getWithAuth에서 401 자동 처리)
  static Future<String?> fetchCrawledImage(String itemSeq) async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print("❌ [ApiHelper] API_BASE_URL이 설정되지 않음: $itemSeq");
        return null;
      }
      
      final url = Uri.parse('$baseUrl/image-scrape').replace(
        queryParameters: {
          'item_seq': itemSeq,
        },
      );
      
      // 🚀 getWithAuth에서 401, 403, 404 에러를 자동으로 처리
      final response = await getWithAuth(url);
      
      if (response.statusCode == 200) {
        return _processSuccessfulResponse(response, baseUrl, itemSeq);
      } else if (response.statusCode == 404) {
        // 🚀 404 Not Found: 이미지가 존재하지 않음
        print("🔍 [ApiHelper] 크롤링 이미지 404 - 이미지 없음: $itemSeq");
        return null; // no_image로 처리
      } else {
        print("❌ [ApiHelper] 크롤링 이미지 API 실패: ${response.statusCode} - $itemSeq");
        return null;
      }
    } catch (e) {
      print("❌ [ApiHelper] 크롤링 이미지 요청 중 오류: $itemSeq - $e");
      return null;
    }
  }

  /// 성공 응답 처리 (코드 중복 제거)
  static String? _processSuccessfulResponse(http.Response response, String baseUrl, String itemSeq) {
    // 응답 헤더에서 이미지 URL 확인
    final contentType = response.headers['content-type'];
    if (contentType?.startsWith('image/') == true) {
      // 이미지 파일이 직접 반환된 경우, URL을 직접 구성
      var imageUrl = '$baseUrl/image-scrape?item_seq=$itemSeq';
      print("🖼️ [ApiHelper] 크롤링 이미지 성공 (직접 반환): $imageUrl");
      return imageUrl;
    }

    // JSON 응답인 경우 파싱 시도
    try {
      final data = jsonDecode(response.body);
      final imageUrl = data['imageUrl'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        print("🖼️ [ApiHelper] 크롤링 이미지 성공 (JSON): $imageUrl");
        return imageUrl;
      }
    } catch (parseError) {
      print("⚠️ [ApiHelper] JSON 파싱 실패, 이미지 파일로 간주: $parseError");
      // 이미지 파일로 간주하고 URL 반환
      var imageUrl = '$baseUrl/image-scrape?item_seq=$itemSeq';
      return imageUrl;
    }

    print("⚠️ [ApiHelper] 크롤링 이미지 URL을 찾을 수 없습니다: $itemSeq");
    return null;
  }

  /// 기존 메서드들 (하위 호환성 유지)
  static Future<http.Response> getWithAuthOld(Uri url) async {
    final headers = await getAuthHeaders();
    return http.get(url, headers: headers);
  }

  static Future<http.Response> postWithAuthOld(Uri url, {Map<String, dynamic>? body}) async {
    final headers = await getAuthHeaders();
    return http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// 실시간 알약 검색 top 10 가져오기
  static Future<List<Map<String, dynamic>>> getTopPills() async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print("⚠️ API_BASE_URL이 설정되지 않았습니다.");
        return [];
      }

      // 날짜 계산 (접속일자 - 7일 ~ 접속일자)
      final now = DateTime.now();
      final endDate = now.toIso8601String().split('T')[0]; // YYYY-MM-DD
      final startDate = now.subtract(Duration(days: 7)).toIso8601String().split('T')[0]; // YYYY-MM-DD

      final url = Uri.parse('$baseUrl/stats/top-pills').replace(
        queryParameters: {
          'start': startDate,
          'end': endDate,
          'tz_offset_minutes': '540',
          'limit': '10',
        },
      );

      print("📡 top 10 API 호출: $url");
      final response = await getWithAuthOld(url);
      
      print("📊 API 응답 상태: ${response.statusCode}");
      print("📄 응답 바디: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🔍 파싱된 데이터: $data");
        
        // 다양한 응답 구조 처리
        List<Map<String, dynamic>> topPills = [];
        
        if (data['rows'] != null) {
          // rows 배열 형태로 응답하는 경우
          topPills = List<Map<String, dynamic>>.from(data['rows']);
        } else if (data['data'] != null) {
          topPills = List<Map<String, dynamic>>.from(data['data']);
        } else if (data['top_pills'] != null) {
          topPills = List<Map<String, dynamic>>.from(data['top_pills']);
        } else if (data['pills'] != null) {
          topPills = List<Map<String, dynamic>>.from(data['pills']);
        } else if (data['results'] != null) {
          topPills = List<Map<String, dynamic>>.from(data['results']);
        } else if (data is List) {
          // 배열 형태로 직접 응답하는 경우
          topPills = List<Map<String, dynamic>>.from(data);
        } else {
          print("⚠️ 알 수 없는 응답 구조: $data");
          return [];
        }

        print("✅ top 10 데이터 로드 성공: ${topPills.length}개");
        for (int i = 0; i < topPills.length; i++) {
          final pill = topPills[i];
          print("  ${i + 1}. ${pill['name'] ?? pill['itemName'] ?? '이름 없음'}");
        }
        
        return topPills;
      } else {
        print("❌ top 10 API 호출 실패: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ top 10 API 호출 중 오류: $e");
      return [];
    }
  }
}
