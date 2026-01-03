import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_control_provider.dart';
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
      body: Consumer<DeviceControlProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Fan Control
                ControlButton(
                  label: 'Fan Control',
                  icon: Icons.ac_unit,
                  isActive: provider.isDeviceActive(DeviceType.fan),
                  isLoading: provider.getCommandState(DeviceType.fan) ==
                      DeviceCommandState.sending,
                  onPressed: () => provider.toggleFan(),
                ),

                // Lid Control
                ControlButton(
                  label: 'Lid Control',
                  icon: Icons.unfold_more,
                  isActive: provider.isDeviceActive(DeviceType.lid),
                  isLoading: provider.getCommandState(DeviceType.lid) ==
                      DeviceCommandState.sending,
                  onPressed: () => provider.toggleLid(),
                ),

                // Stirrer Control
                ControlButton(
                  label: 'Stirrer Control',
                  icon: Icons.settings,
                  isActive: provider.isDeviceActive(DeviceType.stirrer),
                  isLoading: provider.getCommandState(DeviceType.stirrer) ==
                      DeviceCommandState.sending,
                  onPressed: () => provider.toggleStirrer(),
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

