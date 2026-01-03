import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/compost_batch.dart';
import '../models/completion_status.dart';
import 'config_service.dart';

class ApiService {
  static Future<String> getBaseUrl() => ConfigService.getApiBaseUrl();

  // Get historical sensor data
  static Future<List<SensorData>> getSensorData({int days = 7}) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/sensor-data?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final dataList = jsonData['data'] as List;
        return dataList
            .map((item) => SensorData.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load sensor data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching sensor data: $e');
    }
  }

  // Get current compost batch
  static Future<CompostBatch> getCurrentBatch() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/compost-batch/current'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CompostBatch.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('No active batch found');
      } else {
        throw Exception('Failed to load batch: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching batch: $e');
    }
  }

  // Get completion status
  static Future<CompletionStatus> getCompletionStatus({int days = 30}) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/completion-status?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CompletionStatus.fromJson(jsonData);
      } else {
        throw Exception('Failed to load completion status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching completion status: $e');
    }
  }

  // Test API connection
  static Future<bool> testConnection() async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse(baseUrl.replaceAll('/api/v1', '/health'));
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

