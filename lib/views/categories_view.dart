import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  Uint8List? _categoryImageBytes;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111C43)),
            ),
            ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA1AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('categories').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No custom categories found.\nAdd some to show them in the user app!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.2,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final colorStr = data['color'] as String? ?? '0xFFE8F5E9';
                  final color = Color(int.parse(colorStr));

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Image.network(
                              data['imageUrl'] ?? '',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: color.withOpacity(0.2),
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                data['label'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteCategory(docs[index].id),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    _colorController.text = '0xFFE8F5E9'; // Default color code
    _categoryImageBytes = null; // Reset picked image
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Category Label (e.g. Dairy)'),
                ),
                const SizedBox(height: 20),
                const Text('Category Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setDialogState(() {
                        _categoryImageBytes = bytes;
                      });
                      setState(() {
                        _categoryImageBytes = bytes;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _categoryImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_categoryImageBytes!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to pick from gallery', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: 'Color Hex (e.g. 0xFFE8F5E9)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _addCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA1AF),
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    try {
      final cloudName = (dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').trim();
      final apiKey = (dotenv.env['CLOUDINARY_API_KEY'] ?? '').trim();
      final apiSecret = (dotenv.env['CLOUDINARY_API_SECRET'] ?? '').trim();
      final folder = (dotenv.env['CLOUDINARY_FOLDER'] ?? 'demo_Project').trim();
      
      if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
        debugPrint('Missing Cloudinary credentials');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String signatureString = 'folder=$folder&timestamp=$timestamp$apiSecret';
      final String signature = sha1.convert(utf8.encode(signatureString)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp.toString()
        ..fields['folder'] = folder
        ..fields['signature'] = signature
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'category_${timestamp}.jpg'));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);
      final jsonMap = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonMap['secure_url'];
      } else {
        debugPrint('Cloudinary Error: ${jsonMap['error']?['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<void> _addCategory() async {
    if (_labelController.text.isEmpty || _categoryImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a label and pick an image')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Upload to Cloudinary first
      final String? imageUrl = await _uploadImageToCloudinary(_categoryImageBytes!);
      
      if (imageUrl == null) {
        throw Exception('Failed to upload image to Cloudinary');
      }

      // 2. Save to Firestore
      await FirebaseFirestore.instance.collection('categories').add({
        'label': _labelController.text,
        'imageUrl': imageUrl,
        'color': _colorController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      Navigator.pop(context);
      _labelController.clear();
      _colorController.clear();
      _categoryImageBytes = null;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await FirebaseFirestore.instance.collection('categories').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    }
  }
}
