import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 전역 비교함(=장바구니 대체) 노티파이어 — 단일 소스 오브 트루스
/// - 모든 화면은 이 클래스를 통해서만 담기/삭제/전체삭제/표시(배지) 수행
/// - SharedPreferences에는 `compare_tray_v1` 키로만 저장 (이전 `unified_cart`에서 마이그레이션)
class CompareTray extends ChangeNotifier {
  CompareTray._internal();
  static final CompareTray instance = CompareTray._internal();

  /// 새로운 영구 저장 키
  static const String _prefsKey = 'compare_tray_v1';
  /// 과거 코드에서 쓰던 키 (마이그레이션 후 제거)
  static const String _legacyKey = 'unified_cart';

  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final Set<String> _seqs = <String>{};
  bool _loaded = false; // 중복 초기화 방지
  bool get isLoaded => _loaded;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool contains(String itemSeq) => _seqs.contains(itemSeq);

  /// 앱 시작 시 1회만 호출해서 로컬 상태 로드 + 레거시 데이터 마이그레이션
  Future<void> init() async {
    if (_loaded) return;
    await _loadAndMigrate();
    _loaded = true;
    notifyListeners();
  }

  /// 외부에서 동기 재확인이 필요할 때 호출 (예: 방어적으로 새로고침)
  Future<void> refresh() async {
    await _loadAndMigrate();
    notifyListeners();
  }

  Future<void> _loadAndMigrate() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> merged = [];

    // 1) 최신 포맷 로드
    final nowRaw = prefs.getString(_prefsKey);
    if (nowRaw != null && nowRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(nowRaw) as List<dynamic>;
        for (final e in list) {
          if (e is Map) {
            merged.add(Map<String, dynamic>.from(e as Map));
          }
        }
      } catch (_) {}
    }

    // 2) 레거시 포맷도 있으면 합치고 이후 제거
    final legacyRaw = prefs.getString(_legacyKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(legacyRaw) as List<dynamic>;
        for (final e in list) {
          if (e is Map) {
            merged.add(Map<String, dynamic>.from(e as Map));
          }
        }
      } catch (_) {}
      // 레거시 키는 제거 (한 번만)
      await prefs.remove(_legacyKey);
    }

    // 3) 정규화 + 중복 제거
    _items.clear();
    _seqs.clear();

    final seen = <String>{};
    for (final m in merged) {
      final seq = (m['itemSeq'] ?? '').toString();
      if (seq.isEmpty || seen.contains(seq)) continue;

      // 필수 필드 보정
      final normalized = <String, dynamic>{
        'itemSeq': seq,
        'itemName': (m['itemName'] ?? '이름 없음').toString(),
        'entpName': (m['entpName']?.toString()),
        'imageUrl': _pickHttpUrl([
          m['imageUrl']?.toString(),
          m['ITEM_IMAGE']?.toString(),
          m['permit'] is Map ? (m['permit']['permitDetail']?['images']?['main']?.toString()) : null,
          m['permit'] is Map ? (m['permit']['permitDetail']?['itemImage']?.toString()) : null,
          m['permit'] is Map ? (m['permit']['permitList']?['imageUrl']?.toString()) : null,
          m['images'] is Map ? (m['images']['main']?.toString()) : null,
        ]),
        'ts': (m['ts']?.toString()) ?? DateTime.now().toIso8601String(),
        'source': (m['source']?.toString()) ?? 'compare',
      };

      _items.add(normalized);
      _seqs.add(seq);
      seen.add(seq);
    }

    // 최신 포맷으로 저장
    await _persist();
  }

  static String? _pickHttpUrl(List<String?> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final fixed = c.startsWith('//') ? 'https:$c' : c;
      if (fixed.startsWith('http')) return fixed;
    }
    return null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_items));
  }

  /// 통일된 입력 포맷으로 담기 (중복 시 맨 앞으로 이동)
  Future<void> addNormalized({
    required String itemSeq,
    required String itemName,
    String? entpName,
    String? imageUrl,
    Map<String, dynamic>? extra,
  }) async {
    if (itemSeq.isEmpty) return;

    // 중복이면 제거 후 앞으로
    _items.removeWhere((m) => (m['itemSeq']?.toString() ?? '') == itemSeq);

    final newMap = <String, dynamic>{
      'itemSeq': itemSeq,
      'itemName': itemName,
      'entpName': entpName,
      'imageUrl': imageUrl,
      'ts': DateTime.now().toIso8601String(),
      'source': 'compare',
      ...?extra,
    };

    _items.insert(0, newMap);
    _seqs.add(itemSeq);
    await _persist();
    notifyListeners();
  }

  /// 다양한 키 형태에서 안전 추출해서 담기 (이미지/특징/이름검색 공통)
  Future<void> addFromDynamic(Map<String, dynamic> src) async {
    final String itemSeq = (src['itemSeq'] ?? src['ITEM_SEQ'])?.toString() ?? '';
    if (itemSeq.isEmpty) return;

    final String itemName = (src['itemName'] ?? src['ITEM_NAME'] ?? '이름 없음').toString();
    final String? entpName = (
          src['entpName'] ??
          src['ENTP_NAME'] ??
          src['permit']?['permitList']?['entpName'] ??
          src['permit']?['permitDetail']?['entpName']
        )
        ?.toString();

    final imageUrl = _pickHttpUrl([
      src['imageUrl']?.toString(),
      src['ITEM_IMAGE']?.toString(),
      src['permit']?['permitDetail']?['itemImage']?.toString(),
      src['permit']?['permitDetail']?['images']?['main']?.toString(),
      src['permit']?['permitList']?['imageUrl']?.toString(),
      src['images']?['main']?.toString(),
    ]);

    await addNormalized(
      itemSeq: itemSeq,
      itemName: itemName,
      entpName: entpName,
      imageUrl: imageUrl,
    );
  }

  Future<void> remove(String itemSeq) async {
    _items.removeWhere((m) => (m['itemSeq']?.toString() ?? '') == itemSeq);
    _seqs.remove(itemSeq);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    _seqs.clear();
    await _persist();
    notifyListeners();
  }
}