import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import '../constructor/workout_builder_screen.dart';
import '../library/my_library_screen.dart';
import '../../widgets/theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Список экранов остается прежним
  static final List<Widget> _widgetOptions = <Widget>[
    const WorkoutBuilderScreen(),
    const ChatScreen(),
    const MyLibraryScreen(),
    const Center(
      child: Text('Блок 4: Лента', style: TextStyle(color: Colors.white)),
    ),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _widgetOptions.elementAt(_selectedIndex),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.3),
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: GNav(
              rippleColor: Colors.transparent,
              hoverColor: Colors.transparent,
              gap: 4,
              activeColor: Colors.white,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppColors.primary.withOpacity(
                0.2,
              ),
              color: AppColors.textSecondary,
              tabs: const [
                GButton(icon: Icons.build_rounded, text: 'Конструктор'),
                GButton(icon: Icons.smart_toy_rounded, text: 'ИИ'),
                GButton(icon: Icons.fitness_center_rounded, text: 'Мои'),
                GButton(icon: Icons.dynamic_feed_rounded, text: 'Лента'),
                GButton(icon: Icons.person_rounded, text: 'Профиль'),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
