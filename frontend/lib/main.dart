import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Правильные относительные пути внутри папки lib/
import 'screens/login_screen.dart';
import 'widgets/theme.dart';

void main() async {
  // Эта строка обязательна, если мы используем await до вызова runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Получаем доступ к локальному хранилищу
  final prefs = await SharedPreferences.getInstance();

  // Ищем сохраненный токен
  final token = prefs.getString('jwt_token');

  // Определяем, какой экран показать первым.
  // Если токен есть и он не пустой — пускаем на MainScreen. Иначе — на LoginScreen.
  final Widget initialScreen = (token != null && token.isNotEmpty)
      ? const MainScreen()
      : const LoginScreen();

  // Запускаем приложение, передавая выбранный стартовый экран
  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  // Добавляем initialScreen в конструктор
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigaFit',
      theme: AppTheme.light, // Раскомментируй свою тему
      // theme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      //   useMaterial3: true,
      // ),
      // Устанавливаем экран, который мы определили в функции main()
      home: initialScreen,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Заглушки для твоих 5 экранов
  static const List<Widget> _widgetOptions = <Widget>[
    Center(child: Text('Блок 1: Конструктор тренировок')),
    Center(child: Text('Блок 2: Чат с ИИ')),
    Center(child: Text('Блок 3: Мои тренировки')),
    Center(child: Text('Блок 4: Лента')),
    Center(child: Text('Блок 5: Профиль')),
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
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType
            .fixed, // Позволяет отображать больше 3 иконок
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
