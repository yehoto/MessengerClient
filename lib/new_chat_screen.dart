import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_list_screen.dart';

class NewChatScreen extends StatefulWidget {
  final int userId;

  NewChatScreen({required this.userId});

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  List<dynamic> users = [];
  bool isLoading = true;
  bool hasError = false; // Добавляем флаг для ошибки

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.216.250:8080/users?current_user_id=${widget.userId}'), // Добавляем параметр current_user_id
      );

      print("Статус ответа: ${response.statusCode}"); // Логируем статус ответа
      print("Тело ответа: ${response.body}"); // Логируем тело ответа

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final decodedResponse = json.decode(responseBody);
        setState(() {
          users = decodedResponse;
          isLoading = false;
        });
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Ошибка при загрузке пользователей: $e"); // Логируем исключение
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _createChat(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.216.250:8080/chats'),
        body: {
          'user_id': targetUserId.toString(),
          'current_user_id': widget.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatListScreen(userId: widget.userId),
          ),
        );
      } else {
        print("Ошибка при создании чата: ${response.statusCode}");
      }
    } catch (e) {
      print("Ошибка при создании чата: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новый чат'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : hasError
          ? Center(
        child: Text(
          'Ошибка при загрузке пользователей',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      )
          : users.isEmpty
          ? Center(
        child: Text(
          'Нет доступных пользователей',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user['username']),
            onTap: () => _createChat(user['id']),
          );
        },
      ),
    );
  }
}