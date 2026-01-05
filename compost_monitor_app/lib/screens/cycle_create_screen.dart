import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cycle_provider.dart';
import '../models/compost_batch.dart';
import '../theme/app_theme.dart';
import '../widgets/waste_input_form.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _startDate = DateTime.now();
  DateTime _projectedEndDate = DateTime.now().add(const Duration(days: 21));
  double _greenWasteKg = 0.0;
  double _brownWasteKg = 0.0;
  double? _initialVolumeLiters;
  bool _isCreating = false;

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _projectedEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_projectedEndDate.isBefore(_startDate)) {
            _projectedEndDate = _startDate.add(const Duration(days: 21));
          }
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
        projectedEndDate: _projectedEndDate,
        status: 'planning',
        createdAt: DateTime.now(),
        greenWasteKg: _greenWasteKg > 0 ? _greenWasteKg : null,
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

            // Projected end date
            Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: AppTheme.primaryGreen),
                title: const Text('Projected End Date'),
                subtitle: Text(dateFormat.format(_projectedEndDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectDate(context, false),
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
                      'Duration: ${_projectedEndDate.difference(_startDate).inDays} days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Waste input form (without cycle ID for creation)
            Text(
              'Waste Input (Optional)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You can add waste amounts now or update them later',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            WasteInputForm(
              onChanged: (greenKg, brownKg) {
                setState(() {
                  _greenWasteKg = greenKg;
                  _brownWasteKg = brownKg;
                });
              },
            ),
            const SizedBox(height: 24),

            // Initial volume (optional)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Initial Volume (Liters)',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.water_drop),
                suffixText: 'L',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSaved: (value) {
                _initialVolumeLiters = value != null && value.isNotEmpty
                    ? double.tryParse(value)
                    : null;
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final volume = double.tryParse(value);
                  if (volume == null || volume < 0) {
                    return 'Please enter a valid volume';
                  }
                }
                return null;
              },
            ),
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
}

