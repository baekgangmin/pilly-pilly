class PillData {
  final String itemSeq;
  final String itemName;
  final String timestamp;
  final String? userId;

  PillData({
    required this.itemSeq,
    required this.itemName,
    required this.timestamp,
    this.userId,
  });

  factory PillData.fromMap(Map<String, dynamic> map) {
    print("🧾 DB에서 가져온 Map: $map");

    return PillData(
      itemSeq: map['item_seq'],
      itemName: map['item_name'],
      timestamp: map['timestamp'],
      userId: map['user_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_seq': itemSeq,
      'item_name': itemName,
      'timestamp': timestamp,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PillData && itemSeq == other.itemSeq);

  @override
  int get hashCode => itemSeq.hashCode;
}