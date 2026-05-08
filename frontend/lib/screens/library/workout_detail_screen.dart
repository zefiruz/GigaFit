import 'package:flutter/material.dart';
import '../../widgets/theme.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final dynamic workoutData;

  const WorkoutDetailScreen({Key? key, required this.workoutData})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Безопасно достаем данные
    final safeData = workoutData ?? {};
    final title = safeData['title'] ?? safeData['Title'] ?? 'Тренировка';
    final description = safeData['description'] ?? safeData['Description'] ?? '';
    final List exercises = safeData['exercises'] ?? safeData['Exercises'] ?? [];
    final bool isAi = safeData['is_ai_generated'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Детали тренировки',
          style: TextStyle(
            color: AppColors.textPrimary, 
            fontWeight: FontWeight.w600, 
            fontSize: 20
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
          // Шапка тренировки
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isAi ? AppColors.primary : AppColors.personal).withOpacity(0.3)
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAi ? Icons.auto_awesome : Icons.sports_gymnastics,
                      color: isAi ? AppColors.primary : AppColors.personal,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
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
                      height: 1.4
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Программа упражнений:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Список упражнений
          ...exercises.map((ex) {
            final info = ex['exercise_info'] ?? ex['exercise'] ?? {};
            final exName = info['name'] ?? 'Упражнение';
            final exDesc = info['description'] ?? 'Описание отсутствует';
            final muscleGroups = info['muscle_groups'] ?? {};

            final sets = ex['sets'] ?? 3;
            final reps = ex['reps'] ?? 12;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surface),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: AppColors.primary,
                  collapsedIconColor: AppColors.textSecondary,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: isAi ? AppColors.primary : AppColors.personal,
                    ),
                  ),
                  title: Text(
                    exName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$sets подхода по $reps повторений',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: AppColors.surface),
                          const SizedBox(height: 8),
                          const Text(
                            'ТЕХНИКА ВЫПОЛНЕНИЯ:',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exDesc,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (muscleGroups['primary'] != null) ...[
                            const Text(
                              'ЦЕЛЕВЫЕ МЫШЦЫ:',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: (muscleGroups['primary'] as List)
                                  .map((m) => _buildMuscleChip(m.toString()))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 32),

          // Кнопка начала тренировки
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white, // Белый текст для строгости
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Режим активной тренировки скоро появится! 🔥'),
                  backgroundColor: AppColors.primaryDark,
                ),
              );
            },
            child: const Text(
              'НАЧАТЬ ТРЕНИРОВКУ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMuscleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary, 
          fontSize: 11,
          fontWeight: FontWeight.w500
        ),
      ),
    );
  }
}