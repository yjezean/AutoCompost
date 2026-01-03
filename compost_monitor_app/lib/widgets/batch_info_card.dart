import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/compost_batch.dart';
import '../models/completion_status.dart';
import '../theme/app_theme.dart';

class BatchInfoCard extends StatelessWidget {
  final CompostBatch? batch;
  final CompletionStatus? completionStatus;
  final double combinedProgress;

  const BatchInfoCard({
    super.key,
    required this.batch,
    this.completionStatus,
    required this.combinedProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (batch == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No active batch',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final progressPercent = combinedProgress.clamp(0.0, 100.0);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.recycling, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Current Batch',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              'Started',
              dateFormat.format(batch!.startDate),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Projected Complete',
              dateFormat.format(batch!.projectedEndDate),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${progressPercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 8,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(progressPercent),
                ),
              ),
            ),
            if (completionStatus != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _getStatusIcon(completionStatus!.status),
                    size: 16,
                    color: _getStatusColor(completionStatus!.status),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(completionStatus!.status),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(completionStatus!.status),
                        ),
                  ),
                  if (completionStatus!.estimatedDaysRemaining != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${completionStatus!.estimatedDaysRemaining} days remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
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

  Color _getProgressColor(double progress) {
    if (progress < 30) return AppTheme.tempCold;
    if (progress < 70) return AppTheme.primaryGreen;
    if (progress < 90) return AppTheme.tempWarning;
    return AppTheme.tempOptimal;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'complete':
        return Icons.check_circle;
      case 'completing':
        return Icons.trending_down;
      default:
        return Icons.autorenew;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'complete':
        return AppTheme.success;
      case 'completing':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'complete':
        return 'Complete';
      case 'completing':
        return 'Completing';
      default:
        return 'Active';
    }
  }
}

