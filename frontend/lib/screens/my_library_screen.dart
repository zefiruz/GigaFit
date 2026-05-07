import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'workout_detail_screen.dart';

class MyLibraryScreen extends StatelessWidget {
  const MyLibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00E676);
    const bgColor = Color(0xFF121212);

    return DefaultTabController(
      length: 2, // Количество вкладок
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text(
            'Моя библиотека',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: bgColor,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: primaryGreen,
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Тренировки', icon: Icon(Icons.fitness_center)),
              Tab(text: 'Планы', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Вкладка 1: Тренировки
            _WorkoutsTab(),
            // Вкладка 2: Планы
            _PlansTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 1: ТРЕНИРОВКИ
// ==========================================
class _WorkoutsTab extends StatefulWidget {
  const _WorkoutsTab({Key? key}) : super(key: key);

  @override
  State<_WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<_WorkoutsTab> {
  bool _isLoading = true;
  List _workouts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient().get('/workout/all');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _workouts = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Ошибка: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00E676);
    const cardColor = Color(0xFF1E1E1E);

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      color: primaryGreen,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _workouts.isEmpty
          ? _buildEmptyState('Нет тренировок', 'Создай свою первую тренировку!')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final isAi = workout['is_ai_generated'] ?? false;

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isAi
                          ? primaryGreen.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isAi ? Icons.auto_awesome : Icons.sports_gymnastics,
                      color: isAi ? primaryGreen : Colors.white70,
                    ),
                    title: Text(
                      workout['title'] ?? 'Без названия',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${workout['exercises']?.length ?? 0} упр. • ${workout['total_duration_est'] ?? 0} мин.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WorkoutDetailScreen(workoutData: workout),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      // Используем ListView, чтобы RefreshIndicator работал даже на пустом экране
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Icon(Icons.fitness_center, size: 64, color: Colors.grey[800]),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

// ==========================================
// ВКЛАДКА 2: ПЛАНЫ (Задел на будущее)
// ==========================================
class _PlansTab extends StatefulWidget {
  const _PlansTab({Key? key}) : super(key: key);

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  bool _isLoading = true;
  List _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // У тебя в Go уже есть эта ручка в RouteGroup!
      final response = await ApiClient().get('/plan/all');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _plans = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Ошибка: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF00E676);
    const cardColor = Color(0xFF1E1E1E);

    return RefreshIndicator(
      onRefresh: _loadPlans,
      color: primaryGreen,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _plans.isEmpty
          ? _buildEmptyState(
              'Нет активных планов',
              'Сгенерируй план на месяц с ИИ!',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final isAi =
                    plan['is_ai_generated'] ??
                    true; // Допустим, пока все планы от ИИ

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isAi
                          ? Colors.purpleAccent.withOpacity(0.5)
                          : Colors.transparent,
                    ), // Планы можно подсветить фиолетовым!
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.event_note,
                      color: isAi ? Colors.purpleAccent : Colors.white70,
                    ),
                    title: Text(
                      plan['title'] ?? 'План тренировок',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Длительность: ${plan['duration_weeks'] ?? 4} нед.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      // TODO: Навигация на экран просмотра деталей плана (календарь)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скоро: Детали плана!')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Icon(Icons.calendar_month, size: 64, color: Colors.grey[800]),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
