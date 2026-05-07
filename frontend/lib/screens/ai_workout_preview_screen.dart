import 'package:flutter/material.dart';
import '../services/api_client.dart'; // Не забудь импорт твоего клиента

class AiWorkoutPreviewScreen extends StatefulWidget {
  final dynamic workoutData;

  const AiWorkoutPreviewScreen({Key? key, required this.workoutData})
    : super(key: key);

  @override
  State<AiWorkoutPreviewScreen> createState() => _AiWorkoutPreviewScreenState();
}

class _AiWorkoutPreviewScreenState extends State<AiWorkoutPreviewScreen> {
  // Флаг: сохранил ли юзер тренировку?
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final safeData = widget.workoutData ?? {};
    final workoutId = safeData['id']; // Достаем ID тренировки для удаления
    final title = safeData['title'] ?? safeData['Title'] ?? 'Тренировка';
    final description =
        safeData['description'] ?? safeData['Description'] ?? '';
    final List exercises = safeData['exercises'] ?? safeData['Exercises'] ?? [];

    const primaryGreen = Color(0xFF00E676);
    const cardColor = Color(0xFF1E1E1E);

    // PopScope позволяет перехватить нажатие кнопки "Назад" или жест смахивания
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!_isSaved && workoutId != null) {
          print('Отмена: физически удаляем черновик DELETE /workout/$workoutId?hard=true');
          
          // ДОБАВИЛИ ?hard=true ВОТ СЮДА:
          ApiClient().delete('/workout/$workoutId?hard=true');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text(
            'Ваша тренировка',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Шапка
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryGreen.withOpacity(0.3)),
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
              'Упражнения (нажми, чтобы узнать детали):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: primaryGreen,
                    collapsedIconColor: Colors.grey,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: primaryGreen,
                      ),
                    ),
                    title: Text(
                      exName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$sets подхода по $reps повторений',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
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
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            const Text(
                              'ТЕХНИКА:',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exDesc,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (muscleGroups['primary'] != null) ...[
                              const Text(
                                'РАБОЧИЕ МЫШЦЫ:',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                    backgroundColor: Colors.green,
                  ),
                );

                // Возвращаемся в меню
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Добавить в мои тренировки',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
