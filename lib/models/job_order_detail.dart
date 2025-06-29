class JobOrderDetail {
  final String id;
  final String jobOrderID;
  final String fabricID;
  final double yardageUsed;
  final String size;
  final String color;
  final String? notes;

  JobOrderDetail({
    required this.id,
    required this.jobOrderID,
    required this.fabricID,
    required this.yardageUsed,
    required this.size,
    required this.color,
    this.notes,
  });

  factory JobOrderDetail.fromMap(String id, Map<String, dynamic> data) {
    return JobOrderDetail(
      id: id,
      jobOrderID: data['jobOrderID'] ?? '',
      fabricID: data['fabricID'] ?? '',
      yardageUsed: (data['yardageUsed'] ?? 0).toDouble(),
      size: data['size'] ?? '',
      color: data['color'] ?? '',
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobOrderID': jobOrderID,
      'fabricID': fabricID,
      'yardageUsed': yardageUsed,
      'size': size,
      'color': color,
      'notes': notes,
    };
  }
}
