import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _mqttBrokerKey = 'mqtt_broker_url';
  static const String _apiBaseUrlKey = 'api_base_url';
  
  // Default values
  static const String defaultMqttBroker = 'tcp://34.87.144.95:1883';
  static const String defaultApiBaseUrl = 'http://34.87.144.95:8000/api/v1';

  static Future<String> getMqttBrokerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mqttBrokerKey) ?? defaultMqttBroker;
  }

  static Future<void> setMqttBrokerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttBrokerKey, url);
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiBaseUrlKey) ?? defaultApiBaseUrl;
  }

  static Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, url);
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mqttBrokerKey);
    await prefs.remove(_apiBaseUrlKey);
  }
}

