// lib/web/admin_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class AdminApi {
  final String adminKey;
  AdminApi(this.adminKey);

  Map<String, String> get _headersGet => {
        'accept': 'application/json',
        'X-ADMIN-KEY': adminKey,
      };

  Map<String, String> get _headersJson => {
        'accept': 'application/json',
        'content-type': 'application/json',
        'X-ADMIN-KEY': adminKey,
      };

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final base = Uri.parse('$BASE_URL$path');
    if (q == null) return base;
    return base.replace(
      queryParameters: q.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  // 공통 GET 헬퍼
  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? q}) async {
    // path에 이미 쿼리가 포함되어 있으면 그대로 사용,
    // q가 있으면 replace로 세팅
    Uri uri;
    if (q == null) {
      uri = Uri.parse('$BASE_URL$path');
    } else {
      uri = Uri.parse('$BASE_URL$path').replace(
        queryParameters: q.map((k, v) => MapEntry(k, v?.toString())),
      );
    }
    final res = await http.get(uri, headers: _headersGet);
    return _json(res);
  }

  // ----- 모델 성능 통계 -----
  Future<Map<String, dynamic>> getModelLogs({
    int page = 1,
    int limit = 50,
    String? userId,
    String? start,
    String? end,
  }) async {
    final q = {
      'page': page,
      'limit': limit,
      if (userId?.isNotEmpty == true) 'user_id': userId,
      if (start?.isNotEmpty == true) 'start': start,
      if (end?.isNotEmpty == true) 'end': end,
    };
    final res = await http.get(_u('/admin/logs', q), headers: _headersGet);
    return _json(res);
  }

  Future<Map<String, dynamic>> getModelSummary({
    String? userId,
    String? start,
    String? end,
  }) async {
    final q = {
      if (userId?.isNotEmpty == true) 'user_id': userId,
      if (start?.isNotEmpty == true) 'start': start,
      if (end?.isNotEmpty == true) 'end': end,
    };
    final res = await http.get(_u('/admin/summary', q), headers: _headersGet);
    return _json(res);
  }

  Future<http.Response> getModelImage(String imageFileId) async {
    return await http.get(_u('/admin/image/$imageFileId'),
        headers: _headersGet);
  }

  // ----- 관리자/감사 액션 -----
  Future<Map<String, dynamic>> blockUser(String userId) async {
    final res =
        await http.delete(_u('/admin/user/$userId'), headers: _headersJson);
    return _json(res);
  }

  Future<Map<String, dynamic>> unblockUser(String userId) async {
    final res = await http.put(_u('/admin/user/$userId/unblock'),
        headers: _headersJson);
    return _json(res);
  }

  Future<Map<String, dynamic>> deleteData({
    required String target,
    bool dryRun = true,
    bool hard = false,
    String? start,
    String? end,
    String? userId,
    int? olderThanDays,
  }) async {
    final q = {
      'dry_run': dryRun,
      'hard': hard,
      if (start?.isNotEmpty == true) 'start': start,
      if (end?.isNotEmpty == true) 'end': end,
      if (userId?.isNotEmpty == true) 'user_id': userId,
      if (olderThanDays != null) 'older_than_days': olderThanDays,
    };
    final res =
        await http.delete(_u('/admin/data/$target', q), headers: _headersJson);
    return _json(res);
  }

  Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? adminId,
  }) async {
    final q = {
      'page': page,
      'limit': limit,
      if (action?.isNotEmpty == true) 'action': action,
      if (adminId?.isNotEmpty == true) 'admin_id': adminId,
    };
    final res =
        await http.get(_u('/admin/audit-logs', q), headers: _headersGet);
    return _json(res);
  }

  // =========================
  // 시스템 통계 API
  // =========================

  Future<Map<String, dynamic>> getStatsToday(
      {required int tzOffsetMinutes}) async {
    return await _get(
      '/admin/stats/today',
      q: {'tz_offset_minutes': tzOffsetMinutes},
    );
  }

  Future<Map<String, dynamic>> getUsageSeries({
    required String granularity, // day | week | month
    required String start, // YYYY-MM-DD
    required String end, // YYYY-MM-DD
    required int tzOffsetMinutes,
  }) async {
    return await _get(
      '/admin/stats/usage-series',
      q: {
        'granularity': granularity,
        'start': start,
        'end': end,
        'tz_offset_minutes': tzOffsetMinutes,
      },
    );
  }

  Future<Map<String, dynamic>> getTopPills({
    String? start,
    String? end,
    required int tzOffsetMinutes,
    int limit = 20,
  }) async {
    final q = <String, dynamic>{
      'tz_offset_minutes': tzOffsetMinutes,
      'limit': limit,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    };
    return await _get('/admin/stats/top-pills', q: q);
  }

  Future<Map<String, dynamic>> getTopByType({
    String? start,
    String? end,
    required int tzOffsetMinutes,
    int topK = 20,
  }) async {
    final q = <String, dynamic>{
      'tz_offset_minutes': tzOffsetMinutes,
      'top_k_each': topK,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    };
    return await _get('/admin/stats/top-by-type', q: q);
  }

  Future<Map<String, dynamic>> getIdentifyQueries({
    String? start,
    String? end,
    int? tzOffsetMinutes,
    int limit = 50,
    String? userId,
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };
    return await _get('/admin/stats/identify-queries', q: q);
  }

  Future<Map<String, dynamic>> getKeywordQueries({
    String? start,
    String? end,
    int? tzOffsetMinutes,
    int limit = 50,
    String? userId,
  }) async {
    final q = <String, dynamic>{
      'limit': limit,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };
    return await _get('/admin/stats/keyword-queries', q: q);
  }

  // ----- 차단된 사용자 통계 -----
  Future<Map<String, dynamic>> getBlockedUsersCount() async {
    return await _get('/admin/stats/blocked-users');
  }

  Map<String, dynamic> _json(http.Response res) {
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    if (!ct.contains('application/json')) {
      final preview =
          res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception(
          'Invalid response: status=${res.statusCode}, content-type=$ct, body="$preview"');
    }

    final body = res.body.isEmpty ? '{}' : res.body;
    final map = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      // Admin key 인증 실패 시 특별한 메시지
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception('Admin-key가 틀렸습니다. 올바른 키를 입력해주세요.');
      }
      throw Exception(map['detail']?.toString() ?? 'API error ${res.statusCode}');
    }
    return map;
  }
}
