class Color {
  final String id;
  final String name;
  final String? hexCode;
  final String createdBy;

  Color({
    required this.id,
    required this.name,
    this.hexCode,
    required this.createdBy,
  });

  factory Color.fromMap(String id, Map<String, dynamic> data) {
    return Color(
      id: id,
      name: data['name'] ?? '',
      hexCode: data['hexCode'],
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'hexCode': hexCode,
      'createdBy': createdBy,
    };
  }
}
