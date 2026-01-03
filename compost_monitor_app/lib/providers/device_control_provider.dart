import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/device_status.dart';
import '../services/mqtt_service.dart';

enum DeviceCommandState {
  idle,
  sending,
  success,
  error,
}

class DeviceControlProvider with ChangeNotifier {
  final MqttService _mqttService;
  StreamSubscription<DeviceStatus>? _statusSubscription;

  final Map<DeviceType, DeviceAction> _deviceStates = {
    DeviceType.fan: DeviceAction.off,
    DeviceType.lid: DeviceAction.close,
    DeviceType.stirrer: DeviceAction.stopped,
  };

  final Map<DeviceType, DeviceCommandState> _commandStates = {
    DeviceType.fan: DeviceCommandState.idle,
    DeviceType.lid: DeviceCommandState.idle,
    DeviceType.stirrer: DeviceCommandState.idle,
  };

  DeviceControlProvider(this._mqttService) {
    _initialize();
  }

  void _initialize() {
    // Listen to device status updates
    _statusSubscription = _mqttService.deviceStatusStream.listen(
      (status) {
        _deviceStates[status.device] = status.action;
        notifyListeners();
      },
    );
  }

  DeviceAction getDeviceState(DeviceType device) {
    return _deviceStates[device] ?? DeviceAction.off;
  }

  DeviceCommandState getCommandState(DeviceType device) {
    return _commandStates[device] ?? DeviceCommandState.idle;
  }

  bool isDeviceActive(DeviceType device) {
    final action = getDeviceState(device);
    switch (device) {
      case DeviceType.fan:
        return action == DeviceAction.on;
      case DeviceType.lid:
        return action == DeviceAction.open;
      case DeviceType.stirrer:
        return action == DeviceAction.running || action == DeviceAction.start;
    }
  }

  Future<void> sendCommand(DeviceType device, String action) async {
    if (!_mqttService.isConnected) {
      _commandStates[device] = DeviceCommandState.error;
      notifyListeners();
      return;
    }

    _commandStates[device] = DeviceCommandState.sending;
    notifyListeners();

    try {
      final deviceName = device.name; // 'fan', 'lid', 'stirrer'
      await _mqttService.publishCommand(deviceName, action);
      
      // Wait a bit for status update
      await Future.delayed(const Duration(milliseconds: 500));
      
      _commandStates[device] = DeviceCommandState.success;
      notifyListeners();
      
      // Reset to idle after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        _commandStates[device] = DeviceCommandState.idle;
        notifyListeners();
      });
    } catch (e) {
      _commandStates[device] = DeviceCommandState.error;
      notifyListeners();
      
      // Reset to idle after error
      Future.delayed(const Duration(seconds: 2), () {
        _commandStates[device] = DeviceCommandState.idle;
        notifyListeners();
      });
    }
  }

  Future<void> toggleFan() async {
    final isOn = _deviceStates[DeviceType.fan] == DeviceAction.on;
    await sendCommand(DeviceType.fan, isOn ? 'OFF' : 'ON');
  }

  Future<void> toggleLid() async {
    final isOpen = _deviceStates[DeviceType.lid] == DeviceAction.open;
    await sendCommand(DeviceType.lid, isOpen ? 'CLOSE' : 'OPEN');
  }

  Future<void> toggleStirrer() async {
    final isRunning = _deviceStates[DeviceType.stirrer] == DeviceAction.running ||
        _deviceStates[DeviceType.stirrer] == DeviceAction.start;
    await sendCommand(DeviceType.stirrer, isRunning ? 'STOP' : 'START');
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

