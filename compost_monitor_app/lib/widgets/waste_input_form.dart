import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/compost_material.dart';
import '../models/cn_ratio.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'cn_ratio_indicator.dart';

class WasteInputForm extends StatefulWidget {
  final int? cycleId;
  final double? initialGreenWaste;
  final double? initialBrownWaste;
  final Function(double greenKg, double brownKg)? onChanged;

  const WasteInputForm({
    super.key,
    this.cycleId,
    this.initialGreenWaste,
    this.initialBrownWaste,
    this.onChanged,
  });

  @override
  State<WasteInputForm> createState() => _WasteInputFormState();
}

class _WasteInputFormState extends State<WasteInputForm> {
  final _greenController = TextEditingController();
  final _brownController = TextEditingController();
  List<CompostMaterial> _materials = [];
  CompostMaterial? _selectedGreenMaterial;
  CompostMaterial? _selectedBrownMaterial;
  CNRatio? _cnRatio;
  bool _isCalculating = false;
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
    _loadMaterials();
    _greenController.addListener(_onInputChanged);
    _brownController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _greenController.dispose();
    _brownController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await ApiService.getMaterials();
      setState(() {
        _materials = materials;
      });
    } catch (e) {
      // Materials are optional, don't show error
    }
  }

  void _onInputChanged() {
    final greenKg = double.tryParse(_greenController.text) ?? 0.0;
    final brownKg = double.tryParse(_brownController.text) ?? 0.0;

    // Only calculate ratio on input change, don't trigger onChanged callback
    // onChanged should be called explicitly via save button or onSubmitted
    if (greenKg > 0 && brownKg > 0 && widget.cycleId != null) {
      _calculateRatio();
    } else {
      setState(() {
        _cnRatio = null;
      });
    }
  }

  // Method to get current values and trigger onChanged callback
  void save() {
    final greenKg = double.tryParse(_greenController.text) ?? 0.0;
    final brownKg = double.tryParse(_brownController.text) ?? 0.0;
    
    if (widget.onChanged != null) {
      widget.onChanged!(greenKg, brownKg);
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

  double get greenWasteKg => double.tryParse(_greenController.text) ?? 0.0;
  double get brownWasteKg => double.tryParse(_brownController.text) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Green waste input
        TextField(
          controller: _greenController,
          decoration: InputDecoration(
            labelText: 'Green Waste (kg)',
            hintText: 'Enter amount',
            prefixIcon: const Icon(Icons.eco, color: AppTheme.success),
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
        
        // Material selectors (optional)
        if (_materials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CompostMaterial>(
                  value: _selectedGreenMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Green Material Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.eco),
                  ),
                  items: _materials
                      .where((m) => m.materialType == 'green')
                      .map((material) => DropdownMenuItem(
                            value: material,
                            child: Text(material.name),
                          ))
                      .toList(),
                  onChanged: (material) {
                    setState(() {
                      _selectedGreenMaterial = material;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<CompostMaterial>(
                  value: _selectedBrownMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Brown Material Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.forest),
                  ),
                  items: _materials
                      .where((m) => m.materialType == 'brown')
                      .map((material) => DropdownMenuItem(
                            value: material,
                            child: Text(material.name),
                          ))
                      .toList(),
                  onChanged: (material) {
                    setState(() {
                      _selectedBrownMaterial = material;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
        
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
      ],
    );
  }
}

