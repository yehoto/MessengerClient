import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();//Создает и возвращает состояние виджета, которое будет управлять его жизненным циклом.
}

class _ChatScreenState extends State<ChatScreen> {//Определение состояния ChatScreen
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() {
    try{
      _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));
      _channel.stream.listen(
        _onData,//Вызывается при получении данных
        onError: _onError,//Метод для обработки ошибок, возникающих при работе с сокетом
        onDone: _onDone,//Вызывается, когда соединение закрыто
      );
    } catch (e) {
      print("Ошибка подключения: $e");
    }
  }

  void _onData(dynamic data) {
    setState(() {//обновление состояния виджета (пользователь что-то напечатал)
      _messages.add(data);
    });
  }

  void _onError(error) {
    print("Ошибка: $error");
  }

  void _onDone() {
    print("Соединение закрыто");
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {//предотвращает попытку отправки пустого сообщения и ошибки, если сокет не подключен.
      _channel.sink.add(_controller.text);
      _controller.clear();//Очищает текстовое поле после отправки сообщения, чтобы пользователь мог ввести новое сообщение.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(// тип виджета
      appBar: AppBar(
        title: Text("Чат"),
      ),
      body: Column(
        children: [
      Expanded(
      child: ListView.builder(
      itemCount: _messages.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_messages[index]),
          );
        },
      ),
    ),
    Padding(
    padding: const EdgeInsets.all(8.0),
     child: Row(
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
    ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();//необходимо для выполнения любых дополнительных операций по очистке, которые могут быть определены в родительском классе
  }
}