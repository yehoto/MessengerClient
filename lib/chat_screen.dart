import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String username;
  final int currentUserId;

  ChatScreen({required this.chatId, required this.username, required this.currentUserId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
    _loadMessages();
  }



  Future<void> _loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.216.250:8080/messages?chat_id=${widget.chatId}&user_id=${widget.currentUserId}'),
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
    _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.216.250:8080/ws'));

    print("Подключение к WebSocket...");

    _channel.stream.listen(
          (data) {
        print("Получено сообщение через WebSocket: $data"); // Логируем входящие данные
        final message = json.decode(data);
        if (message['chat_id'] == widget.chatId) {
          setState(() {
            _messages.add(message);
          });
        }
      },
      onError: (error) {
        print("Ошибка WebSocket: $error");
      },
      onDone: () {
        print("WebSocket соединение закрыто");
      },
    );
  }

  // chat_screen.dart (исправленный код)
  void _sendMessage() {
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

      _channel.sink.add(json.encode(message));
      _controller.clear();
    }
  }


  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['user_id'] == widget.currentUserId; // Определяем, ваше ли это сообщение
    final text = message['text'] as String? ?? ''; // Проверка на null
    final isSystem = message['is_system'] as bool? ?? false; // Проверка на null

    if (isSystem) {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Padding(
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
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Функционал поиска по сообщениям
            },
          ),
        ],
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