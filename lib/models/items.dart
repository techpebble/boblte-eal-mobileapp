class Item {
  final String id;
  final String itemCode;
  final String name;
  final String market;
  final String brand;
  final String company;
  final String pack;
  final int bottlesPerCase;
  final bool isActive;

  Item({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.market,
    required this.brand,
    required this.company,
    required this.pack,
    required this.bottlesPerCase,
    this.isActive = true,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['_id'],
      itemCode: json['itemCode'],
      name: json['name'],
      brand: json['brand'],
      market: json['market'],
      company: _referenceId(json['company']),
      pack: _referenceId(json['pack']),
      bottlesPerCase: json['bottlesPerCase'],
      isActive: json['isActive'] != false,
    );
  }

  // New API responses populate these references; older responses contain IDs.
  // Keep IDs here because production submissions require ObjectId strings.
  static String _referenceId(dynamic value) {
    final id = value is Map ? value['_id'] : value;
    if (id is! String || id.isEmpty) {
      throw const FormatException('Item is missing a company or pack ID');
    }
    return id;
  }
}
