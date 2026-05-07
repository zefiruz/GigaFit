import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/chat_service.dart';
import '../../widgets/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  String? _currentSessionId;
  bool _isLoading = true;
  bool _isAITyping = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSession();
  }

  // 1. Пытаемся восстановить сессию из памяти телефона
  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('last_chat_session_id');

    if (savedId != null) {
      _currentSessionId = savedId;
      await _fetchHistory();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 2. Загружаем историю из бэкенда по ID сессии
  Future<void> _fetchHistory() async {
    if (_currentSessionId == null) return;

    final history = await _chatService.getHistory(_currentSessionId!);
    List<Map<String, dynamic>> tempMessages = [];

    for (var item in history) {
      if (item['prompt'] != null) {
        tempMessages.add({'text': item['prompt'], 'sender': 'user'});
      }
      // В твоем Go-коде ответ лежит в Response.Data["text"]
      if (item['response'] != null && item['response']['text'] != null) {
        tempMessages.add({'text': item['response']['text'], 'sender': 'ai'});
      }
    }

    setState(() {
      _messages = tempMessages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  // 3. Создание нового чата (сброс сессии)
  Future<void> _startNewChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_chat_session_id');
    setState(() {
      _currentSessionId = null;
      _messages = [];
    });
  }

  // 4. Отправка сообщения
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'sender': 'user'});
      _isAITyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final result = await _chatService.sendMessage(
      text,
      sessionId: _currentSessionId,
    );

    if (mounted && result != null) {
      // Если это был новый чат, сохраняем полученный от бэкенда ID
      if (_currentSessionId == null && result['session_id'] != null) {
        _currentSessionId = result['session_id'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_chat_session_id', _currentSessionId!);
      }

      setState(() {
        _isAITyping = false;
        _messages.add({'text': result['reply'], 'sender': 'ai'});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAdviceSheet() {
    int duration = 60;
    String mood = 'Хорошее';
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder( // StatefulBuilder нужен, чтобы менять состояние внутри шторки
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Анализ тренировки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                
                // Ползунок времени
                Text('Длительность: $duration мин.', style: const TextStyle(color: Colors.white70)),
                Slider(
                  value: duration.toDouble(),
                  min: 10, max: 180, divisions: 17,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setSheetState(() => duration = val.toInt()),
                ),
                
                // Выбор настроения
                const Text('Самочувствие:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['🔥 Отличное', '👍 Нормальное', '😫 Устал'].map((m) {
                    final isSelected = mood == m;
                    return ChoiceChip(
                      label: Text(m),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                      onSelected: (val) => setSheetState(() => mood = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Комментарий
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Краткий комментарий (что делали?)'),
                ),
                const SizedBox(height: 24),

                // Кнопка отправки
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Закрываем шторку
                    
                    // Показываем индикатор печати в чате
                    setState(() => _isAITyping = true);
                    _scrollToBottom();

                    // Идем в сеть за советом
                    final advice = await _chatService.getWorkoutAdvice(
                      duration, mood, commentController.text.trim(),
                    );

                    if (mounted) {
                      setState(() {
                        _isAITyping = false;
                        if (advice != null) {
                          _messages.add({'text': advice, 'sender': 'ai'});
                        } else {
                          _messages.add({'text': 'Не удалось получить совет. Попробуйте позже.', 'sender': 'system'});
                        }
                      });
                      _scrollToBottom();
                    }
                  },
                  child: const Text('Получить совет'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Тренер'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.primary),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildWelcomeMessage()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildBubble(_messages[index]),
                      ),
          ),
          if (_isAITyping) _buildTypingIndicator(),
          
          // НОВАЯ КНОПКА БЫСТРОГО ДЕЙСТВИЯ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.bolt, color: Colors.black, size: 16),
                label: const Text('Совет после тренировки', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.primary,
                onPressed: _showAdviceSheet,
              ),
            ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt, size: 64, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Задай любой вопрос по тренировкам',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isUser = msg['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: isUser ? Colors.black : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'GigaFit печатает...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Ваш вопрос...',
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.black),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
