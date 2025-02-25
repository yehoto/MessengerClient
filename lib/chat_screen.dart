import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();//Создает и возвращает состояние виджета, которое будет управлять его жизненным циклом.
}

class _ChatScreenState extends State<ChatScreen> {//Определение состояния ChatScreen
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  List<Map<String, dynamic>> _messages = [];

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
      final message = {'text': _controller.text, 'isMe': true};
      _channel.sink.add(_controller.text);
      setState(() {
        _messages.add(message);
      });
      _controller.clear();//Очищает текстовое поле после отправки сообщения, чтобы пользователь мог ввести новое сообщение.
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'];
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
              message['text'],
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
        title: Text("Чат"),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(
                _messages.reversed.toList()[index],
              ),
            ),
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
    super.dispose();//необходимо для выполнения любых дополнительных операций по очистке, которые могут быть определены в родительском классе
  }
}