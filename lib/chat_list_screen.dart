import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'profile_menu.dart';

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

  // Ключ для управления состоянием Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Проверка платформы
  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get isDesktopOrWeb => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  void initState() {
    super.initState();
    _loadChats();
    // Подключаемся к WebSocket для обновлений
    //final channel = WebSocketChannel.connect(Uri.parse('ws://192.168.0.106:8080/ws'));
    //final channel = WebSocketChannel.connect(Uri.parse('ws://192.168.0.106:8080/ws'));
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.106:8080/ws?user_id=${widget.userId}'),
    );
    channel.stream.listen((message) {
      _loadChats(); // При любом сообщении обновляем чаты
    });
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

  Future<Uint8List?> _loadUserImage(int? partnerId) async {
    if (partnerId == null) {
      return null; // Если partnerId равен null, фото отсутствует
    }

    final response = await http.get(
      Uri.parse('http://192.168.0.106:8080/user/image?id=$partnerId'),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes; // Возвращаем бинарные данные фото
    } else if (response.statusCode == 204) {
      return null; // Фото отсутствует
    } else {
      throw Exception('Failed to load image');
    }
  }

  Widget _buildAvatar(String name, int? partnerId) {
    return FutureBuilder<Uint8List?>(
      future: _loadUserImage(partnerId), // Загружаем фото
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: CircularProgressIndicator(color: Colors.white),
          );
        } else if (snapshot.hasError || snapshot.data == null) {
          // Если фото нет или произошла ошибка, показываем кружочек с буквой
          return CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          );
        } else {
          // Если фото есть, отображаем его
          return CircleAvatar(
            backgroundImage: MemoryImage(snapshot.data!),
          );
        }
      },
    );
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
              Scaffold.of(context).openDrawer();
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
                  //_showProfileMenu(context); // Показываем меню профиля
                  // Открываем Drawer
                  _scaffoldKey.currentState?.openDrawer();
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: FutureBuilder<Map<String, dynamic>>(
        future: _loadUserProfile(widget.userId), // Загружаем данные профиля
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки профиля'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Данные профиля отсутствуют'));
          }

          final userProfile = snapshot.data!;
          return ProfileMenu(
            username: userProfile['username'] ?? 'username',
            name: userProfile['name'] ?? 'Имя пользователя',
            bio: userProfile['bio'] ?? 'Информация о себе',
            image: userProfile['image'] != null
                ? Uint8List.fromList(userProfile['image'].cast<int>())
                : null,
            registrationDate: userProfile['registrationDate'] ?? '2023-10-01',
            onEditProfile: () {
              // Переход на экран редактирования профиля
            },
            onDeleteProfile: () {
              // Удаление профиля
            },
          );
        },
      ),
    body: Row(
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
                      leading: _buildAvatar(chat['partner_name'] ?? '', chat['partner_id']), // Используем _buildAvatar
                      title: Text(chat['partner_name'] ?? 'Новый чат'),
                      subtitle: Text(chat['lastMessage'] ?? ''),
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
            username: chats.firstWhere((chat) => chat['id'] == _selectedChatId)['partner_name'] ?? 'Новый чат',
            currentUserId: widget.userId, // Передаем ID текущего пользователя
            partnerId: chats.firstWhere((chat) => chat['id'] == _selectedChatId)['partner_id'], // Передаем partnerId
          ),
        ),

      ],
    ),
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
        final partnerName = chat['partner_name'] as String? ?? 'Новый чат';
        final partnerId = chat['partner_id'] as int?;
        final lastMessage = chat['lastMessage'] as String? ?? '';
        final unread = chat['unread'] as int? ?? 0;

        return ListTile(
          leading: _buildAvatar(partnerName, partnerId), // Используем _buildAvatar
          title: Text(partnerName),
          subtitle: Text(lastMessage),
          trailing: unread > 0
              ? CircleAvatar(
            radius: 12,
            child: Text(unread.toString()),
          )
              : null,
          onTap: () {
            if (chat['id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chat['id'],
                    username: chat['partner_name'] ?? 'Новый чат',
                    currentUserId: widget.userId,
                    partnerId: chat['partner_id'], // Передаем partnerId
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
     // appBar: isMobile ? _buildMobileAppBar() : null,
      appBar: isMobile ? _buildMobileAppBar() : null,
      drawer: ProfileMenu(
        username: 'username', // Замените на данные из базы данных
        name: 'Имя пользователя', // Замените на данные из базы данных
        bio: 'Информация о себе', // Замените на данные из базы данных
        image: null, // Замените на данные из базы данных
        registrationDate: '2023-10-01', // Замените на данные из базы данных
        onEditProfile: () {
          // Переход на экран редактирования профиля
        },
        onDeleteProfile: () {
          // Удаление профиля
        },
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : isDesktopOrWeb ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
  Future<Map<String, dynamic>> _loadUserProfile(int userId) async {
    if (userId == null) {
      throw Exception('User ID is null');
    }

    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/user/profile?id=$userId'),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print("Ответ от сервера: $responseBody"); // Логируем ответ

        final decodedResponse = json.decode(responseBody);

        // Декодируем Base64 строку в Uint8List, если изображение есть
        if (decodedResponse['image'] != null) {
          decodedResponse['image'] = base64Decode(decodedResponse['image']);
        }

        return decodedResponse;
      } else {
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Ошибка при загрузке профиля: $e"); // Логируем ошибку
      throw Exception('Failed to load user profile: $e');
    }
  }

}

