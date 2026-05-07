import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';

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

  // Список выбранных упражнений. Структура: { 'id': '...', 'name': '...', 'sets': 3, 'reps': 12 }
  final List<Map<String, dynamic>> _selectedExercises = [];

  // Цвета темы
  final Color primaryGreen = const Color(0xFF00E676);
  final Color bgColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);

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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно упражнение'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Собираем JSON ровно в том формате, который ждет Go бэкенд
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
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
          ); // Возвращаемся назад после успешного сохранения
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Модальное окно для "выбора" упражнения (заглушка для базы)
  // Модальное окно для выбора упражнений (Теперь из реальной БД!)
  void _showAddExerciseModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          // Здесь мы вызываем твой метод получения упражнений.
          // Если твой метод getAllExercises() лежит в каком-то классе (например ExerciseService),
          // то напиши ExerciseService().getAllExercises().
          // А пока я сделаю прямой вызов через твой ApiClient:
          future: _fetchAllExercisesFromApi(),
          builder: (context, snapshot) {
            // 1. Состояние: Загрузка
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              );
            }

            // 2. Состояние: Ошибка
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            // 3. Состояние: Пусто
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'База упражнений пуста',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            // 4. Состояние: Успех (Рисуем реальный список)
            final exercises = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index];

                // Безопасно достаем данные (подстрой под свои ключи JSON)
                final exId = ex['id'];
                final exName = ex['name'] ?? 'Без названия';
                // Если хочешь, можно еще выводить группу мышц:
                // final muscle = ex['muscle_groups']?['primary']?[0] ?? '';

                return ListTile(
                  title: Text(
                    exName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // subtitle: muscle.isNotEmpty ? Text(muscle, style: TextStyle(color: Colors.grey[500], fontSize: 12)) : null,
                  trailing: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF00E676),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Закрываем шторку
                    _showSetsRepsDialog(
                      exId,
                      exName,
                    ); // Спрашиваем подходы и повторения
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Добавь этот метод рядышком (или используй свой готовый getAllExercises, если он уже импортирован)
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
              backgroundColor: cardColor,
              title: Text(
                'Настроить: $exName',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Подходы:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () => setDialogState(
                              () => sets = sets > 1 ? sets - 1 : 1,
                            ),
                          ),
                          Text(
                            '$sets',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
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
                        style: TextStyle(color: Colors.white70),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () => setDialogState(
                              () => reps = reps > 1 ? reps - 1 : 1,
                            ),
                          ),
                          Text(
                            '$reps',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
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
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
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
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Вспомогательный метод для красивых полей ввода
  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Новая тренировка',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: _inputStyle('Название тренировки (напр. День Ног)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: _inputStyle('Описание (опционально)'),
            ),
            const SizedBox(height: 24),

            // Выбор длительности
            const Text(
              'Примерное время (мин):',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: _duration.toDouble(),
              min: 15,
              max: 120,
              divisions: 7,
              activeColor: primaryGreen,
              inactiveColor: Colors.white24,
              label: '$_duration мин',
              onChanged: (val) => setState(() => _duration = val.toInt()),
            ),
            const SizedBox(height: 16),

            // Список выбранных упражнений
            const Text(
              'Упражнения:',
              style: TextStyle(
                color: Colors.white,
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
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Вы еще не добавили упражнения',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),

            ..._selectedExercises.asMap().entries.map((entry) {
              int idx = entry.key;
              Map ex = entry.value;
              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    ex['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${ex['sets']} подходов x ${ex['reps']} повторений',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => setState(
                      () => _selectedExercises.removeAt(idx),
                    ), // Удаление упражнения
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
                  side: BorderSide(color: primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(Icons.add, color: primaryGreen),
                label: Text(
                  'Добавить упражнение',
                  style: TextStyle(color: primaryGreen, fontSize: 16),
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
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _saveWorkout,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Сохранить тренировку',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
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
