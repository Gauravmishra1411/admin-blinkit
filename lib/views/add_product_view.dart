import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddProductView extends StatefulWidget {
  final Map<String, dynamic>? product;
  final int? index;
  final bool initialIsRecent;

  const AddProductView({super.key, this.product, this.index, this.initialIsRecent = true});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  late TextEditingController nameController;
  late TextEditingController categoryController;
  late TextEditingController descriptionController;
  late TextEditingController longDescriptionController;
  late TextEditingController mrpController;
  late TextEditingController discountPriceController;
  late TextEditingController productCodeController;
  late TextEditingController stockController;
  late TextEditingController discountPercentController;
  late TextEditingController discountTypeController;

  bool inStock = true;
  Uint8List? mainImageBytes;
  List<Uint8List> galleryImagesBytes = [];
  List<Map<String, dynamic>> variations = [];
  bool isUploading = false;
  bool isVisible = true;
  bool isRecent = true;
  bool bumpToTop = false; // New variable to track bumping
  List<String> existingGalleryUrls = [];

  List<String> selectedSizes = [];
  String selectedGender = 'Unisex';
  String selectedCategory = 'Jacket';
  List<String> categories = ['Jacket', 'Shirt', 'Trousers', 'Shoes'];

  @override
  void initState() {
    super.initState();
    isRecent = widget.initialIsRecent;
    final bool isEdit = widget.product != null;
    double _toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    nameController = TextEditingController(text: isEdit ? (widget.product!['name'] ?? widget.product!['title'] ?? widget.product!['productName'] ?? '') : '');
    categoryController = TextEditingController(text: isEdit ? widget.product!['category'] : '');
    descriptionController = TextEditingController(text: isEdit ? (widget.product!['description'] ?? '') : '');
    longDescriptionController = TextEditingController(text: isEdit ? (widget.product!['longDescription'] ?? '') : '');
    mrpController = TextEditingController(text: isEdit ? widget.product!['mrp']?.toString() : '');
    discountPriceController = TextEditingController(text: isEdit ? widget.product!['discountPrice']?.toString() : '');
    productCodeController = TextEditingController(text: isEdit ? (widget.product!['productCode'] ?? '') : '');
    stockController = TextEditingController(text: isEdit ? widget.product!['stock']?.toString() : '');
    discountPercentController = TextEditingController(text: isEdit ? (widget.product!['discountPercent']?.toString() ?? '') : '');
    discountTypeController = TextEditingController(text: isEdit ? (widget.product!['discountType'] ?? '') : '');

    if (isEdit) {
      inStock = widget.product!['inStock'] ?? true;
      mainImageBytes = widget.product!['imageBytes'];
      galleryImagesBytes = widget.product!['galleryBytes'] != null 
          ? List<Uint8List>.from(widget.product!['galleryBytes']) 
          : [];
      variations = widget.product!['variations'] != null 
          ? List<Map<String, dynamic>>.from(widget.product!['variations']) 
          : [];
      selectedSizes = List<String>.from(widget.product!['selectedSizes'] ?? []);
      selectedGender = widget.product!['gender'] ?? 'Unisex';
      isVisible = widget.product!['isVisible'] ?? true;
      isRecent = widget.product!['isRecent'] ?? true;
      existingGalleryUrls = List<String>.from(
        (widget.product!['galleryUrls'] is List) 
        ? widget.product!['galleryUrls'] 
        : (widget.product!['gallery'] is List) ? widget.product!['gallery'] : []
      );
      
      // Fix for Dropdown error: Ensure the loaded category is in the list
      String? loadedCategory = widget.product!['category'];
      if (loadedCategory != null && loadedCategory.isNotEmpty) {
        selectedCategory = loadedCategory;
        if (!categories.contains(selectedCategory)) {
          categories.add(selectedCategory);
        }
      }

      // Fix for Discount Type dropdown
      String? loadedDiscountType = widget.product!['discountType'];
      if (loadedDiscountType != null && loadedDiscountType.isNotEmpty) {
        discountTypeController.text = loadedDiscountType;
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    longDescriptionController.dispose();
    mrpController.dispose();
    discountPriceController.dispose();
    productCodeController.dispose();
    stockController.dispose();
    discountPercentController.dispose();
    discountTypeController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes, String filename) async {
    try {
      final cloudName = (dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').trim();
      final apiKey = (dotenv.env['CLOUDINARY_API_KEY'] ?? '').trim();
      final apiSecret = (dotenv.env['CLOUDINARY_API_SECRET'] ?? '').trim();
      final folder = (dotenv.env['CLOUDINARY_FOLDER'] ?? 'demo_Project').trim();
      
      if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
        _showErrorDialog('Cloudinary Config Error', 'Missing Cloudinary credentials in .env file.');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // IMPORTANT: Parameters must be in alphabetical order for the signature
      // f (folder) comes before t (timestamp)
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
      final responseString = utf8.decode(responseData);
      final jsonMap = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonMap['secure_url'];
      } else {
        final errorMsg = jsonMap['error']?['message'] ?? 'Unknown Error';
        _showErrorDialog('Cloudinary Error', errorMsg);
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      _showErrorDialog('Upload Exception', e.toString());
      return null;
    }
  }

  Future<String?> _uploadUrlToCloudinary(String url) async {
    try {
      if (url.contains('cloudinary.com')) return url; // Already on Cloudinary
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return await _uploadImageToCloudinary(response.bodyBytes, 'synced_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      return url; // Fallback to original if download fails
    } catch (e) {
      debugPrint('Error syncing URL to Cloudinary: $e');
      return url;
    }
  }

  void _showError(String message) {
    if (mounted) {
      _showErrorDialog('Upload Error', message);
    }
  }

  Future<List<String>> _uploadMultipleImagesToCloudinary(List<Uint8List> imagesList) async {
    List<String> urls = [];
    for (int i = 0; i < imagesList.length; i++) {
      final url = await _uploadImageToCloudinary(imagesList[i], 'product_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<void> _saveToFirebase() async {
    if (nameController.text.isEmpty) {
      _showErrorDialog('Validation Error', 'Please enter a product name.');
      return;
    }

    // Check Authentication
    if (FirebaseAuth.instance.currentUser == null) {
       _showErrorDialog('Auth Error', 'You must be logged in to save products. Please go back to login screen.');
       return;
    }

    setState(() => isUploading = true);
    
    try {
      String mainUrl = widget.product?['imageUrl'] ?? widget.product?['mainImage'] ?? '';
      
      // Upload main image if a new one was picked (mainImageBytes is not null)
      if (mainImageBytes != null) {
        final url = await _uploadImageToCloudinary(mainImageBytes!, 'main_${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (url == null) {
          setState(() => isUploading = false);
          return; 
        }
        mainUrl = url;
      } else if (mainUrl.isNotEmpty) {
        // If it's an existing URL, sync it to Cloudinary if it isn't already
        final syncedUrl = await _uploadUrlToCloudinary(mainUrl);
        if (syncedUrl != null) mainUrl = syncedUrl;
      }

      // Process Gallery: Mix of existing and new
      List<String> finalGalleryUrls = [];
      
      // 1. Existing URLs (Sync them to Cloudinary if they aren't already)
      for (String url in existingGalleryUrls) {
        final syncedUrl = await _uploadUrlToCloudinary(url);
        if (syncedUrl != null) finalGalleryUrls.add(syncedUrl);
      }

      // 2. New Bytes
      if (galleryImagesBytes.isNotEmpty) {
         final urls = await _uploadMultipleImagesToCloudinary(galleryImagesBytes);
         finalGalleryUrls.addAll(urls);
      }

      final productData = {
        'name': nameController.text,
        'category': selectedCategory,
        'description': descriptionController.text,
        'mrp': double.tryParse(mrpController.text) ?? 0.0,
        'discountPercent': discountPercentController.text,
        'discountType': discountTypeController.text,
        'stock': int.tryParse(stockController.text) ?? 0,
        'inStock': inStock,
        'imageUrl': mainUrl,
        'galleryUrls': finalGalleryUrls,
        'gender': selectedGender,
        'selectedSizes': selectedSizes,
        'variations': variations,
        'productCode': productCodeController.text,
        'isVisible': isVisible,
        'isRecent': isRecent,
        'recentAddedAt': isRecent 
            ? (bumpToTop ? FieldValue.serverTimestamp() : (widget.product?['recentAddedAt'] ?? FieldValue.serverTimestamp())) 
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.product == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('product').add(productData);
      } else {
        final String? docId = widget.product!['id'];
        if (docId != null) {
          await FirebaseFirestore.instance.collection('product').doc(docId).update(productData);
        } else {
          await FirebaseFirestore.instance.collection('product').add(productData);
        }
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success!'),
            content: const Text('Product has been saved successfully to the database.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
      _showErrorDialog('Firestore Error', 'Failed to save to database: $e');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.home_filled, color: Colors.black, size: 24),
            const SizedBox(width: 10),
            const Text('Add New Product', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          _buildTopButton('Save Draf', Icons.save_alt, Colors.white, Colors.black, false),
          const SizedBox(width: 10),
          _buildTopButton('Seed Data', Icons.storage, Colors.orange.shade100, Colors.black, false, isSeed: true),
          const SizedBox(width: 10),
          const SizedBox(width: 10),
          if (isUploading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
          _buildTopButton('Add Product', Icons.check, const Color(0xFFC0F0C0), Colors.black, true),
          const SizedBox(width: 20),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildGeneralInfoSection(),
                      const SizedBox(height: 20),
                      _buildPricingStockSection(),
                      const SizedBox(height: 20),
                      _buildVariantsSection(),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                // Right Column
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildUploadImageSection(),
                      const SizedBox(height: 20),
                      _buildCategorySection(),
                      const SizedBox(height: 20),
                      _buildVisibilitySection(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Bottom Save Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : _saveToFirebase,
                icon: isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  isUploading ? 'Uploading Product...' : (widget.product == null ? 'Publish Product to Store' : 'Update Product Details'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111C43),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
      if (isUploading)
        Container(
          color: Colors.black26,
          child: const Center(
            child: Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4CA1AF)),
                    SizedBox(height: 16),
                    Text('Saving Product...', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Uploading images and syncing with database', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _buildVariantsSection() {
    return _buildContainerSection(
      title: 'Product Variants (Variable Products)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Define variations like Color, size, etc. with specific prices.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFB0F0B0)), onPressed: () => setState(() => variations.add({'type': '', 'value': '', 'price': ''}))),
            ],
          ),
          const SizedBox(height: 10),
          ...variations.asMap().entries.map((entry) {
            int idx = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _buildStyledTextField(null, 'Type (e.g. Color)', initialValue: variations[idx]['type'], onChanged: (v) => variations[idx]['type'] = v)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStyledTextField(null, 'Value (e.g. Red)', initialValue: variations[idx]['value'], onChanged: (v) => variations[idx]['value'] = v)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStyledTextField(null, 'Extra Price', prefixText: '+ \$ ', initialValue: variations[idx]['price'], onChanged: (v) => variations[idx]['price'] = v)),
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => variations.removeAt(idx))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopButton(String label, IconData icon, Color bgColor, Color textColor, bool isPrimary, {bool isSeed = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: isSeed ? _seedData : (isPrimary ? _saveToFirebase : null),
        icon: Icon(icon, size: 18, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.black12)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Future<void> _seedData() async {
    final List<Map<String, dynamic>> productsToSeed = [
      {
        "category": "Shirt",
        "createdAt": FieldValue.serverTimestamp(),
        "description": "Stylish casual shirt for men",
        "discountPercent": "20",
        "discountType": "Summer Sale",
        "galleryUrls": [
          "https://picsum.photos/seed/shirt1/500",
          "https://picsum.photos/seed/shirt1b/500"
        ],
        "gender": "Men",
        "imageUrl": "https://picsum.photos/seed/shirt1/500",
        "inStock": true,
        "mrp": 999.0,
        "name": "Casual Cotton Shirt 1",
        "productCode": "SHIRT001",
        "selectedSizes": ["S", "M", "L"],
        "stock": 50,
        "updatedAt": FieldValue.serverTimestamp(),
        "variations": [
          {
            "price": "799",
            "type": "color",
            "value": "Blue"
          }
        ]
      },
      {
        "category": "Shirt",
        "createdAt": FieldValue.serverTimestamp(),
        "description": "Premium formal shirt",
        "discountPercent": "30",
        "discountType": "Festive Offer",
        "galleryUrls": [
          "https://picsum.photos/seed/shirt2/500",
          "https://picsum.photos/seed/shirt2b/500"
        ],
        "gender": "Men",
        "imageUrl": "https://picsum.photos/seed/shirt2/500",
        "inStock": true,
        "mrp": 1299.0,
        "name": "Formal Shirt 2",
        "productCode": "SHIRT002",
        "selectedSizes": ["M", "L", "XL"],
        "stock": 40,
        "updatedAt": FieldValue.serverTimestamp(),
        "variations": [
          {
            "price": "999",
            "type": "color",
            "value": "White"
          }
        ]
      }
    ];

    setState(() => isUploading = true);
    try {
      for (var product in productsToSeed) {
        await FirebaseFirestore.instance.collection('product').add(product);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully seeded 2 products!')),
        );
      }
    } catch (e) {
      _showErrorDialog('Seeding Error', e.toString());
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Widget _buildGeneralInfoSection() {
    return _buildContainerSection(
      title: 'General Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Name Product'),
          _buildStyledTextField(nameController, 'Puffer Jacket With Pocket Detail'),
          const SizedBox(height: 20),
          _buildLabel('Description Product'),
          _buildStyledTextField(descriptionController, 'Write description here...', maxLines: 5),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Size'),
                    const Text('Pick Available Size', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildSizeSelector(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Gender'),
                    const Text('Pick Available Gender', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildGenderSelector(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingStockSection() {
    return _buildContainerSection(
      title: 'Pricing And Stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Base Pricing'),
                    _buildStyledTextField(mrpController, '\$47.55', prefixText: '\$ '),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Stock'),
                    _buildStyledTextField(stockController, '77'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Discount'),
                    _buildStyledTextField(discountPercentController, '10%', prefixText: '% '),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Discount Type'),
                    _buildDropdownField(
                        discountTypeController, 
                        discountTypeController.text.isEmpty ? 'Flash Sale' : discountTypeController.text, 
                        ['Seasonal Discount', 'Chinese New Year Discount', 'Flash Sale'].contains(discountTypeController.text) 
                            ? ['Seasonal Discount', 'Chinese New Year Discount', 'Flash Sale']
                            : [...['Seasonal Discount', 'Chinese New Year Discount', 'Flash Sale'], if (discountTypeController.text.isNotEmpty) discountTypeController.text]
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadImageSection() {
    String? imageUrl = widget.product?['imageUrl'] ?? 
                      widget.product?['mainImage'] ?? 
                      widget.product?['image'] ??
                      (widget.product?['galleryUrls'] != null && (widget.product!['galleryUrls'] as List).isNotEmpty ? widget.product!['galleryUrls'][0] : null);

    return _buildContainerSection(
      title: 'Product Photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Main Image (Click box to upload)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickMainImage,
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: mainImageBytes != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(mainImageBytes!, fit: BoxFit.contain))
                  : (imageUrl != null && imageUrl.isNotEmpty)
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red))))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 50, color: Color(0xFF4CA1AF)),
                            SizedBox(height: 10),
                            Text('Click to upload main image', style: TextStyle(color: Color(0xFF4CA1AF), fontSize: 12)),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Gallery Images', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Gallery from URL (existing)
                ...existingGalleryUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildThumbnail(url: url, onDelete: () => setState(() => existingGalleryUrls.remove(url))),
                )),
                // Gallery from local bytes (newly picked)
                ...galleryImagesBytes.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildThumbnail(bytes: entry.value, onDelete: () => setState(() => galleryImagesBytes.removeAt(entry.key))),
                )),
                _buildAddImageButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return _buildContainerSection(
      title: 'Category',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Product Category'),
          _buildDropdownField(null, selectedCategory, categories, onChanged: (v) => setState(() => selectedCategory = v!)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final newCategoryController = TextEditingController();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Add New Category'),
                  content: TextField(
                    controller: newCategoryController,
                    decoration: const InputDecoration(hintText: 'Category name (e.g. Grocery, Beauty)'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        if (newCategoryController.text.isNotEmpty) {
                          setState(() {
                            if (!categories.contains(newCategoryController.text)) {
                              categories.add(newCategoryController.text);
                            }
                            selectedCategory = newCategoryController.text;
                          });
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB0F0B0),
              elevation: 0,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Add Category', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildContainerSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildStyledTextField(TextEditingController? controller, String hint, {int maxLines = 1, String? prefixText, Function(String)? onChanged, String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }

  Widget _buildSizeSelector() {
    final sizes = ['XS', 'S', 'M', 'XL', 'XXL'];
    return Wrap(
      spacing: 8,
      children: sizes.map((s) {
        bool isSelected = selectedSizes.contains(s);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedSizes.remove(s);
              } else {
                selectedSizes.add(s);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFB0F0B0) : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(s, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenderSelector() {
    final options = ['Men', 'Woman', 'Unisex'];
    return Row(
      children: options.map((o) {
        bool isSelected = selectedGender == o;
        return Padding(
          padding: const EdgeInsets.only(right: 15),
          child: GestureDetector(
            onTap: () => setState(() => selectedGender = o),
            child: Row(
              children: [
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: isSelected ? const Color(0xFFB0F0B0) : Colors.grey),
                const SizedBox(width: 5),
                Text(o, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownField(TextEditingController? controller, String value, List<String> items, {Function(String?)? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged ?? (val) {
            if (controller != null) controller.text = val!;
          },
        ),
      ),
    );
  }

  Widget _buildThumbnail({Uint8List? bytes, String? url, VoidCallback? onDelete}) {
    return Stack(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: bytes != null 
                ? MemoryImage(bytes) as ImageProvider
                : NetworkImage(url!) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(color: Colors.black26, child: const Icon(Icons.close, size: 14, color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMainImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => mainImageBytes = bytes);
    }
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: () async {
        final images = await ImagePicker().pickMultiImage();
        if (images.isNotEmpty) {
          for (var img in images) {
            final bytes = await img.readAsBytes();
            setState(() {
              // Always add to gallery when using the multi-picker button
              galleryImagesBytes.add(bytes);
            });
          }
        }
      },
      child: Container(
        height: 60, width: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Color(0xFFB0F0B0)),
      ),
    );
  }

  Widget _buildVisibilitySection() {
    return _buildContainerSection(
      title: 'Status & Visibility',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Show on User App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Toggle product visibility for customers', style: TextStyle(fontSize: 12)),
            value: isVisible,
            activeColor: const Color(0xFF4CA1AF),
            onChanged: (val) => setState(() => isVisible = val),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Mark as Recent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Display in "Recently Added" section', style: TextStyle(fontSize: 12)),
            value: isRecent,
            activeColor: const Color(0xFF4CA1AF),
            onChanged: (val) => setState(() => isRecent = val),
          ),
          if (widget.product != null && isRecent)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Checkbox(
                    value: bumpToTop,
                    activeColor: const Color(0xFF4CA1AF),
                    onChanged: (val) => setState(() => bumpToTop = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Bump to Top (Refresh recent timestamp)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
