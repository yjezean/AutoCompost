import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cycle_provider.dart';
import '../models/compost_batch.dart';
import '../theme/app_theme.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _greenController = TextEditingController();
  final _brownController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _projectedEndDate;
  double _organicWasteKg = 0.0;
  double _brownWasteKg = 0.0;
  double? _initialVolumeLiters;
  double? _suggestedBrownKg;
  bool _isCreating = false;
  static const double MAX_ORGANIC_WASTE_KG = 1.0;
  
  // Density constants (kg per liter)
  static const double ORGANIC_WASTE_DENSITY = 0.5; // Kitchen scraps: ~0.5 kg/L
  static const double BROWN_WASTE_DENSITY = 0.1; // Dry leaves: ~0.1 kg/L

  @override
  void initState() {
    super.initState();
    _greenController.addListener(_calculateAll);
    _brownController.addListener(_calculateAll);
    _calculateAll();
  }

  @override
  void dispose() {
    _greenController.dispose();
    _brownController.dispose();
    super.dispose();
  }

  void _calculateAll() {
    // Calculate volume from organic and brown waste
    final organicKg = double.tryParse(_greenController.text) ?? 0.0;
    final brownKg = double.tryParse(_brownController.text) ?? 0.0;
    
    // Calculate volumes
    final organicVolume = organicKg > 0 ? organicKg / ORGANIC_WASTE_DENSITY : 0.0;
    final brownVolume = brownKg > 0 ? brownKg / BROWN_WASTE_DENSITY : 0.0;
    final totalVolume = organicVolume + brownVolume;
    
    setState(() {
      _organicWasteKg = organicKg;
      _brownWasteKg = brownKg;
      _initialVolumeLiters = totalVolume > 0 ? totalVolume : null;
    });

    // Calculate projected end date from total volume
    if (totalVolume > 0) {
      // Base: 21 days + 1 day per 5 liters, max 90 days
      final baseDays = 21;
      final additionalDays = (totalVolume / 5.0).ceil();
      final totalDays = (baseDays + additionalDays).clamp(21, 90);
      setState(() {
        _projectedEndDate = _startDate.add(Duration(days: totalDays));
      });
    } else {
      setState(() {
        _projectedEndDate = _startDate.add(const Duration(days: 21));
      });
    }

    // Calculate suggested brown waste
    if (organicKg > 0) {
      // Formula: B = G * (27.5 - 20) / (60 - 27.5) ≈ G * 0.231
      final suggested = organicKg * 0.231;
      setState(() {
        _suggestedBrownKg = suggested;
      });
    } else {
      setState(() {
        _suggestedBrownKg = null;
      });
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
        brownWasteKg: _brownWasteKg > 0 ? _brownWasteKg : null,
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

            // Suggested Brown Waste Display
            if (_suggestedBrownKg != null && _organicWasteKg > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: AppTheme.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Suggested Brown Waste:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.info,
                            ),
                          ),
                          Text(
                            '${_suggestedBrownKg!.toStringAsFixed(2)} kg',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.info,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add this amount to balance C:N ratio',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Brown waste input
            TextFormField(
              controller: _brownController,
              decoration: InputDecoration(
                labelText: 'Brown Waste (kg)',
                hintText: _suggestedBrownKg != null
                    ? 'Suggested: ${_suggestedBrownKg!.toStringAsFixed(2)} kg'
                    : 'Enter amount',
                prefixIcon: const Icon(Icons.forest, color: AppTheme.warning),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.info_outline, color: AppTheme.warning),
                  onPressed: () => _showBrownWasteDialog(context),
                  tooltip: 'What is Brown Waste?',
                ),
                suffixText: 'kg',
                border: const OutlineInputBorder(),
                helperText: 'Add based on system suggestion',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSaved: (value) {
                _brownWasteKg = value != null && value.isNotEmpty
                    ? (double.tryParse(value) ?? 0.0)
                    : 0.0;
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final weight = double.tryParse(value);
                  if (weight == null || weight < 0) {
                    return 'Please enter a valid weight';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Calculated Volume Display
            if (_initialVolumeLiters != null && _initialVolumeLiters! > 0) ...[
              Card(
                color: AppTheme.info.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, color: AppTheme.info, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculated Total Volume',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.info,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_initialVolumeLiters!.toStringAsFixed(2)} liters',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.info,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Organic: ${(_organicWasteKg / ORGANIC_WASTE_DENSITY).toStringAsFixed(2)} L'
                              '${_brownWasteKg > 0 ? ' + Brown: ${(_brownWasteKg / BROWN_WASTE_DENSITY).toStringAsFixed(2)} L' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
}
