import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/theme.dart';
import '../auth/login_screen.dart';

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
  bool _isInitialLoad = true;

  String? _aiAdvice;
  bool _isLoadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (_profileData == null) {
      setState(() => _isInitialLoad = true);
    }

    final results = await Future.wait([
      _profileService.getProfile(),
      _profileService.getProgress(),
    ]);

    if (mounted) {
      setState(() {
        _profileData = results[0] as Map<String, dynamic>?;

        final dynamic progressData = results[1];
        _weightHistory = [];

        if (progressData != null) {
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
          } else if (progressData is Map) {
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

  Future<void> _fetchAiAdvice() async {
    setState(() => _isLoadingAdvice = true);

    final advice = await _profileService.getAiAdvice();

    if (mounted) {
      setState(() {
        _aiAdvice = advice;
        _isLoadingAdvice = false;
      });

      // Если бэкенд вернул ошибку, показываем снекбар
      if (advice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось получить совет. Добавьте больше замеров!',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Фирменные инпуты
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputStyle('Вес (кг)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputStyle('Рост (см)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputStyle('Цель (например: Набор массы)'),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

                if (parsedWeight <= 0 || parsedHeight <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Вес и рост должны быть больше нуля'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                if (parsedGoal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пожалуйста, укажите вашу цель'),
                      backgroundColor: AppColors.error,
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
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text(
                'Сохранить',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Фирменный стиль полей
  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
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

  bool _checkIfDataMissing() {
    if (_profileData == null) return true;
    if (_profileData!['current_weight'] == null) return true;

    final weight =
        double.tryParse(_profileData!['current_weight'].toString()) ?? 0.0;
    return weight <= 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final bool isDataMissing = _checkIfDataMissing();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // При свайпе вниз сбрасываем старый совет и грузим профиль заново
          setState(() => _aiAdvice = null);
          await _loadAllData();
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 30),
              _buildStatsRow(),
              const SizedBox(height: 30),

              isDataMissing
                  ? _buildBigButton("Заполнить данные", true)
                  : _buildBigButton("Редактировать профиль", false),

              const SizedBox(height: 32),

              // 3. ВСТАВЛЯЕМ КАРТОЧКУ СОВЕТА ПРЯМО НАД ГРАФИКОМ
              if (!isDataMissing) // Показываем ИИ только если юзер заполнил вес
                _buildAiAdviceCard(),

              const SizedBox(height: 24),

              _buildProgressChart(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiAdviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                "СОВЕТ ОТ GIGAFIT AI",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingAdvice)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else if (_aiAdvice != null)
            Text(
              _aiAdvice!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            )
          else
            TextButton(
              onPressed: _fetchAiAdvice,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Проанализировать мой прогресс →",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
        ],
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
            backgroundColor: AppColors.surface,
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
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          _profileData?['email']?.toString() ?? '',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
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
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _showEditSheet,
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : OutlinedButton(
              onPressed: _showEditSheet,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  // --- МАГИЯ FL_CHART ЗДЕСЬ ---
  Widget _buildProgressChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Динамика веса",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.only(
            right: 20,
            left: 10,
            top: 24,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: _weightHistory.length < 2
              ? const Center(
                  child: Text(
                    "Добавьте вес хотя бы 2 раза,\nчтобы увидеть график",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false), // Прячем скучную сетку
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      // Оставляем только значения веса слева
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: false,
                    ), // Прячем рамки графика
                    lineBarsData: [
                      LineChartBarData(
                        // Превращаем массив веса в точки (X, Y)
                        spots: _weightHistory.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true, // Плавные изгибы!
                        color: AppColors.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true, // Показываем точки на графике
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.background,
                              strokeWidth: 2,
                              strokeColor: AppColors.primary,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          // Роскошный градиент под линией
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    // Интерактивные подсказки при нажатии
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (LineBarSpot touchedSpot) =>
                            AppColors.surface,

                        tooltipBorderRadius: BorderRadius.circular(12),

                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),

                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y} кг',
                              const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
