import 'package:flutter/material.dart';
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
    } else {
      setState(() => _isAITyping = false);
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

  // Строгий стиль инпутов, как на остальных экранах
  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  void _showAdviceSheet() {
    int duration = 60;
    String mood = 'Хорошее';
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface, // Темно-серый строгий фон
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Анализ тренировки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                
                // Ползунок времени
                Text('Длительность: $duration мин.', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Slider(
                  value: duration.toDouble(),
                  min: 10, max: 180, divisions: 17,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.background,
                  onChanged: (val) => setSheetState(() => duration = val.toInt()),
                ),
                const SizedBox(height: 16),
                
                // Выбор настроения
                const Text('Самочувствие:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['🔥 Отличное', '👍 Нормальное', '😫 Устал'].map((m) {
                    final isSelected = mood == m;
                    return ChoiceChip(
                      label: Text(m),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      backgroundColor: AppColors.background,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) => setSheetState(() => mood = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Комментарий (используем нашу премиум-форму)
                TextField(
                  controller: commentController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputStyle('Краткий комментарий (что делали?)'),
                ),
                const SizedBox(height: 32),

                // Кнопка отправки
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white, // Белый текст
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    setState(() => _isAITyping = true);
                    _scrollToBottom();

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
                  child: const Text('Получить совет', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 32),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Тренер', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.primary),
            onPressed: _startNewChat,
            tooltip: 'Новый чат',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
          
          // Кнопка быстрого действия
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.bolt, color: Colors.white, size: 18),
                label: const Text('Совет после тренировки', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.primary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          Icon(Icons.bolt, size: 72, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'Задай любой вопрос\nпо фитнесу или питанию',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isUser = msg['sender'] == 'user';
    bool isSystem = msg['sender'] == 'system';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8, // Баббл не будет растягиваться на весь экран
        ),
        decoration: BoxDecoration(
          color: isSystem 
              ? AppColors.error.withOpacity(0.2) 
              : (isUser ? AppColors.primary : AppColors.card),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null, // Аккуратный хвостик
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: isSystem ? Border.all(color: AppColors.error.withOpacity(0.5)) : null,
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: isSystem ? AppColors.error : (isUser ? Colors.white : AppColors.textPrimary),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'GigaFit печатает...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.card, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ваш вопрос...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), // Круглый инпут в чате смотрится лучше
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}