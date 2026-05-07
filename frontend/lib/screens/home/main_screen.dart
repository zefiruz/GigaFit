import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import '../constructor/workout_builder_screen.dart';
import '../library/my_library_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const WorkoutBuilderScreen(),
    const ChatScreen(),
    const MyLibraryScreen(),
    const Center(child: Text('Блок 4: Лента')),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Конструктор',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'ИИ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Мои',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed),
            label: 'Лента',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
