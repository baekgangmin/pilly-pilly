// lib/web/admin_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class AdminApi {
  final String adminKey;
  AdminApi(this.adminKey);

  Map<String,String> get _headersGet => {
    'accept': 'application/json',
    'X-ADMIN-KEY': adminKey,
  };

  Map<String,String> get _headersJson => {
    'accept': 'application/json',
    'content-type': 'application/json',
    'X-ADMIN-KEY': adminKey,
  };

  Uri _u(String path,[Map<String,dynamic>? q]) =>
    Uri.parse('$BASE_URL$path').replace(
      queryParameters: q?.map((k,v)=>MapEntry(k, v?.toString()))
    );

  // ----- 모델 성능 통계 -----
  Future<Map<String, dynamic>> getModelLogs({
    int page=1, int limit=50, String? userId, String? start, String? end
  }) async {
    final q = {
      'page': page, 'limit': limit,
      if(userId?.isNotEmpty == true) 'user_id': userId,
      if(start?.isNotEmpty == true) 'start': start,
      if(end?.isNotEmpty == true) 'end': end,
    };
    final res = await http.get(_u('/admin/logs', q), headers:_headersGet);
    return _json(res);
  }

  Future<Map<String, dynamic>> getModelSummary({
    String? userId, String? start, String? end
  }) async {
    final q = {
      if(userId?.isNotEmpty == true) 'user_id': userId,
      if(start?.isNotEmpty == true) 'start': start,
      if(end?.isNotEmpty == true) 'end': end,
    };
    final res = await http.get(_u('/admin/summary', q), headers:_headersGet);
    return _json(res);
  }

  Future<http.Response> getModelImage(String imageFileId) async {
    return await http.get(_u('/admin/image/$imageFileId'), headers:_headersGet);
  }

  // ----- 관리자/감사 액션 -----
  Future<Map<String,dynamic>> blockUser(String userId) async {
    final res = await http.delete(_u('/admin/user/$userId'), headers:_headersJson);
    return _json(res);
  }

  Future<Map<String,dynamic>> unblockUser(String userId) async {
    final res = await http.put(_u('/admin/user/$userId/unblock'), headers:_headersJson);
    return _json(res);
  }

  Future<Map<String,dynamic>> deleteData({
    required String target, bool dryRun=true, bool hard=false,
    String? start, String? end, String? userId, int? olderThanDays
  }) async {
    final q = {
      'dry_run': dryRun, 'hard': hard,
      if(start?.isNotEmpty == true) 'start': start,
      if(end?.isNotEmpty == true) 'end': end,
      if(userId?.isNotEmpty == true) 'user_id': userId,
      if(olderThanDays != null) 'older_than_days': olderThanDays,
    };
    final res = await http.delete(_u('/admin/data/$target', q), headers:_headersJson);
    return _json(res);
  }

  Future<Map<String,dynamic>> getAuditLogs({
    int page=1, int limit=20, String? action, String? adminId
  }) async {
    final q = {
      'page': page, 'limit': limit,
      if(action?.isNotEmpty == true) 'action': action,
      if(adminId?.isNotEmpty == true) 'admin_id': adminId,
    };
    final res = await http.get(_u('/admin/audit-logs', q), headers:_headersGet);
    return _json(res);
  }

  Map<String, dynamic> _json(http.Response res) {
  final ct = (res.headers['content-type'] ?? '').toLowerCase();
  if (!ct.contains('application/json')) {
    final preview = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
    throw Exception(
      'Invalid response: status=${res.statusCode}, content-type=$ct, body="$preview"'
    );
  }

  final body = res.body.isEmpty ? '{}' : res.body;
  final map = jsonDecode(body) as Map<String, dynamic>;
  if (res.statusCode >= 400) {
    throw Exception(map['detail']?.toString() ?? 'API error ${res.statusCode}');
  }
  return map;
}
}
