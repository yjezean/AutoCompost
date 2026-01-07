import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cycle_provider.dart';
import '../models/compost_batch.dart';
import '../theme/app_theme.dart';
import '../widgets/cycle_card.dart';
import 'cycle_create_screen.dart';
import 'cycle_detail_screen.dart';
import 'completed_cycles_analytics_screen.dart';

class CycleManagementScreen extends StatefulWidget {
  const CycleManagementScreen({super.key});

  @override
  State<CycleManagementScreen> createState() => _CycleManagementScreenState();
}

class _CycleManagementScreenState extends State<CycleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CycleProvider>().fetchCycles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CycleProvider>().refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Category Selector
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.divider,
                width: 1,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: [
                _buildTab('All', Icons.list, 0),
                _buildTab('Planning', Icons.schedule, 1),
                _buildTab('Active', Icons.play_circle, 2),
                _buildTab('Completed', Icons.check_circle, 3),
              ],
            ),
          ),
          // Content Area
          Expanded(
            child: Consumer<CycleProvider>(
              builder: (context, cycleProvider, child) {
                if (cycleProvider.isLoading && cycleProvider.cycles.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (cycleProvider.error != null && cycleProvider.cycles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading cycles',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cycleProvider.error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => cycleProvider.refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCycleList(cycleProvider.cycles, cycleProvider, false),
                    _buildCycleList(cycleProvider.planningCycles, cycleProvider, false),
                    _buildCycleList(cycleProvider.activeCycles, cycleProvider, false),
                    _buildCycleList(cycleProvider.completedCycles, cycleProvider, true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CycleCreateScreen(),
            ),
          ).then((_) {
            context.read<CycleProvider>().refresh();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('New Cycle'),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildCycleList(List<CompostBatch> cycles, CycleProvider provider, bool isCompletedTab) {
    if (cycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.recycling,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No cycles found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new cycle to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: Column(
        children: [
          // Analytics button for completed cycles
          if (isCompletedTab) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompletedCyclesAnalyticsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('View Analytics'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
            ),
          ],
          // Cycles list
          Expanded(
            child: ListView.builder(
              itemCount: cycles.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final cycle = cycles[index];
                return CycleCard(
                  cycle: cycle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CycleDetailScreen(cycleId: cycle.id),
                      ),
                    ).then((_) {
                      provider.refresh();
                    });
                  },
                  onActivate: cycle.status != 'active'
                      ? () => _activateCycle(context, cycle.id, provider)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateCycle(
    BuildContext context,
    int cycleId,
    CycleProvider provider,
  ) async {
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
        await provider.activateCycle(cycleId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cycle activated successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
}

