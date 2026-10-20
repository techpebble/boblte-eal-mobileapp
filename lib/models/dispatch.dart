class EALLinkModel {
  final String id;
  final String prefix;
  final int serialFrom;
  final int serialTo;

  EALLinkModel({
    required this.id,
    required this.prefix,
    required this.serialFrom,
    required this.serialTo,
  });

  factory EALLinkModel.fromJson(Map<String, dynamic> json) {
    return EALLinkModel(
      id: json['_id'],
      prefix: json['prefix'],
      serialFrom: json['serialFrom'],
      serialTo: json['serialTo'],
    );
  }
}

class DispatchItemModel {
  final String id;
  final String itemId;
  final String name;
  final int quantityInCases;
  final int bottlesPerCase;
  late final int issuedQty;
  late List<EALLinkModel> links;

  DispatchItemModel({
    required this.id,
    required this.itemId,
    required this.name,
    required this.quantityInCases,
    required this.bottlesPerCase,
    required this.issuedQty,
    required this.links,
  });

  factory DispatchItemModel.fromJson(Map<String, dynamic> json) {
    return DispatchItemModel(
      id: json['_id'],
      itemId: json['item']['_id'],
      name: json['item']['name'],
      quantityInCases: json['quantityInCases'],
      bottlesPerCase: json['item']['bottlesPerCase'],
      issuedQty: json['EALIssuedQuantity'],
      links: (json['EALLinks'] as List)
          .map((e) => EALLinkModel.fromJson(e))
          .toList(),
    );
  }
}

class DispatchModel {
  final String id;
  final String depotName;
  final String companyName;
  final String market;
  final int totalQuantity;
  final DateTime dateDispatched;
  final List<DispatchItemModel> items;

  late String status;
  late int issuedQty;
  late String vehicleNumber;
  late String driverName;
  late String driverContact;

  DispatchModel({
    required this.id,
    required this.status,
    required this.depotName,
    required this.companyName,
    required this.market,
    required this.totalQuantity,
    required this.issuedQty,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverContact,
    required this.dateDispatched,
    required this.items,
  });

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchModel(
      id: json['_id'],
      status: json['status'],
      depotName: json['deliveryTo']['name'],
      companyName: json['company']['name'],
      market: json['market'],
      totalQuantity: json['totalQuantity'],
      issuedQty: json['EALIssuedTotalQuantity'],
      vehicleNumber: json['vehicleDetails']?['vehicleNumber'] ?? '',
      driverName: json['vehicleDetails']?['driverName'] ?? '',
      driverContact: json['vehicleDetails']?['driverContact'] ?? '',
      dateDispatched: DateTime.parse(json['dateDispatched']),
      items: (json['items'] as List)
          .map((item) => DispatchItemModel.fromJson(item))
          .toList(),
    );
  }

  DispatchModel copyWith({
    String? status,
    int? issuedQty,
    String? vehicleNumber,
    String? driverName,
    String? driverContact,
  }) {
    return DispatchModel(
      id: id,
      status: status ?? this.status,
      depotName: depotName,
      companyName: companyName,
      market: market,
      totalQuantity: totalQuantity,
      issuedQty: issuedQty ?? this.issuedQty,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      dateDispatched: dateDispatched,
      items: items,
    );
  }
}

