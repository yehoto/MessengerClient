import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'profile_menu.dart';

import 'new_group_chatscreen.dart';

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
        //print("Ответ от серверааа: $responseBody");

        if (responseBody != null && responseBody.isNotEmpty) {
          final decodedResponse = json.decode(responseBody);
          setState(() {
            chats = decodedResponse is List ? decodedResponse : [];
            print("Ответ от сервера: $chats['partnerName']");
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
      automaticallyImplyLeading: true, // Включаем автоматическое меню (три полоски)
      iconTheme: IconThemeData(color: Colors.white), // Делаем все иконки белыми
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // IconButton(
          //   icon: Icon(Icons.person, color: Colors.white),
          //   onPressed: () {
          //     // Переход в профиль
          //     Scaffold.of(context).openDrawer();
          //   },
          // ),
          Expanded(
            child: Center(
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => NewChatScreen(userId: widget.userId),
                  //   ),
                  // );
                  _showChatTypeSelection(context);
                },
              ),
            ),
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

  // Новый метод для отображения выбора типа чата
  void _showChatTypeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.person_add, color: Colors.deepPurple),
            title: Text('Личный чат'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewChatScreen(userId: widget.userId),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.group_add, color: Colors.deepPurple),
            title: Text('Групповой чат'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewGroupChatScreen(userId: widget.userId),
                ),
              );
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
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => NewChatScreen(userId: widget.userId),
              //   ),
              // );
              _showChatTypeSelection(context);
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
        future: _loadUserProfile(widget.userId),
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
          // Список чатов (левая панель)
          Container(
            width: _chatListWidth,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
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
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedChatId = chat['id'];
                          });
                        },
                        child: _buildChatItem(chat),
                      );
                    },
                  ),
                ),
                _buildDesktopChatListFooter(),
              ],
            ),
          ),

          // Вертикальный разделитель с возможностью изменения ширины
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _chatListWidth += details.delta.dx;
                _chatListWidth = _chatListWidth.clamp(200.0, 400.0);
              });
            },
            child: Container(
              width: 8,
              color: Colors.grey[300],
            ),
          ),

          // Область выбранного чата (правая часть)
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
              username: chats.firstWhere(
                    (chat) => chat['id'] == _selectedChatId,
                orElse: () => {
                  'partner_name': 'Чат',
                  'chat_name': 'Чат',
                  'is_group': false
                },
              )[chats.firstWhere(
                    (chat) => chat['id'] == _selectedChatId,
                orElse: () => {'is_group': false},
              )['is_group'] ? 'chat_name' : 'partner_name'] ?? 'Чат',
              currentUserId: widget.userId,
              partnerId: chats.firstWhere(
                    (chat) => chat['id'] == _selectedChatId,
                orElse: () => {'partner_id': null},
              )['partner_id'],
              isGroup: chats.firstWhere(
                    (chat) => chat['id'] == _selectedChatId,
                orElse: () => {'is_group': false},
              )['is_group'],
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
        :ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) => _buildChatItem(chats[index]),
    );

    //     : ListView.builder(
    //   itemCount: chats.length,
    //   itemBuilder: (context, index) {
    //     final chat = chats[index];
    //     final partnerName = chat['partner_name'] as String? ?? 'Новый чат';
    //     final partnerId = chat['partner_id'] as int?;
    //     final lastMessage = chat['lastMessage'] as String? ?? '';
    //     final unread = chat['unread'] as int? ?? 0;
    //
    //     return ListTile(
    //       leading: _buildAvatar(partnerName, partnerId), // Используем _buildAvatar
    //       title: Text(partnerName),
    //       subtitle: Text(lastMessage),
    //       trailing: unread > 0
    //           ? CircleAvatar(
    //         radius: 12,
    //         child: Text(unread.toString()),
    //       )
    //           : null,
    //       onTap: () {
    //         if (chat['id'] != null) {
    //           Navigator.push(
    //             context,
    //             MaterialPageRoute(
    //               builder: (context) => ChatScreen(
    //                 chatId: chat['id'],
    //                 username: chat['partner_name'] ?? 'Новый чат',
    //                 currentUserId: widget.userId,
    //                 partnerId: chat['partner_id'], // Передаем partnerId
    //               ),
    //             ),
    //           );
    //         }
    //       },
    //     );
    //   },
    // );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isMobile ? _buildMobileAppBar() : null,
      drawer: FutureBuilder<Map<String, dynamic>>(
        future: _loadUserProfile(widget.userId), // Динамические данные
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ProfileMenu(
              username: "Ошибка",
              name: "Не удалось загрузить",
              bio: "",
              image: null,
              registrationDate: "",
              onEditProfile: () {},
              onDeleteProfile: () {},
            );
          }

          final userProfile = snapshot.data!;
          return ProfileMenu(
            username: userProfile['username'] ?? "Пользователь",
            name: userProfile['name'] ?? "Имя не указано",
            bio: userProfile['bio'] ?? "",
            image: userProfile['image'],
            registrationDate: userProfile['registrationDate'] ?? "",
            onEditProfile: () {/* Редактирование */},
            onDeleteProfile: () {/* Удаление */},
          );
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
        //print("Ответ от сервера: $responseBody"); // Логируем ответ

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

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final isGroup = chat['is_group'] ?? false;
    final dynamic imageData = chat['group_image'];
    Uint8List? imageBytes;

    if (imageData != null) {
      if (imageData is String) {
        imageBytes = base64Decode(imageData);
      } else if (imageData is List) {
        imageBytes = Uint8List.fromList(List<int>.from(imageData));
      }
    }

    final chatName = isGroup
        ? chat['chat_name'] ?? 'Групповой чат'
        : chat['partner_name'] ?? 'Личный чат';
    final lastMessage = chat['lastMessage'] ?? '';
    final unread = chat['unread'] ?? 0;

    return ListTile(
      leading: isGroup
          ? CircleAvatar(
        backgroundColor: Colors.deepPurple,
        backgroundImage: imageBytes != null
            ? MemoryImage(imageBytes)
            : null,
        child: imageBytes == null
            ? Icon(Icons.group, color: Colors.white)
            : null,
      )
          : _buildAvatar(chatName, chat['partner_id']),
      title: Text(chatName),
      subtitle: Text(lastMessage),
      trailing: unread > 0
          ? CircleAvatar(
        radius: 12,
        backgroundColor: Colors.deepPurple,
        child: Text(
          unread.toString(),
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      )
          : null,
      selected: _selectedChatId == chat['id'],
      selectedTileColor: Colors.deepPurple.withOpacity(0.1),
    );
  }

}