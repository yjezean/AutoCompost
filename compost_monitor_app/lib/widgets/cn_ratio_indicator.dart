import 'package:flutter/material.dart';
import '../models/cn_ratio.dart';
import '../theme/app_theme.dart';

class CNRatioIndicator extends StatelessWidget {
  final CNRatio cnRatio;

  const CNRatioIndicator({
    super.key,
    required this.cnRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'C:N Ratio',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cnRatio.currentRatio.toStringAsFixed(1)}:1',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Optimal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cnRatio.optimalRatio.toStringAsFixed(1)}:1',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Visual ratio bar
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _getRatioProgress(),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            if (!cnRatio.isOptimal) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSuggestionIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getSuggestionText(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _getStatusColor(),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (cnRatio.isOptimal) return Icons.check_circle;
    if (cnRatio.needsMoreBrown) return Icons.warning;
    return Icons.info;
  }

  Color _getStatusColor() {
    if (cnRatio.isOptimal) return AppTheme.success;
    if (cnRatio.needsMoreBrown) return AppTheme.warning;
    return AppTheme.info;
  }

  double _getRatioProgress() {
    // Normalize ratio to 0-1 scale (assuming optimal range is 25-30)
    final ratio = cnRatio.currentRatio;
    if (ratio < 25) return ratio / 30;
    if (ratio > 30) return 1.0;
    return 0.8; // Optimal range
  }

  IconData _getSuggestionIcon() {
    if (cnRatio.needsMoreBrown) return Icons.add_circle_outline;
    return Icons.remove_circle_outline;
  }

  String _getSuggestionText() {
    if (cnRatio.needsMoreBrown && cnRatio.suggestedBrownKg != null) {
      return 'Add ${cnRatio.suggestedBrownKg!.toStringAsFixed(1)} kg of brown waste';
    }
    if (cnRatio.needsMoreGreen) {
      return 'Add more green waste to balance the ratio';
    }
    return 'Ratio is optimal!';
  }
}

