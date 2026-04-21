import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorsView extends StatefulWidget {
  const VendorsView({super.key});

  @override
  State<VendorsView> createState() => _VendorsViewState();
}

class _VendorsViewState extends State<VendorsView> {
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? vendorsJson = prefs.getString('saved_vendors');

    if (vendorsJson != null) {
      final List<dynamic> decodedList = jsonDecode(vendorsJson);
      _vendors = List<Map<String, dynamic>>.from(decodedList);
    } else {
      _vendors = [
        {'name': 'Fresh Foods Outlet', 'category': 'Groceries', 'joined': 'Oct 20, 2024', 'status': 'Pending'},
        {'name': 'City Bakery Hub', 'category': 'Bakery', 'joined': 'Oct 21, 2024', 'status': 'Active'},
        {'name': 'Metro Dairy', 'category': 'Dairy', 'joined': 'Oct 22, 2024', 'status': 'Active'},
        {'name': 'Spice World', 'category': 'Groceries', 'joined': 'Oct 23, 2024', 'status': 'Pending'},
        {'name': 'Farmers Market Direct', 'category': 'Produce', 'joined': 'Oct 24, 2024', 'status': 'Suspended'},
      ];
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveVendors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_vendors', jsonEncode(_vendors));
  }

  void _showVendorDialog({Map<String, dynamic>? vendor, int? index}) {
    final bool isEdit = vendor != null;
    final nameController = TextEditingController(text: isEdit ? vendor['name'] : '');
    final categoryController = TextEditingController(text: isEdit ? vendor['category'] : '');
    String status = isEdit ? vendor['status'] : 'Pending';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEdit ? 'Edit Vendor' : 'Add New Vendor'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Vendor Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category (e.g. Groceries)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status:', style: TextStyle(fontSize: 16)),
                        DropdownButton<String>(
                          value: status,
                          items: ['Active', 'Pending', 'Suspended'].map((String value) {
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
                    final newVendor = {
                      'name': nameController.text.trim().isEmpty ? 'Unnamed Vendor' : nameController.text.trim(),
                      'category': categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                      'status': status,
                      'joined': isEdit ? vendor['joined'] : 'Just Now',
                    };

                    setState(() {
                      if (isEdit && index != null) {
                        _vendors[index] = newVendor;
                      } else {
                        _vendors.insert(0, newVendor); // Add new vendors to top
                      }
                    });
                    _saveVendors();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                  child: Text(isEdit ? 'Save Changes' : 'Add Vendor', style: const TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _updateVendorStatus(int index, String newStatus) {
    setState(() {
      _vendors[index]['status'] = newStatus;
    });
    _saveVendors();
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
                const Text('Vendors / Restaurants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showVendorDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vendor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _vendors.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _buildVendorTile(index);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVendorTile(int index) {
    final vendor = _vendors[index];
    bool isPending = vendor['status'] == 'Pending';
    bool isActive = vendor['status'] == 'Active';
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFF4CA1AF).withOpacity(0.1),
        child: const Icon(Icons.store, color: Color(0xFF4CA1AF)),
      ),
      title: Text(vendor['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Joined: ${vendor['joined']} • Category: ${vendor['category']}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isPending 
                ? Colors.orange.withOpacity(0.1) 
                : isActive 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPending ? 'Pending Approval' : isActive ? 'Active' : 'Suspended',
              style: TextStyle(
                color: isPending ? Colors.orange : isActive ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (isPending) ...[
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () => _updateVendorStatus(index, 'Active'),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Reject',
              onPressed: () => _updateVendorStatus(index, 'Suspended'),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'Edit Vendor',
              onPressed: () => _showVendorDialog(vendor: vendor, index: index),
            ),
          ]
        ],
      ),
    );
  }
}
