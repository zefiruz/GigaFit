import 'package:flutter/material.dart';

import '../../services/plan_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/theme.dart';

// Экраны
import '../library/workout_detail_screen.dart';
import '../library/plan_detail_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Каталог GigaFit',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 20),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: const TabBar(
            indicatorColor: AppColors.system,
            labelColor: AppColors.system,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Тренировки', icon: Icon(Icons.fitness_center)),
              Tab(text: 'Планы', icon: Icon(Icons.event_note)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PublicWorkoutsTab(), _PublicPlansTab()],
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 1: ПУБЛИЧНЫЕ ТРЕНИРОВКИ
// ==========================================
class _PublicWorkoutsTab extends StatefulWidget {
  const _PublicWorkoutsTab({Key? key}) : super(key: key);

  @override
  State<_PublicWorkoutsTab> createState() => _PublicWorkoutsTabState();
}

class _PublicWorkoutsTabState extends State<_PublicWorkoutsTab> {
  bool _isLoading = true;
  List _workouts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSystemWorkouts();
  }

  Future<void> _loadSystemWorkouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final workouts = await WorkoutService().getAllSystemWorkouts();

      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка сети: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSystemWorkouts,
      color: AppColors.system,
      backgroundColor: AppColors.surface,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.system))
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          : _workouts.isEmpty
          ? _buildEmptyState(
              'Каталог пуст',
              'Скоро здесь появятся тренировки от сообщества!',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final isAi = workout['is_ai_generated'] ?? false;

                return Card(
                  color: AppColors.card,
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.system.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAi ? Icons.auto_awesome : Icons.sports_gymnastics,
                        color: AppColors.system,
                      ),
                    ),
                    title: Text(
                      workout['title'] ?? 'Без названия',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${workout['exercises']?.length ?? 0} упр. • ${workout['total_duration_est'] ?? 0} мин.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.system.withOpacity(0.15),
                        foregroundColor: AppColors.system,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WorkoutDetailScreen(workoutData: workout),
                          ),
                        );
                      },
                      child: const Text('Смотреть', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 2: ПУБЛИЧНЫЕ ПЛАНЫ
// ==========================================
class _PublicPlansTab extends StatefulWidget {
  const _PublicPlansTab({Key? key}) : super(key: key);

  @override
  State<_PublicPlansTab> createState() => _PublicPlansTabState();
}

class _PublicPlansTabState extends State<_PublicPlansTab> {
  bool _isLoading = true;
  List _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSystemPlans();
  }

  Future<void> _loadSystemPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plans = await PlanService().getAllSystemPlans();

      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка сети';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSystemPlans,
      color: AppColors.system,
      backgroundColor: AppColors.surface,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.system))
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          : _plans.isEmpty
          ? _buildEmptyState(
              'Нет системных планов',
              'Скоро здесь появятся планы от разработчиков!',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];

                return Card(
                  color: AppColors.card,
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.system.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_note, color: AppColors.system),
                    ),
                    title: Text(
                      plan['title'] ?? 'План тренировок',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Длительность: ${plan['duration_weeks'] ?? 4} нед.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.system.withOpacity(0.15),
                        foregroundColor: AppColors.system,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PlanDetailScreen(planData: plan),
                          ),
                        );
                      },
                      child: const Text('Смотреть', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.event_busy, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}