import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BulkUploadView extends StatefulWidget {
  const BulkUploadView({super.key});

  @override
  State<BulkUploadView> createState() => _BulkUploadViewState();
}

class _BulkUploadViewState extends State<BulkUploadView> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isUploading = false;
  String _statusMessage = '';

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

      for (var item in products) {
        final Map<String, dynamic> productData = Map<String, dynamic>.from(item);
        productData['createdAt'] ??= FieldValue.serverTimestamp();
        productData['updatedAt'] = FieldValue.serverTimestamp();
        
        final docRef = collection.doc(); // Generate new doc ID
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
