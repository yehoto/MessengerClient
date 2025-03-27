import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class ForwardScreen extends StatelessWidget {
  final Map<String, dynamic> message;
  final int currentUserId;

  const ForwardScreen({
    required this.message,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Выберите чат')),
      body: FutureBuilder(
        future: _loadAvailableChats(),
        builder: (ctx, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (ctx, index) {
                final chat = snapshot.data![index];
                return ListTile(
                  title: Text(chat['chat_name']),
                  onTap: () => _forwardMessage(chat['id'], context),
                );
              },
            );
          }
          return CircularProgressIndicator();
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAvailableChats() async {
    final response = await http.get(Uri.parse('http://192.168.0.106:8080/chats?user_id=$currentUserId'));
    if (response.statusCode == 200) {
      final responseBody = response.body;
      print('Загруженные чаты: $responseBody'); // Логируем ответ сервера
      if (responseBody == null || responseBody.isEmpty) {
        print('Нет доступных чатов для пересылки');
        return [];
      }
      return json.decode(responseBody).cast<Map<String, dynamic>>();
    } else {
      print('Ошибка загрузки чатов: ${response.statusCode}');
      return [];
    }
  }

  void _forwardMessage(int targetChatId, BuildContext context) async {
    final messageData = {
      'chat_id': targetChatId,
      'user_id': currentUserId,
      'text': message['text'],
    };
    if (message['is_forwarded'] == true) {
      if (message['original_sender_id'] != null) {
        messageData['original_sender_id'] = message['original_sender_id'];
      }
      if (message['original_chat_id'] != null) {
        messageData['original_chat_id'] = message['original_chat_id'];
      }
    } else {
      messageData['original_sender_id'] = message['user_id'];
      messageData['original_chat_id'] = message['chat_id'];
    }
    print('Отправляемые данные для пересылки: $messageData');

    final response = await http.post(
      Uri.parse('http://192.168.0.106:8080/forward-message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(messageData),
    );

    print('Ответ сервера: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сообщение успешно переслано')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось переслать сообщение: ${response.statusCode}')),
      );
    }
    Navigator.pop(context);
  }
}