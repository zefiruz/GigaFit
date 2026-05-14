import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../services/plan_service.dart';
import '../../widgets/theme.dart';

class AiPlanPreviewScreen extends StatefulWidget {
  final dynamic planData;

  const AiPlanPreviewScreen({Key? key, required this.planData})
    : super(key: key);

  @override
  State<AiPlanPreviewScreen> createState() => _AiPlanPreviewScreenState();
}

class _AiPlanPreviewScreenState extends State<AiPlanPreviewScreen> {
  bool _isSaved = false;

  // Маппинг для красивых названий дней
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
  Widget build(BuildContext context) {
    final safeData = widget.planData ?? {};
    final planId = safeData['id'];
    final title =
        safeData['title'] ?? safeData['Title'] ?? 'Сгенерированный План';
    final description =
        safeData['description'] ?? safeData['Description'] ?? '';
    final duration =
        safeData['duration_weeks'] ?? safeData['DurationWeeks'] ?? 4;

    final List rawWorkouts = safeData['workouts'] ?? safeData['Workouts'] ?? [];

    // 1. Группируем тренировки по неделям
    final groupedWorkouts = groupBy(rawWorkouts, (dynamic w) {
      return w['week_number'] ?? w['WeekNumber'] ?? 1;
    });

    // 2. Сортируем недели по порядку
    final sortedWeeks = groupedWorkouts.keys.toList()..sort();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!_isSaved && planId != null) {
          PlanService().deletePlan(planId, hard: true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Ваш новый план',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Шапка плана
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.system.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.system),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Длительность: $duration нед.',
                    style: const TextStyle(
                      color: AppColors.system,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Расписание тренировок:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Вывод тренировок, сгруппированных по неделям
            if (sortedWeeks.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surface),
                ),
                child: const Text(
                  'ИИ не добавил тренировки :(',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            // Генерируем блоки недель
            ...sortedWeeks.map((weekNum) {
              final weekWorkouts = groupedWorkouts[weekNum]!;
              // Сортируем дни внутри недели по порядку
              weekWorkouts.sort(
                (a, b) =>
                    (a['day_number'] ?? 0).compareTo(b['day_number'] ?? 0),
              );

              return _buildWeekSection(weekNum, weekWorkouts);
            }).toList(),

            const SizedBox(height: 24),

            // Кнопка сохранения
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.system,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() => _isSaved = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('План добавлен в библиотеку! 🗓️'),
                    backgroundColor: AppColors.system,
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Добавить в мои планы',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Вспомогательные виджеты ---

  Widget _buildWeekSection(int weekNum, List workouts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
        ...workouts.map((w) => _buildWorkoutCard(w)).toList(),
      ],
    );
  }

  Widget _buildWorkoutCard(dynamic w) {
    final dayNum = w['day_number'] ?? w['DayNumber'] ?? 1;
    final dayName = _dayNames[dayNum] ?? '$dayNum';

    // Пытаемся достать инфо о тренировке
    final workoutInfo = w['workout_info'] ?? w['workout'] ?? w['Workout'] ?? w;
    final workoutTitle =
        workoutInfo['title'] ?? workoutInfo['Title'] ?? 'Тренировка';

    // Достаем упражнения из тренировки (используем нашу "бронебойную" проверку)
    final List exercises =
        workoutInfo['exercises'] ?? workoutInfo['Exercises'] ?? [];

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        // Убираем линии при разворачивании ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.system,
          collapsedIconColor: AppColors.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 48,
            height: 48,
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
            workoutTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Сгенерировано ИИ • ${exercises.length} упр.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          // Рендерим список упражнений внутри выпадающего списка
          children: exercises.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Список упражнений пуст',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ]
              : [
                  ...exercises.map((ex) {
                    final info =
                        ex['exercise_info'] ??
                        ex['exercise'] ??
                        ex['Exercise'] ??
                        {};
                    final exName = info['name'] ?? info['Name'] ?? 'Упражнение';
                    final sets = ex['sets'] ?? ex['Sets'] ?? 0;
                    final reps = ex['reps'] ?? ex['Reps'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.system,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              exName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '$sets x $reps',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(
                    height: 12,
                  ), // Небольшой отступ снизу для красоты
                ],
        ),
      ),
    );
  }
}
