import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseInitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeDatabase() async {
    // 1. Create a dummy User
    String userId = 'dummy_user_123';
    await _firestore.collection('users').doc(userId).set({
      'user_id': userId,
      'name': 'John Doe',
      'email': 'john@example.com',
      'phone': '+1234567890',
      'password_hash': 'hashed_password_here',
      'role': 'customer', // Added for security rules
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. Add an Address for the User
    String addressId = 'address_123';
    await _firestore.collection('users').doc(userId).collection('addresses').doc(addressId).set({
      'address_id': addressId,
      'user_id': userId,
      'full_address': '123 Main St, Apt 4B',
      'city': 'New York',
      'state': 'NY',
      'pincode': '10001',
      'country': 'USA',
      'address_type': 'home',
    });

    // 3. Create a dummy Order
    String orderId = 'order_2024_001';
    String paymentId = 'pay_987654';
    await _firestore.collection('orders').doc(orderId).set({
      'order_id': orderId,
      'user_id': userId,
      'order_date': FieldValue.serverTimestamp(),
      'order_status': 'pending', // pending, shipped, delivered, cancelled
      'total_amount': 299.99,
      'payment_id': paymentId,
      'shipping_address_id': addressId,
      'billing_address_id': addressId,
      'delivery_date': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // 4. Add Order Items
    await _firestore.collection('orders').doc(orderId).collection('items').add({
      'order_item_id': 'item_1',
      'order_id': orderId,
      'product_id': 'prod_001',
      'product_name': 'Premium Wireless Headphones',
      'quantity': 1,
      'price_per_unit': 299.99,
      'total_price': 299.99,
    });

    // 5. Create a Payment Record (Flat collection for easy access)
    await _firestore.collection('payments').doc(paymentId).set({
      'payment_id': paymentId,
      'order_id': orderId,
      'user_id': userId, // Added for filtering/security
      'payment_method': 'Card', // UPI, Card, COD
      'payment_status': 'success', // success, failed, pending
      'transaction_id': 'trans_abc123',
      'payment_date': FieldValue.serverTimestamp(),
    });

    // 6. Create Tracking Info
    String trackingId = 'track_554433';
    await _firestore.collection('tracking').doc(trackingId).set({
      'tracking_id': trackingId,
      'order_id': orderId,
      'delivery_partner': 'FedEx',
      'tracking_status': 'In Transit',
      'current_location': 'Distribution Center, NJ',
      'estimated_delivery': '2024-04-25',
    });
    
    // 7. Ensure Admin User Exists (to test rules)
    await _firestore.collection('users').doc('admin_user').set({
      'user_id': 'admin_user',
      'name': 'System Admin',
      'email': 'admin@yourstore.com',
      'role': 'admin',
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
