import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/compost_batch.dart';
import '../theme/app_theme.dart';

class CycleCard extends StatelessWidget {
  final CompostBatch cycle;
  final VoidCallback? onTap;
  final VoidCallback? onActivate;
  final bool showActions;

  const CycleCard({
    super.key,
    required this.cycle,
    this.onTap,
    this.onActivate,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final progress = cycle.getTimeProgress();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cycle #${cycle.id}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildStatusBadge(context),
                ],
              ),
              const SizedBox(height: 12),
              
              // Dates
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Started',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(cycle.startDate),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Ends',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(cycle.projectedEndDate),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Progress bar
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 6,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(progress),
                  ),
                ),
              ),
              
              // Waste amounts and C:N ratio (if available)
              if (cycle.greenWasteKg != null || cycle.brownWasteKg != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (cycle.greenWasteKg != null)
                      Expanded(
                        child: _buildWasteInfo(
                          context,
                          'Green',
                          cycle.greenWasteKg!,
                          AppTheme.success,
                          Icons.eco,
                        ),
                      ),
                    if (cycle.greenWasteKg != null && cycle.brownWasteKg != null)
                      const SizedBox(width: 16),
                    if (cycle.brownWasteKg != null)
                      Expanded(
                        child: _buildWasteInfo(
                          context,
                          'Brown',
                          cycle.brownWasteKg!,
                          AppTheme.warning,
                          Icons.forest,
                        ),
                      ),
                  ],
                ),
              ],
              
              if (cycle.cnRatio != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.science,
                      size: 16,
                      color: _getCNRatioColor(cycle.cnRatio!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'C:N ${cycle.cnRatio!.toStringAsFixed(1)}:1',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getCNRatioColor(cycle.cnRatio!),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ],
              
              // Actions
              if (showActions && (cycle.status != 'active' || onActivate != null)) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cycle.status != 'active' && onActivate != null)
                      OutlinedButton.icon(
                        onPressed: onActivate,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Activate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                        ),
                      ),
                    if (onTap != null) ...[
                      if (cycle.status != 'active' && onActivate != null)
                        const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View Details'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String text;
    
    switch (cycle.status) {
      case 'active':
        color = AppTheme.success;
        text = 'Active';
        break;
      case 'planning':
        color = AppTheme.info;
        text = 'Planning';
        break;
      case 'completed':
        color = AppTheme.textSecondary;
        text = 'Completed';
        break;
      case 'archived':
        color = AppTheme.textSecondary;
        text = 'Archived';
        break;
      default:
        color = AppTheme.textSecondary;
        text = cycle.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildWasteInfo(
    BuildContext context,
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        Text(
          '${amount.toStringAsFixed(1)} kg',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
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

