import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    Center(child: Text('Блок 1: Конструктор тренировок')),
    ChatScreen(),
    Center(child: Text('Блок 3: Мои тренировки')),
    Center(child: Text('Блок 4: Лента')),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GigaFit'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Чтобы влезло больше 3 иконок
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Конструктор',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy), 
            label: 'ИИ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Мои',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed),
            label: 'Лента',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}