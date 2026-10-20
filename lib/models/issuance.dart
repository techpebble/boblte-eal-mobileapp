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

class IssuanceModel {
  final String id;
  final String companyName;
  final String packName;
  final DateTime dateIssued;
  final int issuedQuantity;
  late int balanceQuantity;
  late String market;
  final String prefix;
  final String serialFrom;
  final String serialTo;
  late List<SerialRangeModel> usedSerialRanges;

  IssuanceModel({
    required this.id,
    required this.companyName,
    required this.packName,
    required this.dateIssued,
    required this.issuedQuantity,
    required this.balanceQuantity,
    required this.market,
    required this.prefix,
    required this.serialFrom,
    required this.serialTo,
    required this.usedSerialRanges,
  });

  factory IssuanceModel.fromJson(Map<String, dynamic> json) {
    return IssuanceModel(
      id: json['_id'],
      companyName: json['company']['name'],
      packName: json['pack']['name'],
      dateIssued: DateTime.parse(json['dateIssued']),
      issuedQuantity: json['issuedQuantity'],
      balanceQuantity: json['balanceQuantity'],
      market: json['market'],
      prefix: json['prefix'],
      serialFrom: json['serialFrom'].toString(),
      serialTo: json['serialTo'].toString(),
      usedSerialRanges: (json['usedSerialRanges'] as List)
          .map((e) => SerialRangeModel.fromJson(e))
          .toList(),
    );
  }
}