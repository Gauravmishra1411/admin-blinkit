import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/notification_service.dart';


class BannersView extends StatefulWidget {
  const BannersView({super.key});

  @override
  State<BannersView> createState() => _BannersViewState();
}

class _BannersViewState extends State<BannersView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _offerController = TextEditingController();
  Uint8List? _bannerImageBytes;
  bool _isLoading = false;

  Future<String?> _uploadToCloudinary(Uint8List imageBytes) async {
    final cloudName = (dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').trim();
    final apiKey = (dotenv.env['CLOUDINARY_API_KEY'] ?? '').trim();
    final apiSecret = (dotenv.env['CLOUDINARY_API_SECRET'] ?? '').trim();
    final uploadPreset = (dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '').trim();
    final folder = (dotenv.env['CLOUDINARY_FOLDER'] ?? 'banners').trim();

    if (cloudName == null || apiKey == null || apiSecret == null) {
      debugPrint('Cloudinary credentials missing in .env');
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = _generateSignature(timestamp, apiSecret, folder);

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = apiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'banner.jpg'));

    try {
      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = utf8.decode(responseData);
      final jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        final errorMsg = jsonResponse['error']?['message'] ?? 'Unknown Cloudinary error';
        debugPrint('Cloudinary Upload Failed: $errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  String _generateSignature(int timestamp, String apiSecret, String folder) {
    final params = 'folder=$folder&timestamp=$timestamp$apiSecret';
    return sha1.convert(utf8.encode(params)).toString();
  }

  Future<void> _saveBanner({String? bannerId, String? existingImageUrl}) async {
    if (_titleController.text.isEmpty || (_bannerImageBytes == null && existingImageUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least a title and an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = existingImageUrl;
      if (_bannerImageBytes != null) {
        imageUrl = await _uploadToCloudinary(_bannerImageBytes!);
        if (imageUrl == null) throw Exception('Failed to upload image to Cloudinary');
      }

      final data = {
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'offer': _offerController.text.trim(),
        'img': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (bannerId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['isActive'] = true; // Enabled by default
        await FirebaseFirestore.instance.collection('banners').add(data);
        
        // Notify all users about the new handpicked banner
        await NotificationService.notifyAllUsers(
          title: 'Handpicked product just for you!',
          message: 'Check out: ${_titleController.text.trim()} - ${_subtitleController.text.trim()}',
          type: 'offer',
        );
      } else {

        await FirebaseFirestore.instance.collection('banners').doc(bannerId).update(data);
      }

      _titleController.clear();
      _subtitleController.clear();
      _offerController.clear();
      setState(() => _bannerImageBytes = null);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bannerId == null ? 'Banner added successfully!' : 'Banner updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving banner: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBannerActive(String id, bool currentValue) async {
    try {
      await FirebaseFirestore.instance.collection('banners').doc(id).update({
        'isActive': !currentValue,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling status: $e')),
      );
    }
  }

  Future<void> _deleteBanner(String id) async {
    try {
      await FirebaseFirestore.instance.collection('banners').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting banner: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Handpicked Banners',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111C43)),
            ),
            ElevatedButton.icon(
              onPressed: () => _showBannerDialog(),
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add New Banner'),
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
            stream: FirebaseFirestore.instance.collection('banners').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No banners found. Add some to show them in the gallery!'));
              }

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: MediaQuery.of(context).size.width > 600 ? 2.2 : 1.5,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final bannerId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  final bool isActive = data['isActive'] ?? true;

                  return Opacity(
                    opacity: isActive ? 1.0 : 0.6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                        border: isActive ? null : Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                            child: ColorFiltered(
                              colorFilter: isActive 
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                : const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      1, 0,
                                  ]),
                              child: Image.network(
                                data['img'] ?? '',
                                width: 140,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 140, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Switch(
                                        value: isActive,
                                        onChanged: (val) => _toggleBannerActive(bannerId, isActive),
                                        activeColor: const Color(0xFF4CA1AF),
                                      ),
                                    ],
                                  ),
                                  Text(data['subtitle'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(data['offer'] ?? '', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                            onPressed: () => _showBannerDialog(bannerId: bannerId, data: data),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () => _deleteBanner(bannerId),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _showBannerDialog({String? bannerId, Map<String, dynamic>? data}) {
    if (data != null) {
      _titleController.text = data['title'] ?? '';
      _subtitleController.text = data['subtitle'] ?? '';
      _offerController.text = data['offer'] ?? '';
    } else {
      _titleController.clear();
      _subtitleController.clear();
      _offerController.clear();
    }
    _bannerImageBytes = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(bannerId == null ? 'Add Handpicked Banner' : 'Edit Handpicked Banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Banner Title')),
                TextField(controller: _subtitleController, decoration: const InputDecoration(labelText: 'Subtitle')),
                TextField(controller: _offerController, decoration: const InputDecoration(labelText: 'Offer (e.g. 50% OFF)')),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setDialogState(() => _bannerImageBytes = bytes);
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: _bannerImageBytes != null
                        ? Image.memory(_bannerImageBytes!, fit: BoxFit.cover)
                        : (data != null && data['img'] != null)
                            ? Image.network(data['img'], fit: BoxFit.cover)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  Text('Tap to select image', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _saveBanner(bannerId: bannerId, existingImageUrl: data?['img']),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Banner'),
            ),
          ],
        ),
      ),
    );
  }
}
