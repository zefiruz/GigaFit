import 'package:flutter/material.dart';
import '../../services/api_client.dart'; // Убедись в правильности пути

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

    const primaryGreen = Color(0xFF00E676);
    const cardColor = Color(0xFF1E1E1E);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // УМНОЕ УДАЛЕНИЕ: если юзер вышел и не сохранил план
        if (!_isSaved && planId != null) {
          print('Отмена плана: отправляем DELETE /plan/$planId');
          // Если на бэке есть хард-удаление для планов — добавь ?hard=true
          ApiClient().delete('/plan/$planId');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text(
            'Ваш новый план',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF121212),
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
                ), // Планы подсвечиваем фиолетовым/зеленым
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.purpleAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Длительность: $duration нед.',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Список тренировок в плане
            if (workouts.isEmpty)
              const Text(
                'ИИ не добавил тренировки :(',
                style: TextStyle(color: Colors.grey),
              ),

            ...workouts.map((w) {
              final week = w['week_number'] ?? w['WeekNumber'] ?? 1;
              final day = w['day_number'] ?? w['DayNumber'] ?? 1;

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
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
                  title: const Text(
                    'Тренировка',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Неделя $week, День $day',
                    style: TextStyle(color: Colors.grey[400]),
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
                setState(() => _isSaved = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('План добавлен в библиотеку! 🗓️'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Добавить в мои планы',
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
}
