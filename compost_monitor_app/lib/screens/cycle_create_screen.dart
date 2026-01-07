import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cycle_provider.dart';
import '../models/compost_batch.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _greenController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _projectedEndDate;
  double _organicWasteKg = 0.0;
  double? _initialVolumeLiters;
  double? _suggestedBrownKg;
  bool _isCreating = false;
  bool _isPreviewing = false;
  bool _hasPreviewed = false;
  static const double MAX_ORGANIC_WASTE_KG = 1.0;
  
  // Density constants (kg per liter)
  static const double ORGANIC_WASTE_DENSITY = 0.5; // Kitchen scraps: ~0.5 kg/L
  static const double BROWN_WASTE_DENSITY = 0.1; // Dry leaves: ~0.1 kg/L

  @override
  void initState() {
    super.initState();
    _greenController.addListener(_calculateAll);
    _calculateAll();
  }

  @override
  void dispose() {
    _greenController.dispose();
    super.dispose();
  }

  void _calculateAll() {
    // Get organic waste input
    final organicKg = double.tryParse(_greenController.text) ?? 0.0;
    
    // Auto-calculate values immediately when user enters organic waste
    // This provides instant feedback, but user can also use Preview button for API calculation
    double? calculatedBrownKg;
    if (organicKg > 0) {
      // Formula: B = G * (27.5 - 20) / (60 - 27.5) ≈ G * 0.231
      calculatedBrownKg = organicKg * 0.231;
    }
    
    // Calculate volumes
    final organicVolume = organicKg > 0 ? organicKg / ORGANIC_WASTE_DENSITY : 0.0;
    final brownVolume = calculatedBrownKg != null && calculatedBrownKg > 0 
        ? calculatedBrownKg / BROWN_WASTE_DENSITY 
        : 0.0;
    final totalVolume = organicVolume + brownVolume;
    
    // Calculate projected end date
    DateTime? calculatedEndDate;
    if (totalVolume > 0) {
      final baseDays = 21;
      final additionalDays = (totalVolume / 5.0).ceil();
      final totalDays = (baseDays + additionalDays).clamp(21, 90);
      calculatedEndDate = _startDate.add(Duration(days: totalDays));
    } else {
      calculatedEndDate = _startDate.add(const Duration(days: 21));
    }
    
    setState(() {
      _organicWasteKg = organicKg;
      _suggestedBrownKg = calculatedBrownKg;
      _initialVolumeLiters = totalVolume > 0 ? totalVolume : null;
      _projectedEndDate = calculatedEndDate;
      // Reset preview flag when user changes input
      if (organicKg == 0) {
        _hasPreviewed = false;
      }
    });
  }

  Future<void> _previewCycle() async {
    final greenKg = double.tryParse(_greenController.text) ?? 0.0;
    
    if (greenKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter organic waste amount first'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isPreviewing = true;
    });

    try {
      final preview = await ApiService.previewCycle(greenKg, _startDate);
      
      setState(() {
        _suggestedBrownKg = (preview['brown_waste_kg'] as num).toDouble();
        _initialVolumeLiters = (preview['total_volume_liters'] as num).toDouble();
        _projectedEndDate = DateTime.parse(preview['projected_end_date'] as String);
        _organicWasteKg = greenKg;
        _hasPreviewed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview calculated successfully'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating preview: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewing = false;
        });
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_projectedEndDate ?? _startDate.add(const Duration(days: 21))),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _calculateAll();
        } else {
          _projectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _createCycle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isCreating = true;
    });

    try {
      final cycle = CompostBatch(
        id: 0, // Will be set by backend
        startDate: _startDate,
        projectedEndDate: _projectedEndDate ?? _startDate.add(const Duration(days: 21)),
        status: 'planning',
        createdAt: DateTime.now(),
        greenWasteKg: _organicWasteKg > 0 ? _organicWasteKg : null,
        brownWasteKg: _suggestedBrownKg != null && _suggestedBrownKg! > 0 ? _suggestedBrownKg : null,
        initialVolumeLiters: _initialVolumeLiters,
      );

      final provider = context.read<CycleProvider>();
      await provider.createCycle(cycle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle created successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating cycle: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Cycle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Help Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showHowToUseDialog(context),
                  icon: const Icon(Icons.help_outline, color: AppTheme.primaryGreen),
                  label: Text(
                    'How to Use',
                    style: TextStyle(color: AppTheme.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Start date
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryGreen),
                title: const Text('Start Date'),
                subtitle: Text(dateFormat.format(_startDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(height: 16),

            // Projected end date (read-only, calculated)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: AppTheme.primaryGreen),
                title: const Text('Projected End Date'),
                subtitle: Text(
                  _projectedEndDate != null
                      ? dateFormat.format(_projectedEndDate!)
                      : 'Calculating...',
                ),
                trailing: const Icon(Icons.auto_awesome, color: AppTheme.info),
              ),
            ),
            const SizedBox(height: 16),

            // Duration info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _projectedEndDate != null
                          ? 'Duration: ${_projectedEndDate!.difference(_startDate).inDays} days (calculated from volume)'
                          : 'Duration: Calculating...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Organic waste input
            TextFormField(
              controller: _greenController,
              decoration: InputDecoration(
                labelText: 'Organic Waste (kg)',
                hintText: 'Enter weight (max ${MAX_ORGANIC_WASTE_KG} kg)',
                prefixIcon: const Icon(Icons.eco, color: AppTheme.primaryGreen),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                  onPressed: () => _showOrganicWasteDialog(context),
                  tooltip: 'What is Organic Waste?',
                ),
                suffixText: 'kg',
                border: const OutlineInputBorder(),
                helperText: 'Food waste from kitchen',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null; // Optional field
                }
                final weight = double.tryParse(value);
                if (weight == null || weight < 0) {
                  return 'Please enter a valid weight';
                }
                if (weight > MAX_ORGANIC_WASTE_KG) {
                  return 'Maximum ${MAX_ORGANIC_WASTE_KG} kg allowed';
                }
                return null;
              },
              onSaved: (value) {
                _organicWasteKg = value != null && value.isNotEmpty
                    ? (double.tryParse(value) ?? 0.0)
                    : 0.0;
              },
            ),
            const SizedBox(height: 16),

            // Preview button
            if (_organicWasteKg > 0) ...[
              OutlinedButton.icon(
                onPressed: _isPreviewing ? null : _previewCycle,
                icon: _isPreviewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_hasPreviewed ? Icons.refresh : Icons.preview),
                label: Text(_isPreviewing 
                    ? 'Calculating...' 
                    : (_hasPreviewed ? 'Recalculate' : 'Preview Calculations')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Brown waste display (auto-calculated, read-only)
            if (_suggestedBrownKg != null && _suggestedBrownKg! > 0) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.warning.withOpacity(0.15),
                      AppTheme.warning.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warning.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warning.withOpacity(0.3),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.forest,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Required Brown Waste',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warning,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_suggestedBrownKg!.toStringAsFixed(3)}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.warning,
                                        fontSize: 22,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'kg',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-calculated to balance C:N ratio',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                        onPressed: () => _showBrownWasteDialog(context),
                        tooltip: 'What is Brown Waste?',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),

            // Calculated Volume Display
            if (_initialVolumeLiters != null && _initialVolumeLiters! > 0) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.info.withOpacity(0.15),
                      AppTheme.info.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.info.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.info.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.info,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.info.withOpacity(0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.water_drop,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Total Volume: ',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.info,
                                      ),
                                ),
                                Text(
                                  '${_initialVolumeLiters!.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.info,
                                        fontSize: 22,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'L',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.info,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_suggestedBrownKg != null && _suggestedBrownKg! > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildVolumeBreakdown(
                                  context,
                                  'Organic',
                                  '${(_organicWasteKg / ORGANIC_WASTE_DENSITY).toStringAsFixed(2)} L',
                                  AppTheme.primaryGreen,
                                  Icons.eco,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 24,
                                color: AppTheme.divider,
                              ),
                              Expanded(
                                child: _buildVolumeBreakdown(
                                  context,
                                  'Brown',
                                  '${(_suggestedBrownKg! / BROWN_WASTE_DENSITY).toStringAsFixed(2)} L',
                                  AppTheme.warning,
                                  Icons.forest,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 32),

            // Create button
            ElevatedButton(
              onPressed: _isCreating ? null : _createCycle,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Cycle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowToUseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.1),
                  AppTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'How to Use',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInstructionStep(
                  context,
                  '1',
                  'Measure your food waste from the kitchen (organic waste)',
                  Icons.kitchen,
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  context,
                  '2',
                  'Enter the weight (max ${MAX_ORGANIC_WASTE_KG} kg per cycle)',
                  Icons.scale,
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  context,
                  '3',
                  'The system will automatically calculate:\n'
                  '   • Total volume from your waste\n'
                  '   • How much brown waste you need to add\n'
                  '   • Projected completion date',
                  Icons.auto_awesome,
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  context,
                  '4',
                  'Add the suggested amount of brown waste to balance the C:N ratio',
                  Icons.balance,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(
    BuildContext context,
    String number,
    String text,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          icon,
          color: AppTheme.primaryGreen,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }

  void _showOrganicWasteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryGreen.withOpacity(0.1),
                  AppTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'What is Organic Waste?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Organic waste is nitrogen-rich material:',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildWasteItem('Food scraps (vegetables, fruits, leftovers)'),
                _buildWasteItem('Coffee grounds'),
                _buildWasteItem('Fresh grass clippings'),
                _buildWasteItem('Kitchen waste'),
                _buildWasteItem('Green leaves'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warning.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Maximum: ${MAX_ORGANIC_WASTE_KG} kg per cycle',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warning,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBrownWasteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.warning.withOpacity(0.1),
                  AppTheme.warning.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.forest,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'What is Brown Waste?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warning,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Brown waste is carbon-rich organic material:',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildWasteItem('Dry leaves'),
                _buildWasteItem('Straw or hay'),
                _buildWasteItem('Sawdust'),
                _buildWasteItem('Cardboard (shredded)'),
                _buildWasteItem('Newspaper (shredded)'),
                _buildWasteItem('Wood chips'),
                _buildWasteItem('Dried grass'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWasteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBreakdown(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
