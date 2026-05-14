import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../widgets/theme.dart';
import 'workout_detail_screen.dart';
import '../../services/plan_service.dart'; // Добавили импорт сервиса!

class PlanDetailScreen extends StatefulWidget {
  final dynamic planData;

  const PlanDetailScreen({Key? key, required this.planData}) : super(key: key);

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _fullPlan = {};

  // Маппинг для названий дней
  static const Map<int, String> _dayNames = {
    1: 'ПН',
    2: 'ВТ',
    3: 'СР',
    4: 'ЧТ',
    5: 'ПТ',
    6: 'СБ',
    7: 'ВС',
  };

  @override
  void initState() {
    super.initState();
    _loadFullPlanData();
  }

  // Запрашиваем полную версию плана с бэкенда!
  Future<void> _loadFullPlanData() async {
    final planId = widget.planData['id'] ?? widget.planData['ID'];

    if (planId != null) {
      final fullData = await PlanService().getPlanById(planId);
      if (mounted) {
        setState(() {
          // Если данные пришли, берем их. Если вдруг ошибка сети - берем то, что передали из списка
          _fullPlan = fullData ?? widget.planData;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _fullPlan = widget.planData;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пока грузим полные данные - показываем крутилку
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Детали плана'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // РАБОТАЕМ С ПОЛНЫМИ ДАННЫМИ
    final safeData = _fullPlan;
    final title = safeData['title'] ?? safeData['Title'] ?? 'План тренировок';
    final description =
        safeData['description'] ?? safeData['Description'] ?? '';
    final duration =
        safeData['duration_weeks'] ?? safeData['DurationWeeks'] ?? 4;
    final List rawWorkouts = safeData['workouts'] ?? safeData['Workouts'] ?? [];

    // Группируем тренировки по номеру недели
    final groupedWorkouts = groupBy(rawWorkouts, (dynamic w) {
      return w['week_number'] ?? w['WeekNumber'] ?? 1;
    });

    // Сортируем недели по порядку
    final sortedWeeks = groupedWorkouts.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали плана'),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(title, duration, description),
            const SizedBox(height: 24),

            if (sortedWeeks.isEmpty)
              const Center(
                child: Text(
                  'Расписание пусто',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            ...sortedWeeks.map((weekNum) {
              final weekWorkouts = groupedWorkouts[weekNum]!;
              weekWorkouts.sort(
                (a, b) =>
                    (a['day_number'] ?? 0).compareTo(b['day_number'] ?? 0),
              );

              return _buildWeekSection(context, weekNum, weekWorkouts);
            }).toList(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, int duration, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.system.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                size: 16,
                color: AppColors.system,
              ),
              const SizedBox(width: 6),
              Text(
                '$duration недель',
                style: const TextStyle(
                  color: AppColors.system,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekSection(BuildContext context, int weekNum, List workouts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Text(
            'НЕДЕЛЯ $weekNum',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...workouts.map((w) => _buildWorkoutCard(context, w)).toList(),
      ],
    );
  }

  Widget _buildWorkoutCard(BuildContext context, dynamic w) {
    final dayNum = w['day_number'] ?? w['DayNumber'] ?? 1;
    final dayName = _dayNames[dayNum] ?? '$dayNum';

    final workoutInfo = w['workout_info'] ?? w['workout'] ?? w['Workout'] ?? w;
    final title = workoutInfo['title'] ?? workoutInfo['Title'] ?? 'Тренировка';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.system.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            dayName,
            style: const TextStyle(
              color: AppColors.system,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: const Text(
          'Нажмите, чтобы посмотреть упражнения',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  WorkoutDetailScreen(workoutData: workoutInfo),
            ),
          );
        },
      ),
    );
  }
}
