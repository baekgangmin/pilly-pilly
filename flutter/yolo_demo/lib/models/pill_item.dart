class PillItem {
  final String id;
  final String name;
  final String? imageUrl;

  PillItem({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PillItem && id == other.id);

  @override
  int get hashCode => id.hashCode;
}