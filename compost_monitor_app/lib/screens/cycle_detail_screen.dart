import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cycle_provider.dart';
import '../models/compost_batch.dart';
import '../models/cn_ratio.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cn_ratio_indicator.dart';

class CycleDetailScreen extends StatefulWidget {
  final int cycleId;

  const CycleDetailScreen({
    super.key,
    required this.cycleId,
  });

  @override
  State<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends State<CycleDetailScreen> {
  CompostBatch? _cycle;
  CNRatio? _cnRatio;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadCycle();
  }

  Future<void> _loadCycle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cycle = await ApiService.getCycle(widget.cycleId);
      setState(() {
        _cycle = cycle;
        _error = null;
      });

      // Load C:N ratio if waste amounts are available
      if (cycle.greenWasteKg != null &&
          cycle.brownWasteKg != null &&
          cycle.greenWasteKg! > 0 &&
          cycle.brownWasteKg! > 0) {
        _calculateRatio();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateRatio() async {
    if (_cycle == null ||
        _cycle!.greenWasteKg == null ||
        _cycle!.brownWasteKg == null) {
      return;
    }

    try {
      final ratio = await ApiService.calculateCNRatio(
        widget.cycleId,
        _cycle!.greenWasteKg!,
        _cycle!.brownWasteKg!,
      );
      setState(() {
        _cnRatio = ratio;
      });
    } catch (e) {
      // Error calculating ratio, but don't show error
    }
  }

  Future<void> _updateWasteAmounts(double greenKg, double brownKg) async {
    try {
      final provider = context.read<CycleProvider>();
      await provider.updateCycle(
        widget.cycleId,
        {
          'green_waste_kg': greenKg,
          'brown_waste_kg': brownKg,
        },
      );
      await _loadCycle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waste amounts updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _activateCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Cycle'),
        content: const Text(
          'This will deactivate any currently active cycle. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = context.read<CycleProvider>();
        await provider.activateCycle(widget.cycleId);
        await _loadCycle();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cycle activated successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error activating cycle: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cycle Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _cycle == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cycle Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(
                'Error loading cycle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCycle,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final progress = _cycle!.getTimeProgress();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Details'),
        actions: [
          if (_cycle!.status != 'active')
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Activate',
              onPressed: _activateCycle,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            tooltip: _isEditing ? 'Cancel Edit' : 'Edit',
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCycle,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status and ID
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cycle #${_cycle!.id}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _cycle!.status.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _getStatusColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dates
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context,
                      'Start Date',
                      dateFormat.format(_cycle!.startDate),
                      Icons.calendar_today,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      'Projected End Date',
                      dateFormat.format(_cycle!.projectedEndDate),
                      Icons.event,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      'Duration',
                      '${_cycle!.projectedEndDate.difference(_cycle!.startDate).inDays} days',
                      Icons.schedule,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${progress.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 8,
                        backgroundColor: AppTheme.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(progress),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Waste amounts and C:N ratio
            if (_isEditing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Edit Waste Amounts',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _EditWasteForm(
                        cycleId: widget.cycleId,
                        initialGreenWaste: _cycle!.greenWasteKg,
                        initialBrownWaste: _cycle!.brownWasteKg,
                        onSave: (greenKg, brownKg) async {
                          await _updateWasteAmounts(greenKg, brownKg);
                          if (mounted) {
                            setState(() {
                              _isEditing = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              if (_cycle!.greenWasteKg != null || _cycle!.brownWasteKg != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waste Input',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        if (_cycle!.greenWasteKg != null)
                          _buildWasteRow(
                            context,
                            'Green Waste',
                            _cycle!.greenWasteKg!,
                            AppTheme.success,
                            Icons.eco,
                          ),
                        if (_cycle!.greenWasteKg != null &&
                            _cycle!.brownWasteKg != null)
                          const Divider(),
                        if (_cycle!.brownWasteKg != null)
                          _buildWasteRow(
                            context,
                            'Brown Waste',
                            _cycle!.brownWasteKg!,
                            AppTheme.warning,
                            Icons.forest,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // C:N Ratio indicator
              if (_cnRatio != null) ...[
                CNRatioIndicator(cnRatio: _cnRatio!),
                const SizedBox(height: 16),
              ] else if (_cycle!.cnRatio != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C:N Ratio',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_cycle!.cnRatio!.toStringAsFixed(1)}:1',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: _getCNRatioColor(_cycle!.cnRatio!),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Volume info
            if (_cycle!.initialVolumeLiters != null ||
                _cycle!.totalVolumeLiters != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volume',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      if (_cycle!.initialVolumeLiters != null)
                        _buildInfoRow(
                          context,
                          'Initial Volume',
                          '${_cycle!.initialVolumeLiters!.toStringAsFixed(1)} L',
                          Icons.water_drop,
                        ),
                      if (_cycle!.initialVolumeLiters != null &&
                          _cycle!.totalVolumeLiters != null)
                        const Divider(),
                      if (_cycle!.totalVolumeLiters != null)
                        _buildInfoRow(
                          context,
                          'Current Volume',
                          '${_cycle!.totalVolumeLiters!.toStringAsFixed(1)} L',
                          Icons.water_drop_outlined,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildWasteRow(
    BuildContext context,
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(1)} kg',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_cycle!.status) {
      case 'active':
        return AppTheme.success;
      case 'planning':
        return AppTheme.info;
      case 'completed':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 30) return AppTheme.tempCold;
    if (progress < 70) return AppTheme.primaryGreen;
    if (progress < 90) return AppTheme.tempWarning;
    return AppTheme.tempOptimal;
  }

  Color _getCNRatioColor(double ratio) {
    if (ratio >= 25 && ratio <= 30) return AppTheme.success;
    if (ratio < 25) return AppTheme.warning;
    return AppTheme.info;
  }
}

// Edit form widget with save button
class _EditWasteForm extends StatefulWidget {
  final int? cycleId;
  final double? initialGreenWaste;
  final double? initialBrownWaste;
  final Function(double greenKg, double brownKg) onSave;

  const _EditWasteForm({
    required this.cycleId,
    this.initialGreenWaste,
    this.initialBrownWaste,
    required this.onSave,
  });

  @override
  State<_EditWasteForm> createState() => _EditWasteFormState();
}

class _EditWasteFormState extends State<_EditWasteForm> {
  final _greenController = TextEditingController();
  final _brownController = TextEditingController();
  CNRatio? _cnRatio;
  bool _isCalculating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialGreenWaste != null) {
      _greenController.text = widget.initialGreenWaste!.toStringAsFixed(2);
    }
    if (widget.initialBrownWaste != null) {
      _brownController.text = widget.initialBrownWaste!.toStringAsFixed(2);
    }
    _greenController.addListener(_onInputChanged);
    _brownController.addListener(_onInputChanged);
    // Calculate initial ratio if values exist
    if (widget.initialGreenWaste != null &&
        widget.initialBrownWaste != null &&
        widget.initialGreenWaste! > 0 &&
        widget.initialBrownWaste! > 0 &&
        widget.cycleId != null) {
      _calculateRatio();
    }
  }

  @override
  void dispose() {
    _greenController.dispose();
    _brownController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final greenKg = double.tryParse(_greenController.text) ?? 0.0;
    final brownKg = double.tryParse(_brownController.text) ?? 0.0;

    // Only calculate ratio on input change, don't trigger save
    if (greenKg > 0 && brownKg > 0 && widget.cycleId != null) {
      _calculateRatio();
    } else {
      setState(() {
        _cnRatio = null;
      });
    }
  }

  Future<void> _calculateRatio() async {
    final greenKg = double.tryParse(_greenController.text) ?? 0.0;
    final brownKg = double.tryParse(_brownController.text) ?? 0.0;

    if (greenKg <= 0 || brownKg <= 0 || widget.cycleId == null) {
      return;
    }

    setState(() {
      _isCalculating = true;
      _error = null;
    });

    try {
      final ratio = await ApiService.calculateCNRatio(
        widget.cycleId!,
        greenKg,
        brownKg,
      );
      setState(() {
        _cnRatio = ratio;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cnRatio = null;
      });
    } finally {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Organic waste input
        TextField(
          controller: _greenController,
          decoration: InputDecoration(
            labelText: 'Organic Waste (kg)',
            hintText: 'Enter amount',
            prefixIcon: const Icon(Icons.eco, color: AppTheme.primaryGreen),
            suffixText: 'kg',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        const SizedBox(height: 16),
        
        // Brown waste input
        TextField(
          controller: _brownController,
          decoration: InputDecoration(
            labelText: 'Brown Waste (kg)',
            hintText: 'Enter amount',
            prefixIcon: const Icon(Icons.forest, color: AppTheme.warning),
            suffixText: 'kg',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        
        // C:N Ratio indicator
        if (_cnRatio != null) ...[
          const SizedBox(height: 16),
          CNRatioIndicator(cnRatio: _cnRatio!),
        ],
        
        if (_isCalculating) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
        
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : () async {
              setState(() {
                _isSaving = true;
              });
              try {
                final greenKg = double.tryParse(_greenController.text) ?? 0.0;
                final brownKg = double.tryParse(_brownController.text) ?? 0.0;
                await widget.onSave(greenKg, brownKg);
              } finally {
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

