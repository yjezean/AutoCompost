class CycleAnalytics {
  final int totalCompletedCycles;
  final double averageCompostingDays;
  final double totalCompostedWasteKg;
  final double averageTemperature;
  final double averageHumidity;
  final double optimizationEnabledPercentage;
  final List<MonthData> cyclesByMonth;
  final List<TemperatureTrend> temperatureTrend;
  final List<WasteTrend> wasteProcessedTrend;

  CycleAnalytics({
    required this.totalCompletedCycles,
    required this.averageCompostingDays,
    required this.totalCompostedWasteKg,
    required this.averageTemperature,
    required this.averageHumidity,
    required this.optimizationEnabledPercentage,
    required this.cyclesByMonth,
    required this.temperatureTrend,
    required this.wasteProcessedTrend,
  });

  factory CycleAnalytics.fromJson(Map<String, dynamic> json) {
    return CycleAnalytics(
      totalCompletedCycles: json['total_completed_cycles'] as int,
      averageCompostingDays:
          (json['average_composting_days'] as num).toDouble(),
      totalCompostedWasteKg:
          (json['total_composted_waste_kg'] as num).toDouble(),
      averageTemperature: (json['average_temperature'] as num).toDouble(),
      averageHumidity: (json['average_humidity'] as num).toDouble(),
      optimizationEnabledPercentage:
          (json['optimization_enabled_percentage'] as num).toDouble(),
      cyclesByMonth: (json['cycles_by_month'] as List)
          .map((item) => MonthData.fromJson(item as Map<String, dynamic>))
          .toList(),
      temperatureTrend: (json['temperature_trend'] as List)
          .map(
              (item) => TemperatureTrend.fromJson(item as Map<String, dynamic>))
          .toList(),
      wasteProcessedTrend: (json['waste_processed_trend'] as List)
          .map((item) => WasteTrend.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthData {
  final String month;
  final int count;

  MonthData({required this.month, required this.count});

  factory MonthData.fromJson(Map<String, dynamic> json) {
    return MonthData(
      month: json['month'] as String,
      count: json['count'] as int,
    );
  }
}

class TemperatureTrend {
  final String month;
  final double averageTemperature;

  TemperatureTrend({required this.month, required this.averageTemperature});

  factory TemperatureTrend.fromJson(Map<String, dynamic> json) {
    return TemperatureTrend(
      month: json['month'] as String,
      averageTemperature: (json['average_temperature'] as num).toDouble(),
    );
  }
}

class WasteTrend {
  final String month;
  final double totalWasteKg;

  WasteTrend({required this.month, required this.totalWasteKg});

  factory WasteTrend.fromJson(Map<String, dynamic> json) {
    return WasteTrend(
      month: json['month'] as String,
      totalWasteKg: (json['total_waste_kg'] as num).toDouble(),
    );
  }
}
