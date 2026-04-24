import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';


class OrderDetailView extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailView({super.key, required this.orderData});

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.orderData['status'] ?? 'Pending';
  }

  Future<void> _updateStatus(String newStatus) async {
    final orderId = widget.orderData['orderId'] ?? widget.orderData['order_id'];
    if (orderId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});
      setState(() {
        _currentStatus = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $newStatus')),
      );

      // Notify the specific user about their order status update
      final String userId = widget.orderData['userId'] ?? '';
      if (userId.isNotEmpty) {
        await NotificationService.notifyUser(
          userId: userId,
          title: 'Order $newStatus',
          message: 'Your order #${orderId.toString().substring(orderId.toString().length > 6 ? orderId.toString().length - 6 : 0)} status has been updated to $newStatus.',
          type: 'order',
          metadata: {'orderId': orderId},
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final dynamic rawTimestamp = data['createdAt'];
    String dateStr = 'N/A';
    if (rawTimestamp is Timestamp) {
      dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(rawTimestamp.toDate());
    } else if (rawTimestamp is String) {
      try {
        final dt = DateTime.parse(rawTimestamp);
        dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text('Order #${data['orderId'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF111C43), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111C43)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _buildStatusChip(_currentStatus),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Order Items
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionCard(
                        title: 'Order Items (${items.length})',
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildItemRow(item);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Status Management',
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatusActionButton('Pending', Colors.orange),
                            _buildStatusActionButton('Confirmed', Colors.blue),
                            _buildStatusActionButton('Shipped', Colors.indigo),
                            _buildStatusActionButton('Delivered', Colors.green),
                            _buildStatusActionButton('Cancelled', Colors.red),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right Column: Customer & Payment Info
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildSectionCard(
                        title: 'Customer Details',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailItem(Icons.person_outline, 'Name', data['userName'] ?? 'N/A'),
                            _buildDetailItem(Icons.fingerprint, 'User ID', data['userId'] ?? 'N/A'),
                            _buildDetailItem(Icons.location_on_outlined, 'Address Type', data['addressType'] ?? 'N/A'),
                            _buildDetailItem(Icons.map_outlined, 'Full Address', data['address'] ?? 'N/A', isLong: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Payment Summary',
                        child: Column(
                          children: [
                            _buildPriceRow('Subtotal', '₹${data['totalAmount'] ?? '0'}'),
                            _buildPriceRow('Delivery Fee', '₹0'),
                            _buildPriceRow('Discount', '-₹0', isDiscount: true),
                            const Divider(height: 32),
                            _buildPriceRow('Total Amount', '₹${data['totalAmount'] ?? '0'}', isTotal: true),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.payment, size: 20, color: Color(0xFF111C43)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['paymentMode'] ?? 'UPI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('ID: ${data['transactionId'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Order Timeline',
                        child: Column(
                          children: [
                            _buildTimelineItem('Ordered on', dateStr, true),
                            _buildTimelineItem('Status Updated', DateFormat('MMM dd, hh:mm a').format(DateTime.now()), false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111C43))),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] ?? item['image_url'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FE),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag_outlined))
                : const Icon(Icons.shopping_bag_outlined),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(item['category'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${item['price']?.toString().replaceAll('₹', '') ?? '0'} x ${item['quantity'] ?? 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Total: ₹${(double.tryParse(item['price']?.toString().replaceAll('₹', '') ?? '0') ?? 0) * (item['quantity'] ?? 1)}', style: const TextStyle(color: Color(0xFF4CA1AF), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? const Color(0xFF111C43) : Colors.grey, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: isDiscount ? Colors.red : (isTotal ? const Color(0xFF4CA1AF) : const Color(0xFF111C43)), fontSize: isTotal ? 20 : 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String time, bool isLast) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(color: Color(0xFF4CA1AF), shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(width: 2, height: 30, color: const Color(0xFF4CA1AF).withOpacity(0.2)),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'Delivered') color = Colors.green;
    if (status == 'Cancelled') color = Colors.red;
    if (status == 'Shipped') color = Colors.indigo;
    if (status == 'Confirmed') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildStatusActionButton(String status, Color color) {
    final isSelected = _currentStatus == status;
    return InkWell(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Text(
          status,
          style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
