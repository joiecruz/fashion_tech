class VariantFabric {
  final String fabricId;
  final String fabricName;
  final double yardsRequired;

  VariantFabric({
    required this.fabricId,
    required this.fabricName,
    required this.yardsRequired,
  });

  factory VariantFabric.fromMap(Map<String, dynamic> data) {
    return VariantFabric(
      fabricId: data['fabricId'] ?? '',
      fabricName: data['fabricName'] ?? '',
      yardsRequired: (data['yardsRequired'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fabricId': fabricId,
      'fabricName': fabricName,
      'yardsRequired': yardsRequired,
    };
  }
}
