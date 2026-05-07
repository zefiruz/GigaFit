import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'ai_workout_preview_screen.dart';

import 'manual_workout_builder_screen.dart';
import 'manual_plan_builder_screen.dart';
import 'ai_plan_preview_screen.dart';

class WorkoutBuilderScreen extends StatelessWidget {
  const WorkoutBuilderScreen({Key? key}) : super(key: key);

  final Color bgColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);
  final Color primaryGreen = const Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Конструктор',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'С чего начнем сегодня?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // БЛОК 1: МАГИЯ ИИ (Нейросеть)
            // ==========================================
            _buildAiBlock(context),
            const SizedBox(height: 32),

            const Text(
              'Классический подход',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // БЛОК 2: РУЧНОЙ РЕЖИМ (Своя программа)
            // ==========================================
            _buildManualBlock(context),
            const SizedBox(height: 16),

            // ==========================================
            // БЛОК 3: БИБЛИОТЕКА (Готовые решения)
            // ==========================================
            _buildActionCard(
              context,
              title: 'Библиотека программ',
              subtitle: 'Выбрать из готовых тренировок и планов',
              icon: Icons.view_list_rounded,
              color: Colors.blueAccent,
              onTap: () {
                // TODO: Переход в общую библиотеку GigaFit (не личную)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Открываем библиотеку...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ВИДЖЕТ: БЛОК ИИ (Зеленый градиент)
  // ---------------------------------------------------------
  Widget _buildAiBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.black, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Тренер GigaFit (ИИ)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Нейросеть создаст идеальную программу под ваши параметры и цели.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showAiWorkoutBottomSheet(context),
                      child: const Text(
                        'Тренировка',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showAiPlanBottomSheet(context),
                      child: const Text('План на месяц'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ВИДЖЕТ: БЛОК РУЧНОГО СОЗДАНИЯ (Огненный градиент)
  // ---------------------------------------------------------
  Widget _buildManualBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFBF360C),
            Color(0xFFFF6D00),
          ], // Глубокий красный в ярко-оранжевый
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.build_circle, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Своя программа',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Соберите тренировку или долгосрочный план из базы упражнений вручную.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ManualWorkoutBuilderScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Тренировка',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
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
                                const ManualPlanBuilderScreen(),
                          ),
                        );
                      },
                      child: const Text('План на месяц'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Универсальная карточка (Для библиотеки)
  // ---------------------------------------------------------
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Логика шторки ИИ (Осталась без изменений)
  // ---------------------------------------------------------
  void _showAiWorkoutBottomSheet(BuildContext context) {
    String selectedPlace = 'Дома';
    String selectedTime = '45 минут';
    String selectedGoal = 'Рельеф';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor, // Темный фон шторки
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Widget buildChoiceChips(
              List<String> options,
              String currentSelection,
              Function(String) onSelect,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = currentSelection == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: isSelected,
                    selectedColor: primaryGreen.withOpacity(0.2),
                    backgroundColor: bgColor,
                    labelStyle: TextStyle(
                      color: isSelected ? primaryGreen : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? primaryGreen : Colors.transparent,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) onSelect(opt);
                    },
                  );
                }).toList(),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Настройте тренировку',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Где тренируемся?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildChoiceChips(
                    ['Дома', 'В зале', 'На улице'],
                    selectedPlace,
                    (v) => setState(() => selectedPlace = v),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Сколько есть времени?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildChoiceChips(
                    ['15 минут', '30 минут', '45 минут', '60 минут'],
                    selectedTime,
                    (v) => setState(() => selectedTime = v),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Фокус на сегодня',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildChoiceChips(
                    ['Похудение', 'Рельеф', 'Масса', 'Тонизирование'],
                    selectedGoal,
                    (v) => setState(() => selectedGoal = v),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              final promptGoal =
                                  'Место: $selectedPlace. Время: $selectedTime. Цель: $selectedGoal.';

                              try {
                                final client = ApiClient();
                                final response = await client.post(
                                  '/workout/ai',
                                  {'goal': promptGoal},
                                  timeout: const Duration(seconds: 60),
                                );

                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  final responseData = jsonDecode(
                                    response.body,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context); // Закрываем шторку
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AiWorkoutPreviewScreen(
                                              workoutData:
                                                  responseData['data'] ??
                                                  responseData,
                                            ),
                                      ),
                                    );
                                  }
                                } else {
                                  throw Exception(
                                    'Ошибка: ${response.statusCode} - ${response.body}',
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Сгенерировать',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAiPlanBottomSheet(BuildContext context) {
    String selectedGoal = 'Масса';
    int daysPerWeek = 3;
    int durationWeeks = 4;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Виджет кнопок
            Widget buildChoiceChips(
              List<String> options,
              String currentSelection,
              Function(String) onSelect,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = currentSelection == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: isSelected,
                    selectedColor: Colors.purpleAccent.withOpacity(
                      0.2,
                    ), // Для плана цвет фиолетовый
                    backgroundColor: bgColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.purpleAccent : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.purpleAccent
                            : Colors.transparent,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) onSelect(opt);
                    },
                  );
                }).toList(),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сгенерировать План',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Главная цель:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildChoiceChips(
                    ['Похудение', 'Рельеф', 'Масса', 'Выносливость'],
                    selectedGoal,
                    (v) => setState(() => selectedGoal = v),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Тренировок в неделю:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  buildChoiceChips(
                    ['2 дня', '3 дня', '4 дня', '5 дней'],
                    '$daysPerWeek ${daysPerWeek > 4 ? 'дней' : 'дня'}', // Подгон под строку
                    (v) => setState(
                      () => daysPerWeek = int.parse(v.split(' ')[0]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Продолжительность (недели):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Slider(
                    value: durationWeeks.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 5,
                    activeColor: Colors.purpleAccent,
                    inactiveColor: Colors.white24,
                    label: '$durationWeeks нед.',
                    onChanged: (val) =>
                        setState(() => durationWeeks = val.toInt()),
                  ),
                  const SizedBox(height: 32),

                  // Кнопка генерации
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);

                              final payload = {
                                'goal': selectedGoal,
                                'days_per_week': daysPerWeek,
                                'duration_weeks': durationWeeks,
                              };

                              try {
                                // ПРОВЕРЬ: убедись, что твоя ручка называется /plan/ai
                                final response = await ApiClient().post(
                                  '/plan/ai', // <--- ТВОЙ ЭНДПОИНТ ИЗ GO
                                  payload,
                                  timeout: const Duration(
                                    seconds: 90,
                                  ), // ИИ для планов думает дольше!
                                );

                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  final responseData = jsonDecode(
                                    response.body,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AiPlanPreviewScreen(
                                              planData:
                                                  responseData['data'] ??
                                                  responseData,
                                            ),
                                      ),
                                    );
                                  }
                                } else {
                                  throw Exception(
                                    'Ошибка: ${response.statusCode}',
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка ИИ: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Создать магию 🪄',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
