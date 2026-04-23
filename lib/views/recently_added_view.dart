import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_product_view.dart';

class RecentlyAddedView extends StatelessWidget {
  const RecentlyAddedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recently Added Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111C43),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Detailed list of products added to the store in chronological order.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddProductView()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Product', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CA1AF),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('product')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter and Sort Client-Side to avoid "Index Required" errors
                final docs = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isRecent'] == true;
                }).toList() ?? [];

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTime = aData['recentAddedAt'] ?? aData['createdAt'];
                  final bTime = bData['recentAddedAt'] ?? bData['createdAt'];
                  
                  // Handle both Timestamp and String types safely
                  DateTime parse(dynamic val) {
                    if (val is Timestamp) return val.toDate();
                    if (val is String) return DateTime.tryParse(val) ?? DateTime(1970);
                    return DateTime(1970);
                  }
                  
                  return parse(bTime).compareTo(parse(aTime));
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('No products added yet.'));
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FE)),
                      columns: const [
                        DataColumn(label: Text('Product Image', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Added On', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final dynamic rawCreatedAt = data['createdAt'];
                        final dynamic rawRecentAddedAt = data['recentAddedAt'];
                        String dateStr = 'N/A';
                        
                        dynamic dateToDisplay = rawRecentAddedAt ?? rawCreatedAt;
                        
                        if (dateToDisplay is Timestamp) {
                          dateStr = DateFormat('MMM dd, yyyy HH:mm').format(dateToDisplay.toDate());
                        } else if (dateToDisplay is String) {
                          try {
                            final dt = DateTime.parse(dateToDisplay);
                            dateStr = DateFormat('MMM dd, yyyy HH:mm').format(dt);
                          } catch (_) {}
                        }
                        
                        final imageUrl = data['imageUrl'] ?? data['mainImage'] ?? '';

                        return DataRow(cells: [
                          DataCell(
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade100,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 20))
                                  : const Icon(Icons.image, size: 20, color: Colors.grey),
                            ),
                          ),
                          DataCell(Text(data['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(data['category'] ?? 'N/A')),
                          DataCell(Text('\$${data['mrp'] ?? 0}')),
                          DataCell(Text(dateStr, style: const TextStyle(color: Colors.grey))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                  tooltip: 'Edit Product',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddProductView(
                                          product: data,
                                          initialIsRecent: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  tooltip: 'Remove from Recent',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove from Recent?'),
                                    content: const Text('This product will no longer show in the Recently Added section on the user app.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await doc.reference.update({'isRecent': false});
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
