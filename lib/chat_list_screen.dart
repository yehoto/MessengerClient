import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'chat_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int userId;

  ChatListScreen({required this.userId});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> chats = [];
  bool isLoading = true;
  double _chatListWidth = 300; // Начальная ширина списка чатов
  int? _selectedChatId; // ID выбранного чата

  // Проверка платформы
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get isDesktopOrWeb => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/chats?user_id=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print("Ответ от серверааа: $responseBody");

        if (responseBody != null && responseBody.isNotEmpty) {
          final decodedResponse = json.decode(responseBody);
          setState(() {
            chats = decodedResponse is List ? decodedResponse : [];
            isLoading = false;
          });
        } else {
          setState(() {
            chats = [];
            isLoading = false;
          });
        }
      } else {
        print("Ошибка: ${response.statusCode}");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Исключение: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Верхняя панель для мобильных устройств
  AppBar _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.deepPurple,
      elevation: 4,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () {
              // Переход в профиль
            },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewChatScreen(userId: widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Поиск чатов
            },
          ),
        ],
      ),
    );
  }

  // Верхняя часть списка чатов для ПК/веб
  Widget _buildDesktopChatListHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.person, color: Colors.deepPurple),
                onPressed: () {
                  // Переход в профиль
                },
              ),
              IconButton(
                icon: Icon(Icons.search, color: Colors.deepPurple),
                onPressed: () {
                  // Поиск чатов
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[300]),
      ],
    );
  }

  // Нижняя часть списка чатов для ПК/веб
  Widget _buildDesktopChatListFooter() {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewChatScreen(userId: widget.userId),
                ),
              );
            },
            child: Text('Создать чат'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  // Макет для десктоп/веб
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Список чатов
        Container(
          width: _chatListWidth,
          child: Column(
            children: [
              _buildDesktopChatListHeader(),
              Expanded(
                child: chats.isEmpty
                    ? Center(
                  child: Text(
                    'Чатов пока нет',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Text((index + 1).toString()),
                      ),
                      title: Text(chat['username'] ?? 'Новый чат'), // Имя пользователя
                      subtitle: Text(chat['lastMessage'] ?? ''), // Последнее сообщение
                      trailing: chat['unread'] > 0
                          ? CircleAvatar(
                        radius: 12,
                        child: Text(chat['unread'].toString()),
                      )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedChatId = chat['id'];
                        });
                      },
                    );
                  },
                ),
              ),
              _buildDesktopChatListFooter(),
            ],
          ),
        ),

        // Вертикальный разделитель
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _chatListWidth += details.delta.dx;
              if (_chatListWidth < 100) _chatListWidth = 100; // Минимальная ширина
              if (_chatListWidth > 400) _chatListWidth = 400; // Максимальная ширина
            });
          },
          child: Container(
            width: 8,
            color: Colors.grey[300],
          ),
        ),

        // Выбранный чат
        Expanded(
          child: _selectedChatId == null
              ? Center(
            child: Text(
              'Выберите чат',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
              : ChatScreen(
            chatId: _selectedChatId!,
            username: chats.firstWhere((chat) => chat['id'] == _selectedChatId)['username'], // Получаем имя пользователя
            currentUserId: widget.userId, // Передаем ID текущего пользователя
          ),
        ),
      ],
    );
  }

  // Макет для мобильных устройств
  Widget _buildMobileLayout() {
    return chats.isEmpty
        ? Center(
      child: Text(
        'Чатов пока нет',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    )
        : ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final chatId = chat['id'] as int?; // Проверка на null
        final username = chat['username'] as String? ?? 'Новый чат'; // Проверка на null
        final lastMessage = chat['lastMessage'] as String? ?? ''; // Проверка на null
        final unread = chat['unread'] as int? ?? 0; // Проверка на null

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Text((index + 1).toString()),
          ),
          title: Text(username),
          subtitle: Text(lastMessage),
          trailing: unread > 0
              ? CircleAvatar(
            radius: 12,
            child: Text(unread.toString()),
          )
              : null,
          onTap: () {
            if (chatId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    username: username,
                    currentUserId: widget.userId,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isMobile ? _buildMobileAppBar() : null,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : isDesktopOrWeb ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
}