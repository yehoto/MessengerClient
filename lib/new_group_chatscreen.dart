import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart'; // Для выбора изображений



class NewGroupChatScreen extends StatefulWidget {
  final int userId;

  NewGroupChatScreen({required this.userId});

  @override
  _NewGroupChatScreenState createState() => _NewGroupChatScreenState();
}

class _NewGroupChatScreenState extends State<NewGroupChatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _image;
  List<int> _selectedUsers = [];
  List<dynamic> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.106:8080/all-users?current_user_id=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _allUsers = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading users: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.0.106:8080/group-chats'),
        );

        // Добавляем текстовые поля
        request.fields['name'] = _nameController.text;
        request.fields['description'] = _descriptionController.text;
        request.fields['created_by'] = widget.userId.toString();
        request.fields['is_group'] = 'true';

        // Передаем user_ids как строку, разделенную запятыми
        request.fields['user_ids'] = _selectedUsers.join(',');

        // Добавляем изображение, если оно выбрано
        if (_image != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            _image!.path,
          ));
        }

        // Отправляем запрос
        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        print('Response status: ${response.statusCode}');
        print('Response body: $responseBody');

        if (response.statusCode == 200) {
          Navigator.pop(context); // Закрываем экран после успешного создания
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка создания чата: $responseBody')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Создать групповой чат'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : null,
                  child: _image == null
                      ? Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Название группы'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название группы';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Описание группы'),
              ),
              SizedBox(height: 20),
              Text('Выберите участников:', style: TextStyle(fontSize: 16)),
              ..._allUsers.map((user) => CheckboxListTile(
                title: Text(user['username']),
                value: _selectedUsers.contains(user['id']),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedUsers.add(user['id']);
                    } else {
                      _selectedUsers.remove(user['id']);
                    }
                  });
                },
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
