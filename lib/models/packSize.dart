class PackSize {
  final String id;
  final String name;
  final int bottlesPerCase;
  final int pack;

  PackSize({
    required this.id,
    required this.name,
    required this.bottlesPerCase,
    required this.pack,
  });

  factory PackSize.fromJson(Map<String, dynamic> json) {
    return PackSize(
      id: json['_id'],
      name: json['name'],
      bottlesPerCase: json['bottlesPerCase'],
      pack: json['pack'],
    );
  }
}