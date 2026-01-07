import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/cycle_analytics.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CompletedCyclesAnalyticsScreen extends StatefulWidget {
  const CompletedCyclesAnalyticsScreen({super.key});

  @override
  State<CompletedCyclesAnalyticsScreen> createState() => _CompletedCyclesAnalyticsScreenState();
}

class _CompletedCyclesAnalyticsScreenState extends State<CompletedCyclesAnalyticsScreen> {
  CycleAnalytics? _analytics;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getCompletedCyclesAnalytics();
      setState(() {
        _analytics = CycleAnalytics.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Cycles Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading analytics',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _analytics == null
                  ? const Center(child: Text('No analytics data available'))
                  : RefreshIndicator(
                      onRefresh: _loadAnalytics,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Summary Cards
                          _buildSummaryCards(),
                          const SizedBox(height: 24),

                          // Cycles by Month Chart
                          _buildCyclesByMonthChart(),
                          const SizedBox(height: 24),

                          // Temperature Trend Chart
                          _buildTemperatureTrendChart(),
                          const SizedBox(height: 24),

                          // Waste Processed Trend Chart
                          _buildWasteTrendChart(),
                          const SizedBox(height: 24),

                          // Optimization Info
                          _buildOptimizationCard(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Cycles',
                '${_analytics!.totalCompletedCycles}',
                Icons.recycling,
                AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Days',
                '${_analytics!.averageCompostingDays.toStringAsFixed(1)}',
                Icons.calendar_today,
                AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Waste',
                '${_analytics!.totalCompostedWasteKg.toStringAsFixed(1)} kg',
                Icons.scale,
                AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Temp',
                '${_analytics!.averageTemperature.toStringAsFixed(1)}°C',
                Icons.thermostat,
                AppTheme.tempCritical,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyclesByMonthChart() {
    if (_analytics!.cyclesByMonth.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cycles Completed by Month',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _analytics!.cyclesByMonth.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b) + 1,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipBgColor: AppTheme.primaryGreen,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _analytics!.cyclesByMonth.length) return const Text('');
                          final month = _analytics!.cyclesByMonth[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(DateTime.parse('$month-01')),
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _analytics!.cyclesByMonth.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.count.toDouble(),
                          color: AppTheme.primaryGreen,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureTrendChart() {
    if (_analytics!.temperatureTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = _analytics!.temperatureTrend.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.averageTemperature);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Temperature Trend',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _analytics!.temperatureTrend.length) return const Text('');
                          final month = _analytics!.temperatureTrend[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(DateTime.parse('$month-01')),
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}°C',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.tempCritical,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.tempCritical.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteTrendChart() {
    if (_analytics!.wasteProcessedTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = _analytics!.wasteProcessedTrend.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalWasteKg);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waste Processed Trend',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _analytics!.wasteProcessedTrend.length) return const Text('');
                          final month = _analytics!.wasteProcessedTrend[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM').format(DateTime.parse('$month-01')),
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}kg',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.warning,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.warning.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizationCard() {
    return Card(
      color: AppTheme.info.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.info, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Optimization Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_analytics!.optimizationEnabledPercentage.toStringAsFixed(0)}% of time enabled',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Average Humidity: ${_analytics!.averageHumidity.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

