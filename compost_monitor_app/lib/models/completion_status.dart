class CompletionStatus {
  final String status; // "active", "completing", "complete"
  final double completionPercentage;
  final int? estimatedDaysRemaining;

  CompletionStatus({
    required this.status,
    required this.completionPercentage,
    this.estimatedDaysRemaining,
  });

  factory CompletionStatus.fromJson(Map<String, dynamic> json) {
    return CompletionStatus(
      status: json['status'] as String,
      completionPercentage: (json['completion_percentage'] as num).toDouble(),
      estimatedDaysRemaining: json['estimated_days_remaining'] as int?,
    );
  }

  bool get isComplete => status == 'complete';
  bool get isCompleting => status == 'completing';
  bool get isActive => status == 'active';
}

