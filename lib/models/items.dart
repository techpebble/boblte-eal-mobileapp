class Item {
  final String id;
  final String itemCode;
  final String name;

  /// Short name for lists and pickers. Full names run to things like
  /// "ORIGINAL CHOICE DELUXE WHISKY 90ML TETRAPAK x 96", which no phone
  /// screen can show. Empty on older records, hence [displayName].
  final String alias;

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
    this.alias = '',
    this.isActive = true,
  });

  /// What to show the operator: the alias where there is one, the full name
  /// otherwise.
  String get displayName => displayNameOf(alias, name);

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['_id'],
      itemCode: json['itemCode'],
      name: json['name'],
      alias: json['alias']?.toString() ?? '',
      brand: json['brand'],
      market: json['market'],
      company: _referenceId(json['company']),
      pack: _referenceId(json['pack']),
      bottlesPerCase: json['bottlesPerCase'],
      isActive: json['isActive'] != false,
    );
  }

  /// The one place the alias rule lives. Usage and dispatch records carry a
  /// populated item rather than a full [Item], so they call this too.
  static String displayNameOf(String? alias, String? name) {
    final short = alias?.trim() ?? '';
    if (short.isNotEmpty) return short;
    return name?.trim() ?? '';
  }

  /// Reads the display name straight off a populated `item` object in an API
  /// response.
  static String displayNameFromJson(dynamic itemJson) {
    if (itemJson is Map) {
      return displayNameOf(
        itemJson['alias']?.toString(),
        itemJson['name']?.toString(),
      );
    }
    return '';
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
