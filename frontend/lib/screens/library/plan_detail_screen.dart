import 'package:flutter/material.dart';
import 'workout_detail_screen.dart';

class PlanDetailScreen extends StatelessWidget {
  final dynamic planData;

  const PlanDetailScreen({Key? key, required this.planData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Безопасно достаем данные плана
    final safeData = planData ?? {};
    final title = safeData['title'] ?? safeData['Title'] ?? 'План тренировок';
    final description =
        safeData['description'] ?? safeData['Description'] ?? '';
    final duration =
        safeData['duration_weeks'] ?? safeData['DurationWeeks'] ?? 4;

    // Достаем массив связок "План-Тренировка"
    List workouts = safeData['workouts'] ?? safeData['Workouts'] ?? [];

    // Сортируем тренировки по неделям и дням, чтобы они шли по порядку!
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

    const primaryGreen = Color(0xFF00E676);
    const cardColor = Color(0xFF1E1E1E);
    const bgColor = Color(0xFF121212);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Детали плана',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Шапка плана
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purpleAccent.withOpacity(0.3),
              ), // Планы у нас фиолетовые
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Длительность: $duration нед.',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Расписание:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          if (workouts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'В плане пока нет тренировок',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

          // Выводим отсортированный список дней
          ...workouts.map((w) {
            final week = w['week_number'] ?? w['WeekNumber'] ?? 1;
            final day = w['day_number'] ?? w['DayNumber'] ?? 1;

            // ИСПРАВЛЕНИЕ: Добавили 'workout_info' на первое место
            final actualWorkout =
                w['workout_info'] ?? w['workout'] ?? w['Workout'] ?? w;

            final workoutTitle =
                actualWorkout['title'] ??
                actualWorkout['Title'] ??
                'Тренировка';

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                  child: Text(
                    '$day',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  workoutTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Неделя $week',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  // Передаем правильный объект тренировки
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          WorkoutDetailScreen(workoutData: actualWorkout),
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
