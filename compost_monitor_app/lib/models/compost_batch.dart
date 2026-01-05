class CompostBatch {
  final int id;
  final DateTime startDate;
  final DateTime projectedEndDate;
  final String status;
  final DateTime createdAt;
  // Phase 2 fields (optional)
  final double? greenWasteKg;
  final double? brownWasteKg;
  final double? totalVolumeLiters;
  final double? cnRatio;
  final double? initialVolumeLiters;

  CompostBatch({
    required this.id,
    required this.startDate,
    required this.projectedEndDate,
    required this.status,
    required this.createdAt,
    this.greenWasteKg,
    this.brownWasteKg,
    this.totalVolumeLiters,
    this.cnRatio,
    this.initialVolumeLiters,
  });

  factory CompostBatch.fromJson(Map<String, dynamic> json) {
    return CompostBatch(
      id: json['id'] as int,
      startDate: DateTime.parse(json['start_date']),
      projectedEndDate: DateTime.parse(json['projected_end_date']),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      greenWasteKg: json['green_waste_kg'] != null 
          ? (json['green_waste_kg'] as num).toDouble() 
          : null,
      brownWasteKg: json['brown_waste_kg'] != null 
          ? (json['brown_waste_kg'] as num).toDouble() 
          : null,
      totalVolumeLiters: json['total_volume_liters'] != null 
          ? (json['total_volume_liters'] as num).toDouble() 
          : null,
      cnRatio: json['cn_ratio'] != null 
          ? (json['cn_ratio'] as num).toDouble() 
          : null,
      initialVolumeLiters: json['initial_volume_liters'] != null 
          ? (json['initial_volume_liters'] as num).toDouble() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String(),
      'projected_end_date': projectedEndDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'green_waste_kg': greenWasteKg,
      'brown_waste_kg': brownWasteKg,
      'total_volume_liters': totalVolumeLiters,
      'cn_ratio': cnRatio,
      'initial_volume_liters': initialVolumeLiters,
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

