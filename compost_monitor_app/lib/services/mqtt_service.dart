import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';
import '../models/device_status.dart';
import 'config_service.dart';

class MqttService {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
      _updatesSubscription;
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

      _client = MqttServerClient.withPort(host,
          'compost_flutter_${DateTime.now().millisecondsSinceEpoch}', port);
      _client!.logging(on: true); // Enable logging temporarily for debugging
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;

      // Set up message handlers
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;

      // Connect first
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(
              'compost_flutter_${DateTime.now().millisecondsSinceEpoch}')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      // Set up message callback AFTER connection
      print('MqttService: Setting up updates stream listener after connection');
      _updatesSubscription = _client!.updates
          ?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c == null || c.isEmpty) {
          print('MqttService: Received empty or null message list');
          return;
        }
        print('MqttService: Received ${c.length} message(s) in callback');
        for (final message in c) {
          final recMess = message.payload as MqttPublishMessage?;
          if (recMess == null) {
            print('MqttService: Skipping message with null payload');
            continue;
          }
          final topic = message.topic;
          final payload =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          print(
              'MqttService: Processing message on topic: $topic, payload length: ${payload.length}');
          _handleMessage(topic, payload);
        }
      });
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      throw Exception('MQTT connection error: $e');
    }
  }

  void _onConnected() {
    print('MqttService: Connected to broker');
    _isConnected = true;
    _connectionController.add(true);
    _subscribeToTopics();
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onSubscribed(String topic) {
    print('MqttService: Successfully subscribed to topic: $topic');
  }

  void _pong() {
    // Pong received
  }

  void _subscribeToTopics() {
    print('MqttService: Subscribing to topics...');
    // Subscribe to sensor data
    _client!.subscribe('compost/sensor/data', MqttQos.atLeastOnce);
    print('MqttService: Subscribed to compost/sensor/data');

    // Subscribe to device status topics
    _client!.subscribe('compost/status/fan', MqttQos.atLeastOnce);
    _client!.subscribe('compost/status/lid', MqttQos.atLeastOnce);
    _client!.subscribe('compost/status/stirrer', MqttQos.atLeastOnce);
    print('MqttService: Subscribed to status topics (fan, lid, stirrer)');
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

        print('MqttService: Received status update on $topic: $payload');

        // Create DeviceStatus from the message
        // Parse timestamp and convert from UTC to local time (GMT+8)
        final utcTimestamp = DateTime.parse(jsonData['timestamp'] as String);
        final localTimestamp = utcTimestamp.toLocal();
        
        final status = DeviceStatus(
          device: _parseDeviceType(deviceType),
          action: DeviceStatus.parseDeviceAction(jsonData['status'] as String),
          timestamp: localTimestamp,
        );
        print(
            'MqttService: Parsed status - device: ${status.device}, action: ${status.action}');
        _deviceStatusController.add(status);
        print('MqttService: Added status to stream');
      }
    } catch (e, stackTrace) {
      // Log error for debugging
      print('Error handling MQTT message on topic $topic: $e');
      print('Payload: $payload');
      print('Stack trace: $stackTrace');
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
    _updatesSubscription?.cancel();
    disconnect();
    _sensorDataController.close();
    _deviceStatusController.close();
    _connectionController.close();
  }
}
