import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'ai_workout_preview_screen.dart';
import 'manual_workout_builder_screen.dart';

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
            // БЛОК 2: БИБЛИОТЕКА ПРОГРАММ
            // ==========================================
            _buildActionCard(
              context,
              title: 'Библиотека программ',
              subtitle: 'Выбрать из готовых тренировок и планов',
              icon: Icons.view_list_rounded,
              color: Colors.blueAccent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Открываем библиотеку...')),
                );
              },
            ),
            const SizedBox(height: 16),

            // ==========================================
            // БЛОК 3: РУЧНОЙ РЕЖИМ
            // ==========================================
            _buildActionCard(
              context,
              title: 'Создать свою тренировку',
              subtitle: 'Собрать программу из базы упражнений с нуля',
              icon: Icons.build_circle_outlined,
              color: Colors.orangeAccent,
              onTap: () {
                // ВМЕСТО SnackBar ПРОСТО ПЕРЕХОДИМ НА НОВЫЙ ЭКРАН:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualWorkoutBuilderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Виджет для градиентного блока ИИ (Темно-зеленый градиент)
  Widget _buildAiBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF004D40),
            Color(0xFF00C853),
          ], // Темно-изумрудный к ярко-зеленому
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
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.black, size: 28),
                  const SizedBox(width: 12),
                  const Text(
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
                        foregroundColor:
                            Colors.black, // Черный текст на белом/зеленом
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
                      onPressed: () {},
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

  // Универсальная карточка (Темная)
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
            // Вспомогательный виджет для кнопок выбора (Chips)
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

                  // Кнопка отправки
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryGreen,
                        foregroundColor:
                            Colors.black, // Черный текст на зеленом
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);

                              // Формируем промпт для бэкенда
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
                                              // Двойная защита: если data пустая, передаем весь ответ целиком
                                              workoutData:
                                                  responseData['data'] ??
                                                  responseData,
                                            ),
                                      ),
                                    );
                                  }
                                } else {
                                  throw Exception(
                                    'СЕРВЕР ВЕРНУЛ ОШИБКУ: ${response.statusCode} - ${response.body}',
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка: $e'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
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
}
