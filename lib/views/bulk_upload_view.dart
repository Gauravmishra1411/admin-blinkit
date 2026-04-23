import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BulkUploadView extends StatefulWidget {
  const BulkUploadView({super.key});

  @override
  State<BulkUploadView> createState() => _BulkUploadViewState();
}

class _BulkUploadViewState extends State<BulkUploadView> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isUploading = false;
  String _statusMessage = '';

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes, String filename) async {
    try {
      final cloudName = (dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').trim();
      final apiKey = (dotenv.env['CLOUDINARY_API_KEY'] ?? '').trim();
      final apiSecret = (dotenv.env['CLOUDINARY_API_SECRET'] ?? '').trim();
      final folder = (dotenv.env['CLOUDINARY_FOLDER'] ?? 'bulk_uploads').trim();
      
      if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String signatureString = 'folder=$folder&timestamp=$timestamp$apiSecret';
      final String signature = sha1.convert(utf8.encode(signatureString)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp.toString()
        ..fields['folder'] = folder
        ..fields['signature'] = signature
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonMap = jsonDecode(utf8.decode(responseData));

      if (response.statusCode == 200) {
        return jsonMap['secure_url'];
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary Error: $e');
      return null;
    }
  }

  Future<String?> _syncUrlToCloudinary(String url) async {
    if (url.isEmpty || url.contains('cloudinary.com')) return url;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return await _uploadImageToCloudinary(response.bodyBytes, 'bulk_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  Future<void> _processBulkUpload() async {
    if (_jsonController.text.isEmpty) {
      _showError('Please paste some JSON data first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Parsing JSON...';
    });

    try {
      final decodedData = jsonDecode(_jsonController.text);
      if (decodedData is! List) throw 'JSON must be a list of objects [{}, {}]';

      final List<dynamic> products = decodedData;
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('product');

      setState(() => _statusMessage = 'Preparing batch for ${products.length} items...');

      for (int i = 0; i < products.length; i++) {
        final Map<String, dynamic> productData = Map<String, dynamic>.from(products[i]);
        
        setState(() => _statusMessage = 'Syncing images for product ${i + 1}/${products.length}...');
        
        // Sync Main Image
        if (productData['imageUrl'] != null) {
          productData['imageUrl'] = await _syncUrlToCloudinary(productData['imageUrl']);
        } else if (productData['mainImage'] != null) {
          productData['imageUrl'] = await _syncUrlToCloudinary(productData['mainImage']);
        }

        // Sync Gallery
        if (productData['galleryUrls'] is List) {
          List<String> syncedGallery = [];
          for (String url in List<String>.from(productData['galleryUrls'])) {
            syncedGallery.add(await _syncUrlToCloudinary(url) ?? url);
          }
          productData['galleryUrls'] = syncedGallery;
        }

        productData['createdAt'] ??= FieldValue.serverTimestamp();
        productData['updatedAt'] = FieldValue.serverTimestamp();
        productData['isVisible'] ??= true;
        productData['isRecent'] ??= false;
        
        final docRef = collection.doc(); 
        batch.set(docRef, productData);
      }

      setState(() => _statusMessage = 'Committing batch to Firestore...');
      await batch.commit();

      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'Success! Uploaded ${products.length} products in one batch.';
        });
        _jsonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully uploaded ${products.length} products!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = 'Error: $e';
      });
      _showError('Upload Failed: $e');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk JSON Upload'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste your JSON Array below:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _jsonController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '[\n  {\n    "name": "Product 1",\n    "mrp": 999,\n    ...\n  }\n]',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isUploading)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(_statusMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _processBulkUpload,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Submit Bulk Upload', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
