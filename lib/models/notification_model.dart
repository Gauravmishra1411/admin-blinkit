import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'order', 'product', 'offer'
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }
}
