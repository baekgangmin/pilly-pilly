import 'dart:convert';
import 'package:http/http.dart' as http;

class DrugApiService {
  static const String apiKey =
      ''; // API key 넣기

  Future<Map<String, dynamic>?> fetchPillInfo() async {
    Map<String, dynamic>? finalData;

    for (int page = 1; page <= 3; page++) {
      final url =
          'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02'
          '?serviceKey=$apiKey'
          '&type=json'
          '&numOfRows=100'
          '&pageNo=$page';

      print('요청 URL: $url');

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final jsonData = json.decode(utf8.decode(response.bodyBytes));
          print('=== page $page 응답 ===');
          print(jsonData);

          if (finalData == null) {
            finalData = jsonData;
          } else {
            // items 합치기
            final items = jsonData['body']?['items'];
            if (items != null && items is List) {
              finalData['body']['items'].addAll(items);
            }
          }
        } else {
          print('API 요청 실패: ${response.statusCode}');
        }
      } catch (e) {
        print('API 호출 오류: $e');
      }
    }

    print('=== 전체 수집된 데이터 개수: ${finalData?['body']?['items']?.length ?? 0} ===');
    return finalData;
  }

  Future<Map<String, dynamic>?> fetchPillApprovalInfo() async {
    Map<String, dynamic>? finalData;

    for (int page = 1; page <= 3; page++) {
      final url =
          'https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnDtlInq05'
          '?serviceKey=$apiKey'
          '&type=json'
          '&numOfRows=100'
          '&pageNo=$page';

      print('요청 URL: $url');

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final jsonData = json.decode(utf8.decode(response.bodyBytes));
          print('=== page $page 응답 ===');
          print(jsonData);

          if (finalData == null) {
            finalData = jsonData;
          } else {
            final items = jsonData['body']?['items'];
            if (items != null && items is List) {
              finalData['body']['items'].addAll(items);
            }
          }
        } else {
          print('API 요청 실패: ${response.statusCode}');
        }
      } catch (e) {
        print('API 호출 오류: $e');
      }
    }

    print('=== 전체 수집된 데이터 개수: ${finalData?['body']?['items']?.length ?? 0} ===');
    return finalData;
  }
}