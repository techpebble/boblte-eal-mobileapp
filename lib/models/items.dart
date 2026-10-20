class Item {
  final String id;
  final String itemCode;
  final String name;
  final String market;
  final String brand;
  final String company;
  final String pack;
  final int bottlesPerCase;

  Item({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.market,
    required this.brand,
    required this.company,
    required this.pack,
    required this.bottlesPerCase,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['_id'],
      itemCode: json['itemCode'],
      name: json['name'],
      brand: json['brand'],
      market: json['market'],
      company: json['company'],
      pack: json['pack'],
      bottlesPerCase: json['bottlesPerCase'],
    );
  }
}