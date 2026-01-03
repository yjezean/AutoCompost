import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final MqttService mqttService;

  const SettingsScreen({
    super.key,
    required this.mqttService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _mqttController = TextEditingController();
  final _apiController = TextEditingController();
  bool _isTesting = false;
  bool _mqttConnected = false;
  bool _apiConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mqttUrl = await ConfigService.getMqttBrokerUrl();
    final apiUrl = await ConfigService.getApiBaseUrl();
    
    setState(() {
      _mqttController.text = mqttUrl;
      _apiController.text = apiUrl;
    });
  }

  Future<void> _testConnections() async {
    setState(() {
      _isTesting = true;
      _mqttConnected = false;
      _apiConnected = false;
    });

    // Test API
    try {
      final apiOk = await ApiService.testConnection();
      setState(() {
        _apiConnected = apiOk;
      });
    } catch (e) {
      setState(() {
        _apiConnected = false;
      });
    }

    // Test MQTT (check if service is connected)
    setState(() {
      _mqttConnected = widget.mqttService.isConnected;
    });

    setState(() {
      _isTesting = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mqttConnected && _apiConnected
                ? 'All connections successful!'
                : 'Some connections failed. Check your settings.',
          ),
          backgroundColor: _mqttConnected && _apiConnected
              ? AppTheme.success
              : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    await ConfigService.setMqttBrokerUrl(_mqttController.text);
    await ConfigService.setApiBaseUrl(_apiController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _mqttController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Settings Section
          Text(
            'Connection Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),

          // MQTT Broker URL
          TextField(
            controller: _mqttController,
            decoration: const InputDecoration(
              labelText: 'MQTT Broker URL',
              hintText: 'tcp://your-server:1883',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // API Base URL
          TextField(
            controller: _apiController,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'http://your-server:8000/api/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Test Connections Button
          ElevatedButton.icon(
            onPressed: _isTesting ? null : _testConnections,
            icon: _isTesting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi),
            label: const Text('Test Connections'),
          ),
          const SizedBox(height: 16),

          // Connection Status
          if (_isTesting || _mqttConnected || _apiConnected) ...[
            Card(
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow('MQTT Broker', _mqttConnected),
                    _buildStatusRow('API Server', _apiConnected),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compost Monitor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool connected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: connected ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: connected ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

