import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data'; // Добавьте этот импорт
import 'forward_screen.dart'; // Добавьте этот импорт
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String username;
  final int currentUserId;
  final int? partnerId; // Добавляем partnerId
  final bool isGroup; // Обязательный параметр



  ChatScreen({
    required this.chatId,
    required this.username,
    required this.currentUserId,
    required this.partnerId, // Добавляем partnerId
    required this.isGroup // Обязательный параметр
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  List<Map<String, dynamic>> _messages = [];
  bool _isUserOnline = false; // Состояние для статуса пользователя
  int? _replyToMessageId;
  Map<String, dynamic>? _replyingMessage;
  int? _highlightedMessageId; // Добавляем в состояние
  final ItemScrollController itemScrollController = ItemScrollController();
  int _participantsCount = 0; // Общее количество участников

  void _startReply(Map<String, dynamic> message) {
    print('Начинаем ответ на сообщение: $message');
    setState(() {
      _replyToMessageId = message['id'];
      _replyingMessage = message;
    });
  }

  void _highlightMessage(int messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });

    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadChatInfo().then((_) {
      _loadMessages().then((_) {
        _connectToServer();
        if (!widget.isGroup) {
          _loadUserStatus();
        }
      });
    });
  }

  Future<void> _loadChatInfo() async {
    if (widget.isGroup) {
      try {
        final response = await http.get(
          Uri.parse('http://192.168.0.106:8080/group_participants_count?chat_id=${widget.chatId}'),
        );
        print("Group info response: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 200) {
          final groupInfo = json.decode(response.body);
          setState(() {
            _participantsCount = groupInfo['participants_count'] ?? 0;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load participants: ${response.statusCode}")),
          );
        }
      } catch (e) {
        print("Error loading group info: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading participants")),
        );
      }
    }
  }

  Future<void> _loadUserStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/user-status?user_id=${widget.partnerId}&chat_id=${widget.chatId}'),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> status = json.decode(responseBody);
        setState(() {
          _isUserOnline = status['online'];
        });
      } else {
        print("Ошибка загрузки статуса: ${response.statusCode}");
      }
    } catch (e) {
      print("Ошибка загрузки статуса: $e");
    }
  }
  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если chatId изменился, очищаем историю сообщений и загружаем новую
    if (oldWidget.chatId != widget.chatId) {
      setState(() {
        _messages.clear(); // Очищаем старые сообщения
        _isUserOnline = false; // Сбрасываем статус пользователя

      });
      _loadMessages(); // Загружаем сообщения для нового чата
      _closeWebSocket(); // Закрываем текущее соединение
      _connectToServer(); // Создаем новое соединение с новым chatId
      _loadUserStatus();
    }
  }


  void _closeWebSocket() {
    if (_channel != null) {
      _channel.sink.close();
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
    final uri = Uri.parse('ws://192.168.0.106:8080/ws?user_id=${Uri.encodeComponent(widget.currentUserId.toString())}&chat_id=${Uri.encodeComponent(widget.chatId.toString())}');
    print("Подключение к WebSocket: $uri");
    _channel = WebSocketChannel.connect(uri);

    _channel.stream.listen((data) {
      final message = json.decode(data);
      print('Получено сообщение через WebSocket: $message'); // Логируем входящее сообщение
      if (message['type'] == 'reaction') {
        setState(() {
          _updateReaction(message);
        });
      } else if (message['type'] == 'user_status' && message['user_id'] == widget.partnerId) {
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
  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      final message = {
        'chat_id': widget.chatId,
        'user_id': widget.currentUserId,
        'text': _controller.text,
        'isMe': true,
        'created_at': DateTime.now().toIso8601String(),
        'parent_message_id': _replyToMessageId,
      };
      _channel.sink.add(json.encode(message));
      _controller.clear();

      // Сбрасываем состояние ответа сразу после отправки
      setState(() {
        _replyToMessageId = null;
        _replyingMessage = null;
      });

      // Опционально: Ожидание подтверждения от сервера
      final response = await _channel.stream.firstWhere((data) {
        final decoded = json.decode(data);
        return decoded['chat_id'] == widget.chatId && decoded['text'] == message['text'];
      });
      final serverMessage = json.decode(response);

      setState(() {
        _messages.insert(0, serverMessage);
      });
    }
  }

  Future<Uint8List?> _loadUserImage(int? userId) async {
    if (userId == null) {
      return null; // Если partnerId равен null, фото отсутствует
    }
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

  Future<Uint8List?> _loadImage(int? id, bool isGroup) async {
    if (id == null) return null;

    final endpoint = isGroup
        ? 'http://192.168.0.106:8080/group/image?chat_id=$id'
        : 'http://192.168.0.106:8080/user/image?id=$id';

    final response = await http.get(Uri.parse(endpoint));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else if (response.statusCode == 204) {
      return null;
    } else {
      throw Exception('Failed to load image');
    }
  }

  Widget _buildUserAvatar() {
    return FutureBuilder<Uint8List?>(
      future: _loadImage(widget.chatId, widget.isGroup), // Загружаем фото
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
    final isGroup = widget.isGroup;
    final senderId = message['user_id'];

    // Пересланные сообщения
    if (message['is_forwarded'] == true) {
      return Column(
        children: [
          Text('Переслано от: ${message['original_sender_name'] ?? 'Неизвестно'}'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.deepPurple : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(text),
          ),
        ],
      );
    }

    // Сообщения-ответы
    if (message['parent_message_id'] != null &&
        message['parent_content'] != null &&
        (message['parent_content'] as String).isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Аватар и имя для групповых чатов (если не свое сообщение)
            if (isGroup && !isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: _loadUserImage(senderId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircleAvatar(radius: 12);
                        }
                        if (snapshot.hasData && snapshot.data != null) {
                          return CircleAvatar(
                            radius: 12,
                            backgroundImage: MemoryImage(snapshot.data!),
                          );
                        }
                        return CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey,
                          child: Text(
                            message['sender_name']?.isNotEmpty == true
                                ? message['sender_name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message['sender_name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            // Превью ответа с кликабельной областью
            GestureDetector(
              onTap: () {
                final parentId = message['parent_message_id'];
                if (parentId != null) {
                  final parentIndex = _messages.indexWhere((msg) => msg['id'] == parentId);
                  if (parentIndex != -1) {
                    itemScrollController.scrollTo(
                      index: parentIndex,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                    _highlightMessage(parentId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Сообщение удалено или недоступно')),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _highlightedMessageId == message['parent_message_id']
                      ? Colors.green[200]
                      : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: const Border(left: BorderSide(width: 4, color: Colors.purple)),
                ),
                child: Text(
                  'Ответ на: ${message['parent_content']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            // Тело сообщения с обработчиками нажатия
            GestureDetector(
              onTap: () {
                _highlightMessage(message['id']);
              },
              onTapDown: (details) {
                final tapPosition = details.globalPosition;
                _showReactionPicker(context, message['id'], tapPosition, message);
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _highlightedMessageId == message['id']
                      ? Colors.green[200]
                      : (isMe ? Colors.deepPurple : Colors.grey[200]),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (message['id'] != null) _buildReactions(message['id']),
          ],
        ),
      );
    }

    // Системные сообщения
    if (isSystem) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                _formatTime(createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    // Обычные сообщения
    return GestureDetector(
      // behavior: HitTestBehavior.translucent, // Пропускает события дальше, если нужно
      onTap: () {
        _highlightMessage(message['id']); // Подсветка при клике
      },
      onTapDown: (details) {
        final tapPosition = details.globalPosition;
        _showReactionPicker(context, message['id'], tapPosition, message);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isGroup && !isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: _loadUserImage(senderId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircleAvatar(radius: 12);
                        } else if (snapshot.hasData && snapshot.data != null) {
                          return CircleAvatar(
                            radius: 12,
                            backgroundImage: MemoryImage(snapshot.data!),
                          );
                        } else {
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey,
                            child: Text(
                              message['sender_name']?.isNotEmpty == true
                                  ? message['sender_name'][0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message['sender_name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _highlightedMessageId == message['id']
                    ? Colors.green[200] // Подсвеченное сообщение
                    : (isMe ? Colors.deepPurple : Colors.grey[200]), // Обычное сообщение
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (message['id'] != null) _buildReactions(message['id']),
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
          return SizedBox.shrink(); // Убрали анимацию загрузки
        } else if (snapshot.hasError) {
          return SizedBox.shrink(); // Скрываем ошибки
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
                  final userInitial = reaction['user_id'].toString()[0];

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
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
                      _startReply(message);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.forward, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Реализация пересылки
                      _startForward(message);
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
                      //_deleteMessage(messageId);
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
  void _startForward(Map<String, dynamic> message) {
    print('Начинаем пересылку сообщения: $message'); // Логируем данные сообщения
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ForwardScreen(
          message: message,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }


  Widget _buildReplyPreview() {
    if (_replyingMessage == null) {
      return SizedBox.shrink();
    }

    final isGroup = widget.isGroup;
    final senderId = _replyingMessage?['user_id'];
    final senderName = _replyingMessage?['sender_name'] ?? 'Неизвестный';

    return GestureDetector(
      onTap: () {
        setState(() {
          _replyToMessageId = null;
          _replyingMessage = null;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(width: 4, color: Colors.purple)),
          color: Colors.grey[100],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGroup) // Только для групповых чатов
              Row(
                children: [
                  FutureBuilder<Uint8List?>(
                    future: _loadUserImage(senderId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(radius: 12);
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return CircleAvatar(
                          radius: 12,
                          backgroundImage: MemoryImage(snapshot.data!),
                        );
                      }
                      return CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey,
                        child: Text(
                          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            Text(
              _replyingMessage!['text'],
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
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
            GestureDetector(
              onTap: () => _showPartnerProfile(context), // Открываем профиль
              child: _buildUserAvatar(),
            ),
            SizedBox(width: 10),
            // Имя и статус
            GestureDetector(
              onTap: () => _showPartnerProfile(context), // Открываем профиль
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.username),
                  if (widget.isGroup)
                    Text(
                      "$_participantsCount участника",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  else
                    Text(
                      _isUserOnline ? 'В сети' : 'Не в сети',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isUserOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                ],
              ),
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
            child: ScrollablePositionedList.builder(
              itemScrollController: itemScrollController,
              itemCount: _messages.length,
              reverse: false, // Сохраняем порядок сообщений (новые внизу)
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildReplyPreview(),
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
    _closeWebSocket(); // Закрываем соединение при уничтожении виджета
    super.dispose();
  }
  void _showPartnerProfile(BuildContext context) async {
    try {
      // Загружаем данные профиля собеседника
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/user/profile?id=${widget.partnerId}'),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> profile = json.decode(responseBody);

        // Открываем диалоговое окно с данными
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Профиль'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Фото или кружок с первой буквой имени
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: profile['image'] != null
                        ? MemoryImage(base64Decode(profile['image']))
                        : null,
                    child: profile['image'] == null
                        ? Text(
                      profile['name']?.isNotEmpty == true
                          ? profile['name'][0].toUpperCase()
                          : '?',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    )
                        : null,
                  ),
                  SizedBox(height: 10),
                  Text('Имя: ${profile['name'] ?? 'Не указано'}'),
                  Text('@${profile['username'] ?? 'Не указано'}'),
                  Text('О себе: ${profile['bio'] ?? 'Нет информации'}'),
                  Text('Дата регистрации: ${profile['registrationDate'] ?? 'Не указана'}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Закрываем диалог
                  },
                  child: Text('Закрыть'),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Ошибка загрузки профиля: ${response.statusCode}');
      }
    } catch (e) {
      print("Ошибка при загрузке профиля: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить профиль')),
      );
    }
  }
}