import 'dart:convert';
import 'package:flutter/material.dart';
import '/../services/api_client.dart'; 

class ManualPlanBuilderScreen extends StatefulWidget {
  const ManualPlanBuilderScreen({Key? key}) : super(key: key);

  @override
  State<ManualPlanBuilderScreen> createState() => _ManualPlanBuilderScreenState();
}

class _ManualPlanBuilderScreenState extends State<ManualPlanBuilderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  int _durationWeeks = 4; // По умолчанию план на месяц
  bool _isPublic = false;
  bool _isLoading = false;

  // Список добавленных в план тренировок
  // Структура: { 'id': '...', 'title': '...', 'week': 1, 'day': 3 }
  final List<Map<String, dynamic>> _selectedWorkouts = [];

  final Color primaryGreen = const Color(0xFF00E676);
  final Color bgColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);

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
        const SnackBar(content: Text('Введите название плана'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну тренировку в план'), backgroundColor: Colors.red),
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
      "workouts": _selectedWorkouts.map((w) => {
        "workout_id": w['id'],
        "week_number": w['week'],
        "day_number": w['day'],
      }).toList(),
    };

    try {
      // ПРОВЕРЬ: убедись, что твоя ручка в RouteGroup называется именно /plan (метод POST)
      final response = await ApiClient().post('/plan', payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('План успешно создан! 🚀'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); 
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

  // Выбор тренировки из библиотеки
  void _showAddWorkoutModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _fetchMyWorkouts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryGreen));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('У вас нет сохраненных тренировок. Сначала создайте тренировку!', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ),
              );
            }

            final workouts = snapshot.data!;

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Выберите тренировку:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: workouts.length,
                    itemBuilder: (context, index) {
                      final w = workouts[index];
                      final wId = w['id'];
                      final wTitle = w['title'] ?? 'Без названия';
                      final isAi = w['is_ai_generated'] ?? false;

                      return ListTile(
                        leading: Icon(isAi ? Icons.auto_awesome : Icons.sports_gymnastics, color: isAi ? primaryGreen : Colors.white70),
                        title: Text(wTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: Icon(Icons.add_circle_outline, color: primaryGreen),
                        onTap: () {
                          Navigator.pop(context); // Закрыли список
                          _showAssignDayDialog(wId, wTitle); // Открыли диалог назначения дня
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
              backgroundColor: cardColor,
              title: Text('Назначить: $wTitle', style: const TextStyle(color: Colors.white, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Неделя:', style: TextStyle(color: Colors.white70)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () => setDialogState(() => selectedWeek = selectedWeek > 1 ? selectedWeek - 1 : 1)),
                          Text('$selectedWeek', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => setDialogState(() => selectedWeek = selectedWeek < _durationWeeks ? selectedWeek + 1 : _durationWeeks)),
                        ],
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('День (1-7):', style: TextStyle(color: Colors.white70)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () => setDialogState(() => selectedDay = selectedDay > 1 ? selectedDay - 1 : 1)),
                          Text('$selectedDay', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => setDialogState(() => selectedDay = selectedDay < 7 ? selectedDay + 1 : 7)),
                        ],
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
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
                        if (a['week'] == b['week']) return a['day'].compareTo(b['day']);
                        return a['week'].compareTo(b['week']);
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Добавить в план', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryGreen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Новый план', style: TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: _inputStyle('Название плана (напр. На массу)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: _inputStyle('Описание (опционально)'),
            ),
            const SizedBox(height: 24),

            const Text('Продолжительность (недели):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Slider(
              value: _durationWeeks.toDouble(),
              min: 1, max: 12, divisions: 11,
              activeColor: primaryGreen, inactiveColor: Colors.white24,
              label: '$_durationWeeks нед.',
              onChanged: (val) {
                setState(() => _durationWeeks = val.toInt());
                // Опционально: можно удалять тренировки, если они вылезли за пределы новой длительности
              },
            ),
            
            // Переключатель публичности
            SwitchListTile(
              title: const Text('Сделать публичным', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Другие смогут найти этот план', style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: primaryGreen,
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              onChanged: (val) => setState(() => _isPublic = val),
            ),
            const SizedBox(height: 16),

            const Text('Расписание тренировок:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_selectedWorkouts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Text('Вы еще не добавили тренировки', style: TextStyle(color: Colors.grey[500])),
              ),

            ..._selectedWorkouts.asMap().entries.map((entry) {
              int idx = entry.key;
              Map w = entry.value;
              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryGreen.withOpacity(0.2),
                    child: Text('${w['day']}', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(w['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Неделя ${w['week']}, День ${w['day']}', style: TextStyle(color: Colors.grey[400])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => setState(() => _selectedWorkouts.removeAt(idx)),
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
                  side: BorderSide(color: primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(Icons.add, color: primaryGreen),
                label: Text('Добавить из моих тренировок', style: TextStyle(color: primaryGreen, fontSize: 16)),
                onPressed: _showAddWorkoutModal,
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _savePlan,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Сохранить план', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}