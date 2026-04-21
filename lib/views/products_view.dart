import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_product_view.dart';
import 'bulk_upload_view.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 300,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, category, or brand...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _seedData(),
                  icon: const Icon(Icons.storage),
                  label: const Text('Seed Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddProduct(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('product').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              
              // Local Search Filtering
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? data['title'] ?? '').toString().toLowerCase();
                final category = (data['category'] ?? '').toString().toLowerCase();
                final brand = (data['brand'] ?? '').toString().toLowerCase();
                final description = (data['description'] ?? '').toString().toLowerCase();

                return name.contains(_searchQuery) || 
                       category.contains(_searchQuery) || 
                       brand.contains(_searchQuery) ||
                       description.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 60, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(_searchQuery.isEmpty ? 'No products found.' : 'No results for "$_searchQuery"'),
                    ],
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final id = filteredDocs[index].id;
                  data['id'] = id; 
                  return _buildProductCard(data, id);
                },
              );
            },
          ),
        )
      ],
    );
  }

  Future<void> _navigateToAddProduct({Map<String, dynamic>? product}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductView(product: product),
      ),
    );
  }

  Future<void> _seedData() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BulkUploadView(),
      ),
    );
  }

  void _showProductStats(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: 450,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Product Stats',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111C43)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('Performance over the last 7 days', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (value.toInt() >= 0 && value.toInt() < days.length) {
                              return Text(
                                days[value.toInt()], 
                                style: const TextStyle(color: Colors.grey, fontSize: 12)
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) => Text(
                            '${value.toInt() * 10}', 
                            style: const TextStyle(color: Colors.grey, fontSize: 12)
                          ),
                          reservedSize: 42,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 1),
                          FlSpot(1, 3),
                          FlSpot(2, 2),
                          FlSpot(3, 4),
                          FlSpot(4, 3.5),
                          FlSpot(5, 4.5),
                          FlSpot(6, 4),
                        ],
                        isCurved: true,
                        gradient: const LinearGradient(colors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)]),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [const Color(0xFF4CA1AF).withOpacity(0.2), const Color(0xFF2C3E50).withOpacity(0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Sales', '124', Colors.blue),
                  _buildStatItem('Conversion', '3.2%', Colors.green),
                  _buildStatItem('Returns', '2', Colors.red),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _deleteProduct(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('product').doc(id).delete();
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildProductCard(Map<String, dynamic> product, String id) {
    final bool inStock = product['inStock'] ?? true;
    final String imageUrl = product['imageUrl'] ?? 
                           product['mainImage'] ?? 
                           product['image'] ?? 
                           (product['galleryUrls'] != null && (product['galleryUrls'] as List).isNotEmpty ? product['galleryUrls'][0] : '') ??
                           '';
    final double mrp = _toDouble(product['mrp']);
    final String discountPercent = product['discountPercent']?.toString() ?? '0';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F7FE),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: imageUrl.isNotEmpty 
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.black26)),
                      )
                    : const Center(child: Icon(Icons.image_outlined, size: 50, color: Colors.black26)),
                ),
                // Image Count Badge
                if (product['gallery'] != null && (product['gallery'] as List).length > 1)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            '${(product['gallery'] as List).length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _buildCardAction(Icons.bar_chart, Colors.indigo, () => _showProductStats(product)),
                      const SizedBox(width: 8),
                      _buildCardAction(Icons.delete, Colors.red, () => _deleteProduct(id)),
                      const SizedBox(width: 8),
                      _buildCardAction(Icons.edit, const Color(0xFF4CA1AF), () => _navigateToAddProduct(product: product)),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product['name'] ?? product['title'] ?? product['productName'] ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Category: ${product['category'] ?? 'N/A'}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\$${mrp.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CA1AF), fontSize: 18)),
                          if (discountPercent != '0' && discountPercent.isNotEmpty)
                             Text('-$discountPercent%', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: inStock ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inStock ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(color: inStock ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardAction(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(6),
        onPressed: onTap,
      ),
    );
  }
}
