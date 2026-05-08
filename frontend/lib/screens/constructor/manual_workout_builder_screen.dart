import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../widgets/theme.dart'; 

class ManualWorkoutBuilderScreen extends StatefulWidget {
  const ManualWorkoutBuilderScreen({Key? key}) : super(key: key);

  @override
  State<ManualWorkoutBuilderScreen> createState() =>
      _ManualWorkoutBuilderScreenState();
}

class _ManualWorkoutBuilderScreenState
    extends State<ManualWorkoutBuilderScreen> {
  // Контроллеры для текстовых полей
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _duration = 45; // Время по умолчанию
  bool _isLoading = false;

  // Список выбранных упражнений
  final List<Map<String, dynamic>> _selectedExercises = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Метод сохранения тренировки на сервер
  Future<void> _saveWorkout() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название тренировки'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно упражнение'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      "title": _titleController.text.trim(),
      "description": _descController.text.trim(),
      "total_duration_est": _duration,
      "exercises": _selectedExercises
          .map((ex) => {"id": ex['id'], "sets": ex['sets'], "reps": ex['reps']})
          .toList(),
    };

    try {
      final response = await ApiClient().post('/workout', payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Тренировка успешно создана! 🎉'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context); // Возвращаемся назад
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

  // Модальное окно для выбора упражнений
  void _showAddExerciseModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface, // Темно-серая поверхность
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _fetchAllExercisesFromApi(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'База упражнений пуста',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            final exercises = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Выберите упражнение',
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
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final ex = exercises[index];
                      final exId = ex['id'];
                      final exName = ex['name'] ?? 'Без названия';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          exName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showSetsRepsDialog(exId, exName);
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

  Future<List<dynamic>> _fetchAllExercisesFromApi() async {
    try {
      final response = await ApiClient().get('/exercise/all');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      throw Exception('Ошибка сервера: ${response.statusCode}');
    } catch (e) {
      throw Exception('Проверьте подключение к сети');
    }
  }

  // Диалог настройки подходов и повторений
  void _showSetsRepsDialog(String exId, String exName) {
    int sets = 3;
    int reps = 12;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface, // Поверхность диалога
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Настроить:\n$exName',
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
                        'Подходы:',
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
                              () => sets = sets > 1 ? sets - 1 : 1,
                            ),
                          ),
                          Text(
                            '$sets',
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
                            onPressed: () => setDialogState(() => sets++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Повторения:',
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
                              () => reps = reps > 1 ? reps - 1 : 1,
                            ),
                          ),
                          Text(
                            '$reps',
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
                            onPressed: () => setDialogState(() => reps++),
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
                      _selectedExercises.add({
                        'id': exId,
                        'name': exName,
                        'sets': sets,
                        'reps': reps,
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Добавить',
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

  // Вспомогательный метод для полей ввода (Строгий стиль)
  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface, // Темно-серая заливка
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
          'Своя тренировка',
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
            // Поля ввода названия и описания
            TextField(
              controller: _titleController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: _inputStyle('Название тренировки (напр. День Ног)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: _inputStyle('Описание (опционально)'),
            ),
            const SizedBox(height: 24),

            // Выбор длительности
            const Text(
              'Примерное время (мин):',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 120,
              divisions: 7,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surface,
              label: '$_duration мин',
              onChanged: (val) => setState(() => _duration = val.toInt()),
            ),
            const SizedBox(height: 16),

            // Список выбранных упражнений
            const Text(
              'Упражнения:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedExercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surface),
                ),
                child: const Text(
                  'Вы еще не добавили упражнения',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            ..._selectedExercises.asMap().entries.map((entry) {
              int idx = entry.key;
              Map ex = entry.value;
              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    ex['name'],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${ex['sets']} подходов x ${ex['reps']} повторений',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () =>
                        setState(() => _selectedExercises.removeAt(idx)),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Кнопка добавления упражнения
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
                  'Добавить упражнение',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _showAddExerciseModal,
              ),
            ),
            const SizedBox(height: 40),

            // Кнопка сохранения
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white, // Белый текст вместо черного
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _saveWorkout,
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
                        'Сохранить тренировку',
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
