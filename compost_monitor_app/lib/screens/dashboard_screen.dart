import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sensor_provider.dart';
import '../providers/compost_batch_provider.dart';
import '../widgets/temperature_gauge.dart';
import '../widgets/humidity_gauge.dart';
import '../widgets/batch_info_card.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compost Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings - will be handled by main navigation
            },
          ),
        ],
      ),
      body: Consumer2<SensorProvider, CompostBatchProvider>(
        builder: (context, sensorProvider, batchProvider, child) {
          final sensorData = sensorProvider.currentData;
          final batch = batchProvider.currentBatch;
          final completionStatus = batchProvider.completionStatus;
          final combinedProgress = batchProvider.getCombinedProgress();

          return RefreshIndicator(
            onRefresh: () async {
              await batchProvider.refresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: sensorProvider.isConnected
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.error.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sensorProvider.isConnected
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sensorProvider.isConnected
                              ? 'Connected'
                              : 'Disconnected',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: sensorProvider.isConnected
                                    ? AppTheme.success
                                    : AppTheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (sensorProvider.lastUpdate != null) ...[
                          const SizedBox(width: 16),
                          Text(
                            'Last: ${DateFormat('HH:mm:ss').format(sensorProvider.lastUpdate!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Gauges
                  if (sensorData != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TemperatureGauge(
                            temperature: sensorData.temperature,
                          ),
                        ),
                        Expanded(
                          child: HumidityGauge(
                            humidity: sensorData.humidity,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 200),
                    const Center(
                      child: Text('Waiting for sensor data...'),
                    ),
                  ],

                  // Batch Info Card
                  BatchInfoCard(
                    batch: batch,
                    completionStatus: completionStatus,
                    combinedProgress: combinedProgress,
                  ),

                  // Device Status Overview
                  if (sensorData != null) ...[
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Status',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            _buildStatusRow(context, 'Fan', 'OFF'), // Will be connected to device control provider
                            _buildStatusRow(context, 'Lid', 'CLOSED'),
                            _buildStatusRow(context, 'Stirrer', 'STOPPED'),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String device, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            device,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

