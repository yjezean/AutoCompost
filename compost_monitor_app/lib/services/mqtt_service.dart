import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';
import '../models/device_status.dart';
import 'config_service.dart';

class MqttService {
  MqttServerClient? _client;
  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<DeviceStatus> _deviceStatusController =
      StreamController<DeviceStatus>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;

  // Streams
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<DeviceStatus> get deviceStatusStream => _deviceStatusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      final brokerUrl = await ConfigService.getMqttBrokerUrl();
      
      // Parse URL (format: tcp://host:port)
      final uri = Uri.parse(brokerUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 1883;

      _client = MqttServerClient.withPort(host, 'compost_flutter_${DateTime.now().millisecondsSinceEpoch}', port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;

      // Set up message handlers
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;

      // Set up message callback
      _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final topic = c[0].topic;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        _handleMessage(topic, payload);
      });

      // Connect
      final connMessage = MqttConnectMessage()
          .withClientIdentifier('compost_flutter_${DateTime.now().millisecondsSinceEpoch}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      throw Exception('MQTT connection error: $e');
    }
  }

  void _onConnected() {
    _isConnected = true;
    _connectionController.add(true);
    _subscribeToTopics();
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onSubscribed(String topic) {
    // Subscription successful
  }

  void _pong() {
    // Pong received
  }

  void _subscribeToTopics() {
    // Subscribe to sensor data
    _client!.subscribe('compost/sensor/data', MqttQos.atLeastOnce);
    
    // Subscribe to device status topics
    _client!.subscribe('compost/status/fan', MqttQos.atLeastOnce);
    _client!.subscribe('compost/status/lid', MqttQos.atLeastOnce);
    _client!.subscribe('compost/status/stirrer', MqttQos.atLeastOnce);
  }

  void _handleMessage(String topic, String payload) {
    try {
      if (topic == 'compost/sensor/data') {
        final jsonData = json.decode(payload) as Map<String, dynamic>;
        final sensorData = SensorData.fromJson(jsonData);
        _sensorDataController.add(sensorData);
      } else if (topic.startsWith('compost/status/')) {
        final deviceType = topic.split('/').last; // 'fan', 'lid', or 'stirrer'
        final jsonData = json.decode(payload) as Map<String, dynamic>;
        
        // Create DeviceStatus from the message
        final status = DeviceStatus(
          device: _parseDeviceType(deviceType),
          action: DeviceStatus.parseDeviceAction(jsonData['status'] as String),
          timestamp: DateTime.parse(jsonData['timestamp']),
        );
        _deviceStatusController.add(status);
      }
    } catch (e) {
      // Error parsing message, ignore
    }
  }

  DeviceType _parseDeviceType(String device) {
    switch (device.toLowerCase()) {
      case 'fan':
        return DeviceType.fan;
      case 'lid':
        return DeviceType.lid;
      case 'stirrer':
        return DeviceType.stirrer;
      default:
        return DeviceType.fan;
    }
  }

  // Publish command to device
  Future<void> publishCommand(String device, String action) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT not connected');
    }

    try {
      final topic = 'compost/cmd/$device';
      final payload = json.encode({'action': action.toUpperCase()});
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      throw Exception('Error publishing command: $e');
    }
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _sensorDataController.close();
    _deviceStatusController.close();
    _connectionController.close();
  }
}

