import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data'; // Добавьте этот импорт

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String username;
  final int currentUserId;
  final int partnerId; // Добавляем partnerId

  ChatScreen({
    required this.chatId,
    required this.username,
    required this.currentUserId,
    required this.partnerId, // Добавляем partnerId
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  List<Map<String, dynamic>> _messages = [];
  bool _isUserOnline = false; // Состояние для статуса пользователя

  @override
  void initState() {
    super.initState();
    _connectToServer();
    _loadMessages();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если chatId изменился, очищаем историю сообщений и загружаем новую
    if (oldWidget.chatId != widget.chatId) {
      setState(() {
        _messages.clear(); // Очищаем старые сообщения
      });
      _loadMessages(); // Загружаем сообщения для нового чата
    }
  }




  Future<void> _loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/messages?chat_id=${widget.chatId}&user_id=${widget.currentUserId}'),
      );

      print("Статус ответа: ${response.statusCode}"); // Логируем статус ответа
      print("Тело ответа: ${response.body}"); // Логируем тело ответа

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> messages = json.decode(responseBody);
        setState(() {
          _messages = messages.map((msg) => msg as Map<String, dynamic>).toList();
        });
      } else {
        print("Ошибка загрузки сообщений: ${response.statusCode}");
      }
    } catch (e) {
      print("Ошибка загрузки сообщений: $e");
    }
  }

  void _connectToServer() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.106:8080/ws?user_id=${widget.currentUserId}'),
    );

    _channel.stream.listen((data) {
      final message = json.decode(data);
      if (message['type'] == 'reaction') {
        setState(() {
          _updateReaction(message);
        });
      } else if (message['type'] == 'user_status' && message['user_id'] == widget.chatId) {
        setState(() {
          _isUserOnline = message['online'];
        });
      } else if (message['chat_id'] == widget.chatId) {
        setState(() {
          _messages.add(message);
        });
      }
    }, onError: (error) {
      print("Ошибка WebSocket: $error");
    }, onDone: () {
      print("WebSocket соединение закрыто");
    });
  }

  void _updateReaction(Map<String, dynamic> reaction) {
    final messageIndex = _messages.indexWhere((msg) => msg['id'] == reaction['message_id']);
    if (messageIndex != -1) {
      setState(() {
        final message = _messages[messageIndex];
        final reactions = message['reactions'] ?? [];
        reactions.add(reaction);
        _messages[messageIndex]['reactions'] = reactions;
      });
    }
  }
  // chat_screen.dart (исправленный код)
  void _sendMessage()async {
    if (_controller.text.isNotEmpty) {
      final message = {
        'chat_id': widget.chatId,
        'user_id': widget.currentUserId,
        'text': _controller.text,
        'isMe': true, // Помечаем как свое сообщение
        'created_at': DateTime.now().toIso8601String(),
      };

      // Оптимистично добавляем сообщение в список
      // setState(() {
      // _messages.insert(0, message); // Добавляем в начало списка
      // });

      // Отправляем сообщение на сервер
      _channel.sink.add(json.encode(message));

      // Очищаем поле ввода
      _controller.clear();


      // Ждем ответа от сервера с id
      final response = await _channel.stream.firstWhere((data) {
        final decoded = json.decode(data);
        return decoded['chat_id'] == widget.chatId && decoded['text'] == message['text'];
      });

      final serverMessage = json.decode(response);

      // Добавляем сообщение с id от сервера в список
      setState(() {
        _messages.insert(0, serverMessage);
      });


    }
  }

  Future<Uint8List?> _loadUserImage(int userId) async {
    final response = await http.get(
      Uri.parse('http://192.168.0.106:8080/user/image?id=$userId'),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes; // Возвращаем бинарные данные фото
    } else if (response.statusCode == 204) {
      return null; // Фото отсутствует
    } else {
      throw Exception('Failed to load image');
    }
  }

  Widget _buildUserAvatar() {
    return FutureBuilder<Uint8List?>(
      future: _loadUserImage(widget.partnerId), // Загружаем фото
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            backgroundColor: Colors.purple,
            child: CircularProgressIndicator(color: Colors.white),
          );
        } else if (snapshot.hasError || snapshot.data == null) {
          // Если фото нет или произошла ошибка, показываем кружочек с буквой
          return CircleAvatar(
            backgroundColor: Colors.purple,
            child: Text(
              widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white),
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
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['user_id'] == widget.currentUserId;
    final text = message['text'] as String? ?? '';
    final createdAt = message['created_at'] as String? ?? '';
    final isSystem = message['is_system'] as bool? ?? false;

    if (isSystem) {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 4), // Отступ между текстом и временем
              Text(
                _formatTime(createdAt), // Время под текстом
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10, // Уменьшаем размер шрифта
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (details) {
        final tapPosition = details.globalPosition;
        _showReactionPicker(context, message['id'], tapPosition, message);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.deepPurple : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  if (message['id'] != null) _buildReactions(message['id']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoTime) {
    final dateTime = DateTime.parse(isoTime).toLocal(); // Преобразуем в локальное время
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  Widget _buildReactions(int messageId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadReactions(messageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Ошибка загрузки реакций');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        } else {
          return Wrap(
            spacing: 4,
            children: snapshot.data!.map((reaction) {
              return FutureBuilder<Uint8List?>(
                future: _loadUserImage(reaction['user_id']),
                builder: (context, imageSnapshot) {
                  final hasImage = imageSnapshot.hasData && imageSnapshot.data != null;
                  final userInitial = reaction['user_id'].toString()[0]; // Первая буква ID пользователя

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                     // color: Colors.grey[200],
                      color: Colors.purpleAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasImage)
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: MemoryImage(imageSnapshot.data!),
                          )
                        else
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.deepPurple,
                            child: Text(
                              userInitial,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        SizedBox(width: 4),
                        Text(
                          reaction['reaction'],
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadReactions(int messageId) async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/get-reactions?message_id=$messageId'),
      );

      print("Response status: ${response.statusCode}"); // Логируем статус ответа
      print("Response body: ${response.body}"); // Логируем тело ответа

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> reactions = json.decode(responseBody);
        return reactions.map((reaction) => reaction as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load reactions: ${response.statusCode}');
      }
    } catch (e) {
      print("Error loading reactions: $e");
      throw Exception('Failed to load reactions');
    }
  }

  void _showReactionPicker(BuildContext context, int messageId, Offset tapPosition, Map<String, dynamic> message) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(tapPosition, tapPosition),
      Offset.zero & overlay.size,
    );

    final createdAt = _formatTime(message['created_at'] as String? ?? '');
    final deliveredAt = message['delivered_at'] != null ? _formatTime(message['delivered_at']) : 'Не доставлено';
    final readAt = message['read_at'] != null ? _formatTime(message['read_at']) : 'Не прочитано';

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: Column(
            children: [
              // Строка с реакциями
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['😀', '😍', '😂'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addReaction(messageId, emoji);
                    },
                    child: Text(emoji, style: TextStyle(fontSize: 24)),
                  );
                }).toList(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['😡', '👍', '👎'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addReaction(messageId, emoji);
                    },
                    child: Text(emoji, style: TextStyle(fontSize: 24)),
                  );
                }).toList(),
              ),

              // Плашка с информацией о статусе
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Статус сообщения:",
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Доставлено: $deliveredAt",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      "Прочитано: $readAt",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      "Изменено: $createdAt",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Кнопки
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.reply, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация ответа
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.forward, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация пересылки
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.push_pin, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация пересылки
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация пересылки
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация удаления
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // void _showMessageOptions(BuildContext context, int messageId) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) {
  //       return Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           ListTile(
  //             leading: Icon(Icons.reply),
  //             title: Text("Ответить"),
  //             onTap: () {
  //               // Реализация ответа
  //               Navigator.pop(context);
  //             },
  //           ),
  //           ListTile(
  //             leading: Icon(Icons.forward),
  //             title: Text("Переслать"),
  //             onTap: () {
  //               // Реализация пересылки
  //               Navigator.pop(context);
  //             },
  //           ),
  //           ListTile(
  //             leading: Icon(Icons.push_pin),
  //             title: Text("Закрепить"),
  //             onTap: () {
  //               // Реализация закрепления
  //               Navigator.pop(context);
  //             },
  //           ),
  //           ListTile(
  //             leading: Icon(Icons.edit),
  //             title: Text("Изменить"),
  //             onTap: () {
  //               // Реализация изменения
  //               Navigator.pop(context);
  //             },
  //           ),
  //           ListTile(
  //             leading: Icon(Icons.delete),
  //             title: Text("Удалить"),
  //             onTap: () {
  //               // Реализация удаления
  //               Navigator.pop(context);
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _addReaction(int messageId, String reaction) async {
    final response = await http.post(
      Uri.parse('http://192.168.0.106:8080/add-reaction'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message_id': messageId,
        'user_id': widget.currentUserId,
        'reaction': reaction,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add reaction');
    }

    // Обновляем сообщения после добавления реакции
    _loadMessages();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Кружочек с фото или первой буквой имени
            _buildUserAvatar(),
            SizedBox(width: 10),
            // Имя и статус
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.username),
                Text(
                  _isUserOnline ? 'В сети' : 'Не в сети',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isUserOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(width: 20),
            // Значок лупы
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {
                // Поиск по сообщениям
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView.builder(
                // reverse: true, //
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              )
          ),
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Введите сообщение...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.deepPurple),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}