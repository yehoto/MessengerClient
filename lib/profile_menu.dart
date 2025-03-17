import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ProfileMenu extends StatelessWidget {
  final String username;
  final String name;
  final String bio;
  final Uint8List? image;
  final String registrationDate;
  final VoidCallback onEditProfile;
  final VoidCallback onDeleteProfile;

  ProfileMenu({
    required this.username,
    required this.name,
    required this.bio,
    required this.image,
    required this.registrationDate,
    required this.onEditProfile,
    required this.onDeleteProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(name),
            accountEmail: Text('@$username'),
            currentAccountPicture: CircleAvatar(
              backgroundImage: image != null ? MemoryImage(image!) : null,
              child: image == null ? Icon(Icons.person, size: 40) : null,
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('О себе'),
            subtitle: Text(bio.isNotEmpty ? bio : 'Нет информации'),
          ),
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Дата регистрации'),
            subtitle: Text(registrationDate),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Редактировать профиль'),
            onTap: onEditProfile,
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Удалить профиль'),
            onTap: onDeleteProfile,
          ),
        ],
      ),
    );
  }
}