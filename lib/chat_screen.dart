import 'package:flutter/material.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();//Создает и возвращает состояние виджета, которое будет управлять его жизненным циклом.
}

class _ChatScreenState extends State<ChatScreen> {//Определение состояния ChatScreen
  final TextEditingController _controller = TextEditingController();
  Socket? _socket;//Знак вопроса указывает, что переменная может быть null
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() async {
    try{
      _socket = await Socket.connect('localhost', 8080);//Подключение к серверу, который работает на локальном хосте на порту 8080. await указывает, что метод должен дождаться завершения подключения.
      _socket!.listen(//Настраивает слушатель для получения данных из сокета
        _onData,//Вызывается при получении данных
        onError: _onError,//Метод для обработки ошибок, возникающих при работе с сокетом
        onDone: _onDone,//Вызывается, когда соединение закрыто
      );
    } catch (e) {
      print("Ошибка подключения: $e");
    }
  }

  void _onData(List<int> data) {
    final message = String.fromCharCodes(data);//Преобразует полученные байты в строку.
    setState(() {//обновление состояния виджета (пользователь что-то напечатал)
      _messages.add(message);
    });
  }

  void _onError(error) {
    print("Ошибка: $error");
  }

  void _onDone() {
    print("Соединение закрыто");
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && _socket != null) {//предотвращает попытку отправки пустого сообщения и ошибки, если сокет не подключен.
      _socket!.write(_controller.text + "\n");
      _controller.clear();//Очищает текстовое поле после отправки сообщения, чтобы пользователь мог ввести новое сообщение.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(// тип виджета
      body: Row(
        children: [
          Expanded(//чтобы текстовое поле занимало всё доступное пространство в ряду
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(hintText: "Введите сообщение..."),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();//необходимо для выполнения любых дополнительных операций по очистке, которые могут быть определены в родительском классе
  }
}