import 'package:flutter/foundation.dart';
import '../models/compost_batch.dart';
import '../services/api_service.dart';

class CycleProvider with ChangeNotifier {
  List<CompostBatch> _cycles = [];
  CompostBatch? _activeCycle;
  bool _isLoading = false;
  String? _error;

  List<CompostBatch> get cycles => _cycles;
  CompostBatch? get activeCycle => _activeCycle;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get cycles by status
  List<CompostBatch> getCyclesByStatus(String status) {
    return _cycles.where((cycle) => cycle.status == status).toList();
  }

  // Get planning cycles
  List<CompostBatch> get planningCycles => getCyclesByStatus('planning');

  // Get active cycles
  List<CompostBatch> get activeCycles => getCyclesByStatus('active');

  // Get completed cycles
  List<CompostBatch> get completedCycles => getCyclesByStatus('completed');

  // Get archived cycles
  List<CompostBatch> get archivedCycles => getCyclesByStatus('archived');

  Future<void> fetchCycles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cycles = await ApiService.getCycles();
      _cycles = cycles;
      
      // Find active cycle
      if (cycles.isEmpty) {
        _activeCycle = null;
      } else {
        _activeCycle = cycles.firstWhere(
          (cycle) => cycle.status == 'active',
          orElse: () => cycles.firstWhere(
            (cycle) => cycle.status == 'planning',
            orElse: () => cycles.first,
          ),
        );
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _cycles = [];
      _activeCycle = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCycle(CompostBatch cycle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cycleData = {
        'start_date': cycle.startDate.toIso8601String(),
        if (cycle.projectedEndDate != null) 'projected_end_date': cycle.projectedEndDate.toIso8601String(),
        'status': cycle.status,
        if (cycle.greenWasteKg != null) 'green_waste_kg': cycle.greenWasteKg,
        if (cycle.brownWasteKg != null) 'brown_waste_kg': cycle.brownWasteKg,
        if (cycle.initialVolumeLiters != null) 'initial_volume_liters': cycle.initialVolumeLiters,
      };

      final createdCycle = await ApiService.createCycle(cycleData);
      _cycles.add(createdCycle);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> activateCycle(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.activateCycle(id);
      
      // Update cycle status locally
      for (var i = 0; i < _cycles.length; i++) {
        if (_cycles[i].id == id) {
          _cycles[i] = CompostBatch(
            id: _cycles[i].id,
            startDate: _cycles[i].startDate,
            projectedEndDate: _cycles[i].projectedEndDate,
            status: 'active',
            createdAt: _cycles[i].createdAt,
            greenWasteKg: _cycles[i].greenWasteKg,
            brownWasteKg: _cycles[i].brownWasteKg,
            totalVolumeLiters: _cycles[i].totalVolumeLiters,
            cnRatio: _cycles[i].cnRatio,
            initialVolumeLiters: _cycles[i].initialVolumeLiters,
          );
          _activeCycle = _cycles[i];
        } else if (_cycles[i].status == 'active') {
          // Deactivate other active cycles
          _cycles[i] = CompostBatch(
            id: _cycles[i].id,
            startDate: _cycles[i].startDate,
            projectedEndDate: _cycles[i].projectedEndDate,
            status: 'completed',
            createdAt: _cycles[i].createdAt,
            greenWasteKg: _cycles[i].greenWasteKg,
            brownWasteKg: _cycles[i].brownWasteKg,
            totalVolumeLiters: _cycles[i].totalVolumeLiters,
            cnRatio: _cycles[i].cnRatio,
            initialVolumeLiters: _cycles[i].initialVolumeLiters,
          );
        }
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCycle(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCycle = await ApiService.updateCycle(id, data);
      
      // Update cycle in list
      final index = _cycles.indexWhere((cycle) => cycle.id == id);
      if (index != -1) {
        _cycles[index] = updatedCycle;
        if (_activeCycle?.id == id) {
          _activeCycle = updatedCycle;
        }
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setActiveCycle(CompostBatch? cycle) {
    _activeCycle = cycle;
    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchCycles();
  }
}

