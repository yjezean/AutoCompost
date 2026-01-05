class CNRatio {
  final double currentRatio;
  final double optimalRatio;
  final double greenWasteKg;
  final double brownWasteKg;
  final double? suggestedBrownKg;
  final String status; // 'optimal', 'too_much_green', 'too_much_brown'

  CNRatio({
    required this.currentRatio,
    required this.optimalRatio,
    required this.greenWasteKg,
    required this.brownWasteKg,
    this.suggestedBrownKg,
    required this.status,
  });

  factory CNRatio.fromJson(Map<String, dynamic> json) {
    return CNRatio(
      currentRatio: (json['current_ratio'] as num).toDouble(),
      optimalRatio: (json['optimal_ratio'] as num).toDouble(),
      greenWasteKg: (json['green_waste_kg'] as num).toDouble(),
      brownWasteKg: (json['brown_waste_kg'] as num).toDouble(),
      suggestedBrownKg: json['suggested_brown_kg'] != null
          ? (json['suggested_brown_kg'] as num).toDouble()
          : null,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_ratio': currentRatio,
      'optimal_ratio': optimalRatio,
      'green_waste_kg': greenWasteKg,
      'brown_waste_kg': brownWasteKg,
      'suggested_brown_kg': suggestedBrownKg,
      'status': status,
    };
  }

  bool get isOptimal => status == 'optimal';
  bool get needsMoreBrown => status == 'too_much_green';
  bool get needsMoreGreen => status == 'too_much_brown';
}

