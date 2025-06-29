class Supplier {
  final String id;
  final String supplierName;
  final String contactNum;
  final String? location;
  final String email;
  final String? notes;

  Supplier({
    required this.id,
    required this.supplierName,
    required this.contactNum,
    this.location,
    required this.email,
    this.notes,
  });

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      supplierName: data['supplierName'] ?? '',
      contactNum: data['contactNum'] ?? '',
      location: data['location'],
      email: data['email'] ?? '',
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'contactNum': contactNum,
      'location': location,
      'email': email,
      'notes': notes,
    };
  }
}
