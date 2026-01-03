import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/chart_data_provider.dart';
import '../widgets/temperature_chart_widget.dart';
import '../widgets/humidity_chart_widget.dart';
import '../theme/app_theme.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChartDataProvider>(context, listen: false);
      provider.fetchData();
      // Set up auto-refresh every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        provider.fetchData();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Data'),
        actions: [
          Consumer<ChartDataProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed:
                    provider.isLoading ? null : () => provider.fetchData(),
                tooltip: 'Refresh data',
              );
            },
          ),
        ],
      ),
      body: Consumer<ChartDataProvider>(
        builder: (context, provider, child) {
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      provider.error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Time Range Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeRangeButton(
                      context,
                      '1 Day',
                      1,
                      provider.selectedDays == 1,
                      provider,
                    ),
                    _buildTimeRangeButton(
                      context,
                      '7 Days',
                      7,
                      provider.selectedDays == 7,
                      provider,
                    ),
                    _buildTimeRangeButton(
                      context,
                      '30 Days',
                      30,
                      provider.selectedDays == 30,
                      provider,
                    ),
                  ],
                ),
              ),
              // Last Fetched Timestamp
              if (provider.lastFetched != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last updated: ${DateFormat('MM/dd HH:mm:ss').format(provider.lastFetched!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Charts - Temperature
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.thermostat,
                                color: AppTheme.tempCritical, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Temperature',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.tempCritical,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      TemperatureChartWidget(
                        data: provider.data,
                        isLoading: provider.isLoading,
                      ),
                      const SizedBox(height: 16),
                      // Charts - Humidity
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.water_drop,
                                color: AppTheme.humHigh, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Humidity',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.humHigh,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      HumidityChartWidget(
                        data: provider.data,
                        isLoading: provider.isLoading,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeButton(
    BuildContext context,
    String label,
    int days,
    bool isSelected,
    ChartDataProvider provider,
  ) {
    return ElevatedButton(
      onPressed: () => provider.setSelectedDays(days),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
        foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
