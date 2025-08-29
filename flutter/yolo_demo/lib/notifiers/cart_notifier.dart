import 'package:flutter/foundation.dart';

class CartItem {
  final String itemSeq;
  final String itemName;
  final String? entpName;
  final String? imageUrl;

  CartItem({
    required this.itemSeq,
    required this.itemName,
    required this.entpName,
    this.imageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CartItem && other.itemSeq == itemSeq);

  @override
  int get hashCode => itemSeq.hashCode;
} 

class CartNotifier extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalCount => _items.length;
  bool contains(String itemSeq) => _items.any((e) => e.itemSeq == itemSeq);

  void add(CartItem item) {
    if (!contains(item.itemSeq)) {
      _items.add(item);
      notifyListeners();
    }
  }

  void remove(String itemSeq) {
    _items.removeWhere((e) => e.itemSeq == itemSeq);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// 이미지기반/특징기반 결과 어디서 오든 안전하게 추출해서 담는 헬퍼
  /// - itemSeq: 'itemSeq' | 'ITEM_SEQ'
  /// - itemName: 'itemName' | 'ITEM_NAME'
  /// - imageUrl 후보 다수 (http/https 인 것만)
  void addFromDynamic(Map<String, dynamic> src) {
    final seq = (src['itemSeq'] ?? src['ITEM_SEQ'])?.toString();
    if (seq == null || seq.isEmpty) return;

    final name = (src['itemName'] ?? src['ITEM_NAME'] ?? '이름 없음').toString();
    final entpName = (src['entpName'] ?? src['ENTP_NAME'] ?? '제조사 없음').toString();

    // 이미지 URL 후보 모아보기
    final candidates = <String?>[
      src['imageUrl']?.toString(),
      src['ITEM_IMAGE']?.toString(),
      // 서버 통합 응답 형태 대비
      src['permit']?['permitDetail']?['itemImage']?.toString(),
      src['permit']?['permitDetail']?['images']?['main']?.toString(),
      src['permit']?['permitList']?['imageUrl']?.toString(),
      src['images']?['main']?.toString(),
    ];

    String? url;
    for (final c in candidates) {
      if (c == null) continue;
      // //로 시작하면 프로토콜 보정
      final fixed = c.startsWith('//') ? 'https:$c' : c;
      if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
        url = fixed;
        break;
      }
    }

    add(CartItem(itemSeq: seq, itemName: name, entpName: entpName, imageUrl: url));
  }
}