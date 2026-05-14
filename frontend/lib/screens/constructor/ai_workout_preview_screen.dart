import 'package:flutter/material.dart';
import '../../services/workout_service.dart';
import '../../widgets/theme.dart';

class AiWorkoutPreviewScreen extends StatefulWidget {
  final dynamic workoutData;

  const AiWorkoutPreviewScreen({Key? key, required this.workoutData})
    : super(key: key);

  @override
  State<AiWorkoutPreviewScreen> createState() => _AiWorkoutPreviewScreenState();
}

class _AiWorkoutPreviewScreenState extends State<AiWorkoutPreviewScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final safeData = widget.workoutData ?? {};
    final workoutId = safeData['id']; // Достаем ID тренировки для удаления
    final title = safeData['title'] ?? safeData['Title'] ?? 'Тренировка';
    final description =
        safeData['description'] ?? safeData['Description'] ?? '';
    final List exercises = safeData['exercises'] ?? safeData['Exercises'] ?? [];

    // PopScope позволяет перехватить нажатие кнопки "Назад" или жест смахивания
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!_isSaved && workoutId != null) {
          WorkoutService().deleteWorkout(workoutId, hard: true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Ваша тренировка',
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
            // Шапка
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16), // Строгий радиус
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ), // Оливковая окантовка
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
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 24),
            const Text(
              'Упражнения (нажми, чтобы узнать детали):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Список упражнений
            ...exercises.map((ex) {
              final info =
                  ex['exercise_info'] ?? ex['exercise'] ?? ex['Exercise'] ?? {};
              final exName = info['name'] ?? info['Name'] ?? 'Упражнение';
              final exDesc =
                  info['description'] ??
                  info['Description'] ??
                  'Описание отсутствует';
              final muscleGroups =
                  info['muscle_groups'] ?? info['MuscleGroups'] ?? {};

              final sets = ex['sets'] ?? ex['Sets'] ?? 3;
              final reps = ex['reps'] ?? ex['Reps'] ?? 12;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: AppColors.primary,
                    collapsedIconColor: AppColors.textSecondary,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.primary,
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
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(
                              color: AppColors.surface,
                            ), // Темный разделитель
                            const SizedBox(height: 8),
                            const Text(
                              'ТЕХНИКА:',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
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
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (muscleGroups['primary'] != null) ...[
                              const Text(
                                'РАБОЧИЕ МЫШЦЫ:',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
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

            const SizedBox(height: 24),

            // Кнопка сохранения
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white, // Белый текст!
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // 1. Ставим флаг, что удалять при выходе НЕ НАДО
                setState(() {
                  _isSaved = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Тренировка сохранена в "Мои тренировки"! 💪',
                    ),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );

                // Возвращаемся в меню
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Добавить в мои тренировки',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Обновленный чипс для мышц (строгий стиль)
  Widget _buildMuscleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
