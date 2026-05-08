import 'package:flutter/material.dart';
import '../../widgets/theme.dart';
import 'workout_detail_screen.dart';

class PlanDetailScreen extends StatelessWidget {
  final dynamic planData;

  const PlanDetailScreen({Key? key, required this.planData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Безопасный парсинг данных
    final safeData = planData ?? {};
    final title = safeData['title'] ?? safeData['Title'] ?? 'План тренировок';
    final description = safeData['description'] ?? safeData['Description'] ?? '';
    final duration = safeData['duration_weeks'] ?? safeData['DurationWeeks'] ?? 4;

    List workouts = safeData['workouts'] ?? safeData['Workouts'] ?? [];

    // Сортировка по порядку
    workouts.sort((a, b) {
      int weekA = a['week_number'] ?? a['WeekNumber'] ?? 1;
      int weekB = b['week_number'] ?? b['WeekNumber'] ?? 1;
      if (weekA == weekB) {
        int dayA = a['day_number'] ?? a['DayNumber'] ?? 1;
        int dayB = b['day_number'] ?? b['DayNumber'] ?? 1;
        return dayA.compareTo(dayB);
      }
      return weekA.compareTo(weekB);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Детали плана',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Длительность: $duration нед.',
                  style: const TextStyle(
                    color: AppColors.system,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Расписание:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          if (workouts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('В плане пока нет тренировок', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),

          ...workouts.map((w) {
            final week = w['week_number'] ?? w['WeekNumber'] ?? 1;
            final day = w['day_number'] ?? w['DayNumber'] ?? 1;
            final actualWorkout = w['workout_info'] ?? w['workout'] ?? w['Workout'] ?? w;
            final workoutTitle = actualWorkout['title'] ?? actualWorkout['Title'] ?? 'Тренировка';

            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.system.withOpacity(0.15),
                  child: Text(
                    '$day',
                    style: const TextStyle(color: AppColors.system, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  workoutTitle,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Неделя $week', style: const TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutDetailScreen(workoutData: actualWorkout),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}