class Supplier {
  final String id;
  final String supplierName;
  final String contactNum;
  final String? location;
  final String email; // Required in ERDv8
  final String? notes;
  final String createdBy; // New field in ERDv8

  Supplier({
    required this.id,
    required this.supplierName,
    required this.contactNum,
    this.location,
    required this.email,
    this.notes,
    required this.createdBy, // Added createdBy field
  });

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      supplierName: data['supplierName'] ?? '',
      contactNum: data['contactNum'] ?? '',
      location: data['location'],
      email: data['email'] ?? '', // Still handle legacy data
      notes: data['notes'],
      createdBy: data['createdBy'] ?? 'anonymous', // Handle legacy data
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'contactNum': contactNum,
      'location': location,
      'email': email,
      'notes': notes,
      'createdBy': createdBy, // Added createdBy field
    };
  }
}
