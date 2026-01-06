import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_control_provider.dart';
import '../providers/sensor_provider.dart';
import '../models/device_status.dart';
import '../widgets/control_button.dart';
import '../theme/app_theme.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
      ),
      body: Consumer2<DeviceControlProvider, SensorProvider>(
        builder: (context, deviceProvider, sensorProvider, child) {
          // Check if device is offline
          final isOffline = sensorProvider.currentData == null || !sensorProvider.isConnected;
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Offline Indicator Banner
                if (isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.warning.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Offline',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Controls are disabled. Please ensure the device is powered on and connected.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Fan Control
                ControlButton(
                  label: 'Fan Control',
                  icon: Icons.ac_unit,
                  isActive: deviceProvider.isDeviceActive(DeviceType.fan),
                  isLoading: deviceProvider.getCommandState(DeviceType.fan) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleFan(),
                ),

                // Lid Control
                ControlButton(
                  label: 'Lid Control',
                  icon: Icons.unfold_more,
                  isActive: deviceProvider.isDeviceActive(DeviceType.lid),
                  isLoading: deviceProvider.getCommandState(DeviceType.lid) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleLid(),
                ),

                // Stirrer Control
                ControlButton(
                  label: 'Stirrer Control',
                  icon: Icons.settings,
                  isActive: deviceProvider.isDeviceActive(DeviceType.stirrer),
                  isLoading: deviceProvider.getCommandState(DeviceType.stirrer) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleStirrer(),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

