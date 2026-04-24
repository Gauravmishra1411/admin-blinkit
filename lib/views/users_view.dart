import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer Users Directory (${users.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Container(
                          width: 250,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by name or email',
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: users.isEmpty
                  ? const Center(child: Text('No users found in Firestore.'))
                  : ListView(
                      children: [
                        _buildUsersTable(users),
                      ],
                    ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTable(List<QueryDocumentSnapshot> users) {
    return DataTable(
      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
      columns: const [
        DataColumn(label: Text('User ID', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: users.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'Unknown';
        final String email = data['email'] ?? 'No Email';
        final String phone = data['phone'] ?? 'No Phone';
        final String initial = name.isNotEmpty ? name[0] : '?';

        return DataRow(
          cells: [
            DataCell(Text(doc.id.substring(0, min(doc.id.length, 8)), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey))),
            DataCell(Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF4CA1AF).withOpacity(0.2),
                  child: Text(initial, style: const TextStyle(fontSize: 10, color: Color(0xFF4CA1AF), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )),
            DataCell(Text(email, style: const TextStyle(color: Colors.black54))),
            DataCell(Text(phone)),
            DataCell(
              IconButton(
                icon: const Icon(Icons.message_outlined, color: Colors.blue, size: 18),
                tooltip: 'Send targeted notification',
                onPressed: () => _sendTargetedNotification(doc.id, name),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  void _sendTargetedNotification(String userId, String userName) {
    final titleController = TextEditingController(text: 'Hello $userName!');
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notify $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await NotificationService.notifyUser(
                userId: userId,
                title: titleController.text.trim(),
                message: messageController.text.trim(),
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
