class CompostBatch {
  final int id;
  final DateTime startDate;
  final DateTime projectedEndDate;
  final String status;
  final DateTime createdAt;

  CompostBatch({
    required this.id,
    required this.startDate,
    required this.projectedEndDate,
    required this.status,
    required this.createdAt,
  });

  factory CompostBatch.fromJson(Map<String, dynamic> json) {
    return CompostBatch(
      id: json['id'] as int,
      startDate: DateTime.parse(json['start_date']),
      projectedEndDate: DateTime.parse(json['projected_end_date']),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String(),
      'projected_end_date': projectedEndDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Calculate progress percentage based on time elapsed
  double getTimeProgress() {
    final now = DateTime.now();
    final totalDuration = projectedEndDate.difference(startDate);
    final elapsed = now.difference(startDate);
    
    if (totalDuration.inDays <= 0) return 100.0;
    final progress = (elapsed.inDays / totalDuration.inDays) * 100;
    return progress.clamp(0.0, 100.0);
  }

  // Get days remaining
  int getDaysRemaining() {
    final now = DateTime.now();
    final remaining = projectedEndDate.difference(now);
    return remaining.inDays > 0 ? remaining.inDays : 0;
  }
}

