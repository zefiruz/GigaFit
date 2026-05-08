import 'dart:convert';
import 'package:flutter/material.dart';

// ТВОИ ИМПОРТЫ
import '../../services/api_client.dart';
import '../../widgets/theme.dart';

// ЭКРАНЫ
import 'ai_workout_preview_screen.dart';
import 'manual_workout_builder_screen.dart';
import 'manual_plan_builder_screen.dart';
import 'ai_plan_preview_screen.dart';
import 'catalog_screen.dart';

class WorkoutBuilderScreen extends StatelessWidget {
  const WorkoutBuilderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Конструктор',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'С чего начнем сегодня?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // БЛОК 1: МАГИЯ ИИ (Оливковый градиент)
            // ==========================================
            _buildAiBlock(context),
            const SizedBox(height: 32),

            const Text(
              'Классический подход',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // БЛОК 2: РУЧНОЙ РЕЖИМ (Строгий серый)
            // ==========================================
            _buildManualBlock(context),
            const SizedBox(height: 16),

            // ==========================================
            // БЛОК 3: БИБЛИОТЕКА (Стальной синий)
            // ==========================================
            _buildActionCard(
              context,
              title: 'Каталог программ',
              subtitle: 'Выбрать из готовых системных тренировок и планов',
              icon: Icons.view_list_rounded,
              color: AppColors.system,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CatalogScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ВИДЖЕТ: БЛОК ИИ (Оливковый)
  // ---------------------------------------------------------
  Widget _buildAiBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Тренер GigaFit (ИИ)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showAiWorkoutBottomSheet(context),
                      child: const Text(
                        'Тренировка',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.background.withOpacity(0.4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showAiPlanBottomSheet(context),
                      child: const Text(
                        'План на месяц',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
  // ВИДЖЕТ: БЛОК РУЧНОГО СОЗДАНИЯ (Светло-серый акцент)
  // ---------------------------------------------------------
  Widget _buildManualBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.personal.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                  Icon(Icons.build_circle, color: AppColors.personal, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Своя программа',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Соберите тренировку или долгосрочный план из базы упражнений вручную.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.personal,
                        foregroundColor: AppColors.background,
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
                                const ManualWorkoutBuilderScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Тренировка',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.personal.withOpacity(0.3),
                          ),
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
                      child: const Text(
                        'План на месяц',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
  // Универсальная карточка
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
      color: AppColors.card,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ЛОГИКА И ШТОРКИ ИИ
  // =========================================================

  Widget _buildChoiceChips(
    List<String> options,
    String currentSelection,
    Color activeColor,
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
          showCheckmark: false,
          selectedColor: activeColor.withOpacity(0.15),
          backgroundColor: AppColors.background,
          labelStyle: TextStyle(
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? activeColor : Colors.transparent,
            ),
          ),
          onSelected: (val) {
            if (val) onSelect(opt);
          },
        );
      }).toList(),
    );
  }

  // --- Шторка генерации ТРЕНИРОВКИ ---
  void _showAiWorkoutBottomSheet(BuildContext context) {
    String selectedPlace = 'Дома';
    String selectedTime = '45 минут';
    String selectedGoal = 'Рельеф';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Где тренируемся?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceChips(
                    ['Дома', 'В зале', 'На улице'],
                    selectedPlace,
                    AppColors.primary,
                    (v) => setState(() => selectedPlace = v),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Сколько есть времени?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceChips(
                    ['15 минут', '30 минут', '45 минут', '60 минут'],
                    selectedTime,
                    AppColors.primary,
                    (v) => setState(() => selectedTime = v),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Фокус на сегодня',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceChips(
                    ['Похудение', 'Рельеф', 'Масса', 'Тонизирование'],
                    selectedGoal,
                    AppColors.primary,
                    (v) => setState(() => selectedGoal = v),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              final promptGoal =
                                  'Место: $selectedPlace. Время: $selectedTime. Цель: $selectedGoal.';
                              try {
                                final response = await ApiClient().post(
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
                                    Navigator.pop(context);
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
                                    'Ошибка: ${response.statusCode}',
                                  );
                                }
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка: $e'),
                                      backgroundColor: AppColors.error,
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
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Сгенерировать',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

  // --- Шторка генерации ПЛАНА ---
  void _showAiPlanBottomSheet(BuildContext context) {
    String selectedGoal = 'Масса';
    int daysPerWeek = 3;
    int durationWeeks = 4;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Главная цель:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceChips(
                    ['Похудение', 'Рельеф', 'Масса', 'Выносливость'],
                    selectedGoal,
                    AppColors.system,
                    (v) => setState(() => selectedGoal = v),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Тренировок в неделю:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceChips(
                    ['2 дня', '3 дня', '4 дня', '5 дней'],
                    '$daysPerWeek ${daysPerWeek > 4 ? 'дней' : 'дня'}',
                    AppColors.system,
                    (v) => setState(
                      () => daysPerWeek = int.parse(v.split(' ')[0]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Продолжительность (недели):',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Slider(
                    value: durationWeeks.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 5,
                    activeColor: AppColors.system,
                    inactiveColor: AppColors.background,
                    label: '$durationWeeks нед.',
                    onChanged: (val) =>
                        setState(() => durationWeeks = val.toInt()),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.system,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                final response = await ApiClient().post(
                                  '/plan/ai',
                                  payload,
                                  timeout: const Duration(seconds: 90),
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
                                      backgroundColor: AppColors.error,
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
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Создать магию 🪄',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
