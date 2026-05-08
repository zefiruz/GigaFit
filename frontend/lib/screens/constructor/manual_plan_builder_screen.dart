import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../widgets/theme.dart';

class ManualPlanBuilderScreen extends StatefulWidget {
  const ManualPlanBuilderScreen({Key? key}) : super(key: key);

  @override
  State<ManualPlanBuilderScreen> createState() =>
      _ManualPlanBuilderScreenState();
}

class _ManualPlanBuilderScreenState extends State<ManualPlanBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _durationWeeks = 4; // По умолчанию план на месяц
  bool _isPublic = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _selectedWorkouts = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Загружаем сохраненные тренировки пользователя из его библиотеки
  Future<List<dynamic>> _fetchMyWorkouts() async {
    try {
      final response = await ApiClient().get('/workout/all');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      throw Exception('Ошибка сервера: ${response.statusCode}');
    } catch (e) {
      throw Exception('Проверьте подключение к сети');
    }
  }

  Future<void> _savePlan() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название плана'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одну тренировку в план'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Собираем payload строго по структуре твоего Go-кода
    final payload = {
      "title": _titleController.text.trim(),
      "description": _descController.text.trim(),
      "is_public": _isPublic,
      "duration_weeks": _durationWeeks,
      "workouts": _selectedWorkouts
          .map(
            (w) => {
              "workout_id": w['id'],
              "week_number": w['week'],
              "day_number": w['day'],
            },
          )
          .toList(),
    };

    try {
      final response = await ApiClient().post('/plan', payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('План успешно создан! 🚀'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Выбор тренировки из библиотеки
  void _showAddWorkoutModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface, // Строгий фон шторки
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _fetchMyWorkouts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'У вас нет сохраненных тренировок. Сначала создайте тренировку!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            final workouts = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Выберите тренировку',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: workouts.length,
                    itemBuilder: (context, index) {
                      final w = workouts[index];
                      final wId = w['id'];
                      final wTitle = w['title'] ?? 'Без названия';
                      final isAi = w['is_ai_generated'] ?? false;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Icon(
                          isAi ? Icons.auto_awesome : Icons.sports_gymnastics,
                          color: isAi
                              ? AppColors.primary
                              : AppColors
                                    .personal, // ИИ - оливковый, свои - серые
                        ),
                        title: Text(
                          wTitle,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          Navigator.pop(context); // Закрыли список
                          _showAssignDayDialog(
                            wId,
                            wTitle,
                          ); // Открыли диалог назначения дня
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Диалог: на какую неделю и день ставим тренировку?
  void _showAssignDayDialog(String wId, String wTitle) {
    int selectedWeek = 1;
    int selectedDay = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface, // Строгий фон диалога
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Назначить:\n$wTitle',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Неделя:',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              color: AppColors.primary,
                            ),
                            onPressed: () => setDialogState(
                              () => selectedWeek = selectedWeek > 1
                                  ? selectedWeek - 1
                                  : 1,
                            ),
                          ),
                          Text(
                            '$selectedWeek',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onPressed: () => setDialogState(
                              () => selectedWeek = selectedWeek < _durationWeeks
                                  ? selectedWeek + 1
                                  : _durationWeeks,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'День (1-7):',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              color: AppColors.primary,
                            ),
                            onPressed: () => setDialogState(
                              () => selectedDay = selectedDay > 1
                                  ? selectedDay - 1
                                  : 1,
                            ),
                          ),
                          Text(
                            '$selectedDay',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onPressed: () => setDialogState(
                              () => selectedDay = selectedDay < 7
                                  ? selectedDay + 1
                                  : 7,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedWorkouts.add({
                        'id': wId,
                        'title': wTitle,
                        'week': selectedWeek,
                        'day': selectedDay,
                      });
                      // Сортируем список по неделе, затем по дню (для красоты)
                      _selectedWorkouts.sort((a, b) {
                        if (a['week'] == b['week'])
                          return a['day'].compareTo(b['day']);
                        return a['week'].compareTo(b['week']);
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Добавить в план',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Строгий стиль инпутов
  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Новый план',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: _inputStyle('Название плана (напр. На массу)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: _inputStyle('Описание (опционально)'),
            ),
            const SizedBox(height: 24),

            const Text(
              'Продолжительность (недели):',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Slider(
              value: _durationWeeks.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surface,
              label: '$_durationWeeks нед.',
              onChanged: (val) {
                setState(() => _durationWeeks = val.toInt());
              },
            ),

            // Переключатель публичности
            SwitchListTile(
              title: const Text(
                'Сделать публичным',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Другие смогут найти этот план',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              onChanged: (val) => setState(() => _isPublic = val),
            ),
            const SizedBox(height: 16),

            const Text(
              'Расписание тренировок:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedWorkouts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surface),
                ),
                child: const Text(
                  'Вы еще не добавили тренировки',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            ..._selectedWorkouts.asMap().entries.map((entry) {
              int idx = entry.key;
              Map w = entry.value;
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      '${w['day']}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    w['title'],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Неделя ${w['week']}, День ${w['day']}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () =>
                        setState(() => _selectedWorkouts.removeAt(idx)),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text(
                  'Добавить из моих тренировок',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _showAddWorkoutModal,
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white, // Белый текст!
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _savePlan,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Сохранить план',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
