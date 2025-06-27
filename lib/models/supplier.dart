class Supplier {
  final String id;
  final String supplierName;
  final String contactNum;
  final String? location;

  Supplier({
    required this.id,
    required this.supplierName,
    required this.contactNum,
    this.location,
  });

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      supplierName: data['supplierName'] ?? '',
      contactNum: data['contactNum'] ?? '',
      location: data['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'contactNum': contactNum,
      'location': location,
    };
  }
}
