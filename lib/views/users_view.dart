import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString('saved_users');

    if (usersJson != null) {
      final List<dynamic> decodedList = jsonDecode(usersJson);
      _users = List<Map<String, dynamic>>.from(decodedList);
    } else {
      _users = [
        {'id': '#USR-9012', 'name': 'Emma Johnson', 'email': 'emma.j@email.com', 'phone': '+1 (555) 123-4567', 'joined': 'Oct 10, 2024', 'status': 'Active'},
        {'id': '#USR-9013', 'name': 'Noah Smith', 'email': 'noah.s@email.com', 'phone': '+1 (555) 987-6543', 'joined': 'Oct 12, 2024', 'status': 'Active'},
        {'id': '#USR-9014', 'name': 'Olivia Williams', 'email': 'olivia.w@email.com', 'phone': '+1 (555) 456-7890', 'joined': 'Oct 14, 2024', 'status': 'Suspended'},
        {'id': '#USR-9015', 'name': 'William Brown', 'email': 'william.b@email.com', 'phone': '+1 (555) 234-5678', 'joined': 'Oct 18, 2024', 'status': 'Active'},
        {'id': '#USR-9016', 'name': 'Sophia Jones', 'email': 'sophia.j@email.com', 'phone': '+1 (555) 345-6789', 'joined': 'Oct 22, 2024', 'status': 'Pending'},
      ];
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_users', jsonEncode(_users));
  }

  void _editUserDialog(Map<String, dynamic> user, int index) {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final phoneController = TextEditingController(text: user['phone']);
    String status = user['status'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
             return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               title: const Text('Edit Customer Profile'),
               content: SizedBox(
                 width: 400,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     TextField(
                       controller: nameController,
                       decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                     ),
                     const SizedBox(height: 15),
                     TextField(
                       controller: emailController,
                       decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                     ),
                     const SizedBox(height: 15),
                     TextField(
                       controller: phoneController,
                       decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                     ),
                     const SizedBox(height: 20),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Account Status:', style: TextStyle(fontSize: 16)),
                         DropdownButton<String>(
                           value: status,
                           items: ['Active', 'Suspended', 'Pending'].map((String value) {
                             return DropdownMenuItem<String>(
                               value: value,
                               child: Text(value),
                             );
                           }).toList(),
                           onChanged: (newValue) {
                             if (newValue != null) {
                               setStateDialog(() => status = newValue);
                             }
                           },
                         ),
                       ],
                     ),
                   ],
                 ),
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                 ),
                 ElevatedButton(
                   onPressed: () {
                     setState(() {
                       _users[index] = {
                         'id': user['id'],
                         'name': nameController.text.trim().isEmpty ? 'Unknown User' : nameController.text.trim(),
                         'email': emailController.text.trim(),
                         'phone': phoneController.text.trim(),
                         'joined': user['joined'],
                         'status': status,
                       };
                     });
                     _saveUsers();
                     Navigator.pop(context);
                   },
                   style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                   child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                 )
               ],
             );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

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
                const Text('Customer Users Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        elevation: 0,
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                _buildUsersTable(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return DataTable(
      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
      columns: const [
        DataColumn(label: Text('User ID', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Joined On', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: _users.asMap().entries.map((entry) {
        int idx = entry.key;
        Map<String, dynamic> user = entry.value;
        return _buildUserRow(idx, user);
      }).toList(),
    );
  }

  DataRow _buildUserRow(int index, Map<String, dynamic> user) {
    Color getStatusColor(String status) {
      if (status == 'Active') return Colors.green;
      if (status == 'Suspended') return Colors.red;
      if (status == 'Pending') return Colors.orange;
      return Colors.grey;
    }

    Color statusColor = getStatusColor(user['status']);
    String initial = user['name'].toString().isNotEmpty ? user['name'][0] : '?';

    return DataRow(
      cells: [
        DataCell(Text(user['id'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey))),
        DataCell(Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF4CA1AF).withOpacity(0.2),
              child: Text(initial, style: const TextStyle(fontSize: 10, color: Color(0xFF4CA1AF), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text(user['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
        DataCell(Text(user['email'], style: const TextStyle(color: Colors.black54))),
        DataCell(Text(user['phone'])),
        DataCell(Text(user['joined'], style: const TextStyle(color: Colors.black54))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(user['status'], style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF4CA1AF), size: 18),
                tooltip: 'Edit Profile',
                onPressed: () => _editUserDialog(user, index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(user['status'] == 'Suspended' ? Icons.settings_backup_restore : Icons.block, color: user['status'] == 'Suspended' ? Colors.green : Colors.red, size: 18),
                tooltip: user['status'] == 'Suspended' ? 'Unsuspend' : 'Suspend User',
                onPressed: () {
                  setState(() {
                    _users[index]['status'] = user['status'] == 'Suspended' ? 'Active' : 'Suspended';
                  });
                  _saveUsers();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          )
        ),
      ],
    );
  }
}
