import 'package:flutter/material.dart';
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
    final List workouts = safeData['workouts'] ?? safeData['Workouts'] ?? [];

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
                borderRadius: BorderRadius.circular(16), // Строгие углы
                border: Border.all(
                  color: AppColors.system.withOpacity(0.3), // Синий акцент для планов
                ), 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.system,
                      ),
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

            // Список тренировок в плане
            if (workouts.isEmpty)
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

            ...workouts.map((w) {
              final week = w['week_number'] ?? w['WeekNumber'] ?? 1;
              final day = w['day_number'] ?? w['DayNumber'] ?? 1;

              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.system.withOpacity(0.15),
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        color: AppColors.system,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: const Text(
                    'Тренировка',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Неделя $week, День $day',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Кнопка сохранения
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.system, // Используем системный цвет для планов
                foregroundColor: Colors.white, // Белый текст
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() => _isSaved = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('План добавлен в библиотеку! 🗓️'),
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
}