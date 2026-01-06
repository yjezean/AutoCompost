import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';
import '../models/compost_batch.dart';
import '../models/completion_status.dart';
import '../models/compost_material.dart';
import '../models/cn_ratio.dart';
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

  // Phase 2: Cycle Management Endpoints (stub implementations)

  // Get all cycles
  static Future<List<CompostBatch>> getCycles() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cycles'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as List;
        return jsonData
            .map((item) => CompostBatch.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load cycles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching cycles: $e');
    }
  }

  // Get cycle by ID
  static Future<CompostBatch> getCycle(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cycles/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CompostBatch.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('Cycle not found');
      } else {
        throw Exception('Failed to load cycle: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching cycle: $e');
    }
  }

  // Create new cycle
  static Future<CompostBatch> createCycle(Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/cycles'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CompostBatch.fromJson(jsonData);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to create cycle: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating cycle: $e');
    }
  }

  // Update cycle
  static Future<CompostBatch> updateCycle(int id, Map<String, dynamic> data) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/cycles/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CompostBatch.fromJson(jsonData);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to update cycle: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating cycle: $e');
    }
  }

  // Activate cycle
  static Future<void> activateCycle(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/cycles/$id/activate'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to activate cycle: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error activating cycle: $e');
    }
  }

  // Calculate C:N ratio
  static Future<CNRatio> calculateCNRatio(int cycleId, double greenKg, double brownKg) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/cycles/$cycleId/calculate-ratio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'green_waste_kg': greenKg,
          'brown_waste_kg': brownKg,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return CNRatio.fromJson(jsonData);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to calculate ratio: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error calculating C:N ratio: $e');
    }
  }

  // Get cycle progress
  static Future<Map<String, dynamic>> getCycleProgress(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cycles/$id/progress'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load progress: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching progress: $e');
    }
  }

  // Get compost materials
  static Future<List<CompostMaterial>> getMaterials() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/materials'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as List;
        return jsonData
            .map((item) => CompostMaterial.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load materials: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching materials: $e');
    }
  }

  // Optimization Settings Endpoints

  // Get optimization status
  static Future<bool> getOptimizationStatus() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/optimization/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return jsonData['enabled'] as bool;
      } else {
        throw Exception('Failed to load optimization status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching optimization status: $e');
    }
  }

  // Set optimization status
  static Future<bool> setOptimizationStatus(bool enabled) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/optimization/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'enabled': enabled}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return jsonData['enabled'] as bool;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to update optimization status: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating optimization status: $e');
    }
  }
}

