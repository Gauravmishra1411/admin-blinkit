import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_view.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
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
                const Text('Live Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          hintText: 'Search order ID or customer',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No orders found.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
                      columns: const [
                        DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildOrderRow(
                          context,
                          data,
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  DataRow _buildOrderRow(BuildContext context, Map<String, dynamic> data) {
    final id = data['orderId'] ?? data['order_id'] ?? 'N/A';
    final date = data['createdAt'] ?? data['order_date'];
    final customer = data['userName'] ?? data['user_name'] ?? 'Guest';
    final amount = (data['totalAmount'] ?? data['total_amount'] ?? 0).toString();
    final status = data['status'] ?? data['order_status'] ?? 'Pending';

    String formattedDate = 'N/A';
    if (date is Timestamp) {
      formattedDate = DateFormat('MMM dd, hh:mm a').format(date.toDate());
    }

    Color statusColor = Colors.orange;
    if (status.toLowerCase().contains('online') || status.toLowerCase().contains('delivered')) {
      statusColor = Colors.green;
    } else if (status.toLowerCase().contains('cash') || status.toLowerCase().contains('pending')) {
      statusColor = Colors.orange;
    } else if (status.toLowerCase().contains('cancelled')) {
      statusColor = Colors.red;
    }

    return DataRow(
      cells: [
        DataCell(Text(id, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(formattedDate, style: const TextStyle(color: Colors.black54))),
        DataCell(Text(customer)),
        DataCell(Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ),
        DataCell(
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailView(orderData: data),
                ),
              );
            },
            child: const Text('View Details'),
          )
        ),
      ],
    );
  }
}

