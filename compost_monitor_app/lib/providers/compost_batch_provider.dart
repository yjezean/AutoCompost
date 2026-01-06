import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/compost_batch.dart';
import '../models/completion_status.dart';
import '../services/api_service.dart';

class CompostBatchProvider with ChangeNotifier {
  CompostBatch? _currentBatch;
  CompletionStatus? _completionStatus;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  CompostBatch? get currentBatch => _currentBatch;
  CompletionStatus? get completionStatus => _completionStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CompostBatchProvider() {
    _startPeriodicRefresh();
    // Fetch immediately on initialization
    fetchBatch();
    fetchCompletionStatus();
  }

  void _startPeriodicRefresh() {
    // Refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      fetchBatch();
      fetchCompletionStatus();
    });
  }

  Future<void> fetchBatch() async {
    try {
      final batch = await ApiService.getCurrentBatch();
      _currentBatch = batch;
      _error = null;
      notifyListeners();
    } catch (e) {
      // Only set error if we don't have existing batch data
      // This allows batch info to persist even if device is temporarily offline
      if (_currentBatch == null) {
        _error = e.toString();
      }
      // Don't clear existing batch on error - keep showing last known batch
      notifyListeners();
    }
  }

  Future<void> fetchCompletionStatus() async {
    try {
      final status = await ApiService.getCompletionStatus();
      _completionStatus = status;
      notifyListeners();
    } catch (e) {
      // Don't set error for completion status, it's optional
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      fetchBatch(),
      fetchCompletionStatus(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  double getCombinedProgress() {
    if (_currentBatch == null) return 0.0;
    
    final timeProgress = _currentBatch!.getTimeProgress();
    final analyticsProgress = _completionStatus?.completionPercentage ?? 0.0;
    
    // Weighted combination: 60% time, 40% analytics
    return (timeProgress * 0.6) + (analyticsProgress * 0.4);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

