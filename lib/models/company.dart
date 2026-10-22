class Company {
  final String id;
  final String code;
  final String name;
  final String address;

  Company({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['_id'],
      code: json['code'],
      name: json['name'],
      address: json['address'],
    );
  }
}
