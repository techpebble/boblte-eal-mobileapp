class SerialRangeModel {
  final int total;
  final int serialFrom;
  final int serialTo;

  SerialRangeModel({
    required this.total,
    required this.serialFrom,
    required this.serialTo,
  });

  factory SerialRangeModel.fromJson(Map<String, dynamic> json) {
    return SerialRangeModel(
      total: json['total'],
      serialFrom: json['serialFrom'],
      serialTo: json['serialTo'],
    );
  }
}

class UsageModel {
  final String id;
  final String companyName;
  final String itemName;
  final String packName;
  final DateTime dateUsed;
  final int usedQuantity;
  final int usedQuantityInCases;
  late int balanceQuantity;
  late int balanceQuantityInCases;
  late String market;
  final String prefix;
  final String serialFrom;
  final String serialTo;
  late List<SerialRangeModel> usedSerialRanges;

  UsageModel({
    required this.id,
    required this.companyName,
    required this.itemName,
    required this.packName,
    required this.dateUsed,
    required this.usedQuantity,
    required this.usedQuantityInCases,
    required this.balanceQuantity,
    required this.balanceQuantityInCases,
    required this.market,
    required this.prefix,
    required this.serialFrom,
    required this.serialTo,
    required this.usedSerialRanges,
  });

  factory UsageModel.fromJson(Map<String, dynamic> json) {
    return UsageModel(
      id: json['_id'],
      companyName: json['company']['name'],
      itemName: json['item']['name'],
      packName: json['pack']['name'],
      balanceQuantity: json['balanceQuantity'],
      balanceQuantityInCases: json['balanceQuantityInCases'],
      dateUsed: DateTime.parse(json['dateUsed']),
      market: json['market'],
      prefix: json['prefix'],
      serialFrom: json['serialFrom'].toString(),
      serialTo: json['serialTo'].toString(),
      usedQuantity: json['usedQuantity'],
      usedQuantityInCases: json['usedQuantityInCases'],
      usedSerialRanges: (json['usedSerialRanges'] as List)
          .map((e) => SerialRangeModel.fromJson(e))
          .toList(),
    );
  }
}