import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../widgets/theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _profileData;
  List<double> _weightHistory = [];
  bool _isInitialLoad = true; // Заменили _isLoading на _isInitialLoad

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Включаем полноэкранную загрузку ТОЛЬКО при первом входе
    if (_profileData == null) {
      setState(() => _isInitialLoad = true);
    }

    // Загружаем профиль и историю веса параллельно
    final results = await Future.wait([
      _profileService.getProfile(),
      _profileService.getProgress(),
    ]);

    if (mounted) {
      setState(() {
        _profileData = results[0] as Map<String, dynamic>?;

        // --- 100% БЕЗОПАСНЫЙ ПАРСИНГ ГРАФИКА ---
        final dynamic progressData =
            results[1]; // Используем dynamic, чтобы Flutter не ругался на типы заранее
        _weightHistory = [];

        // Сначала проверяем, что данные вообще пришли (не null)
        if (progressData != null) {
          // Проверяем, является ли это списком (массивом)
          if (progressData is List) {
            for (var item in progressData) {
              if (item is Map && item['weight'] != null) {
                _weightHistory.add(
                  double.tryParse(item['weight'].toString()) ?? 0.0,
                );
              } else {
                _weightHistory.add(double.tryParse(item.toString()) ?? 0.0);
              }
            }
          }
          // Проверяем, является ли это словарем (Map)
          else if (progressData is Map) {
            // Безопасно проверяем ключ
            if (progressData['weight_history'] != null) {
              final historyList = progressData['weight_history'];
              if (historyList is List) {
                _weightHistory = List<double>.from(
                  historyList.map((e) => double.tryParse(e.toString()) ?? 0.0),
                );
              }
            }
          }
        }

        _isInitialLoad = false;
      });
    }
  }

  // Вызов шторки редактирования
  void _showEditSheet() {
    final weightValue = _profileData?['current_weight'] ?? '';
    final heightValue = _profileData?['current_height'] ?? '';
    final goalValue = _profileData?['goal'] ?? '';

    final weightController = TextEditingController(
      text: weightValue.toString(),
    );
    final heightController = TextEditingController(
      text: heightValue.toString(),
    );
    final goalController = TextEditingController(text: goalValue.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ваши параметры',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Вес (кг)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Рост (см)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Цель (например: Набор массы)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();

                final parsedWeight =
                    double.tryParse(
                      weightController.text.replaceAll(',', '.'),
                    ) ??
                    0;
                final parsedHeight =
                    double.tryParse(
                      heightController.text.replaceAll(',', '.'),
                    ) ??
                    0;
                final parsedGoal = goalController.text.trim();

                // Проверка как на твоем Go-бэкенде!
                if (parsedWeight <= 0 || parsedHeight <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Вес и рост должны быть больше нуля'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (parsedGoal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пожалуйста, укажите вашу цель'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final success = await _profileService.updateAnthropometry(
                  weight: parsedWeight,
                  height: parsedHeight,
                  goal: parsedGoal,
                );

                if (success && mounted) {
                  Navigator.pop(context);
                  await _loadAllData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка сервера. Попробуйте еще раз.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // БЕЗОПАСНАЯ ПРОВЕРКА ДАННЫХ
  bool _checkIfDataMissing() {
    if (_profileData == null) return true;
    if (_profileData!['current_weight'] == null) return true;

    // Превращаем то, что прислал Go (string, int, double) в Double
    final weight = double.tryParse(_profileData!['current_weight'].toString()) ?? 0.0;
    return weight <= 0; // Если вес 0 или меньше, значит данные не заполнены
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDataMissing = _checkIfDataMissing();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GIGAFIT PRO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () async {
              await _authService.logout();
              if (mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData, // Теперь это работает плавно!
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Важно для работы RefreshIndicator
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 30),
              _buildStatsRow(),
              const SizedBox(height: 30),

              // Динамическая кнопка
              isDataMissing
                  ? _buildBigButton("Заполнить данные", true)
                  : _buildBigButton("Редактировать профиль", false),

              const SizedBox(height: 40),
              _buildProgressChart(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profileData?['username']?.toString() ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: CircleAvatar(
            radius: 45,
            backgroundColor: AppColors.card,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 32,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          _profileData?['email']?.toString() ?? '',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    // Теперь используем правильные ключи: current_weight и current_height
    final weight = _profileData?['current_weight'] ?? '--';
    final height = _profileData?['current_height'] ?? '--';
    final goal = _profileData?['goal'] ?? '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statCard("Вес", "$weight", "кг"),
        _statCard("Рост", "$height", "см"),
        _statCard(
          "Цель",
          goal.toString().isNotEmpty ? goal.toString() : "Не задана",
          "",
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  " $unit",
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton(String text, bool isPrimary) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(onPressed: _showEditSheet, child: Text(text))
          : OutlinedButton(
              onPressed: _showEditSheet,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(text),
            ),
    );
  }

  Widget _buildProgressChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Прогресс веса",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Container(
          height: 180,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _weightHistory.length < 2
              ? const Center(
                  child: Text(
                    "Недостаточно данных для графика",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : CustomPaint(painter: WeightChartPainter(_weightHistory)),
        ),
      ],
    );
  }
}

// РИСОВАЛЬЩИК ГРАФИКА
class WeightChartPainter extends CustomPainter {
  final List<double> data;
  WeightChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    double maxW = data.reduce((a, b) => a > b ? a : b) + 5;
    double minW = data.reduce((a, b) => a < b ? a : b) - 5;
    double range = maxW - minW;
    if (range == 0)
      range = 1; // Предотвращаем деление на ноль, если вес не менялся

    for (int i = 0; i < data.length; i++) {
      double x = (size.width / (data.length - 1)) * i;
      double y = size.height - ((data[i] - minW) / range) * size.height;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
