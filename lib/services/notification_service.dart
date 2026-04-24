import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initializeFCM() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Admin granted notification permission');
        
        String? token = await _fcm.getToken(
          vapidKey: dotenv.env['FCM_VAPID_PUBLIC_KEY'],
        );
        
        if (token != null) {
          debugPrint('Admin FCM Token: $token');
          // Save admin token to a special doc
          await _firestore.collection('admin_config').doc('push_notifications').set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Admin received foreground message: ${message.notification?.title}');
        });
      }
    } catch (e) {
      debugPrint('Error initializing Admin FCM: $e');
    }
  }

  Stream<List<NotificationItem>> getAdminNotifications() {
    return _firestore
        .collection('notifications')
        // .where('userId', isEqualTo: 'admin')
        // .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationItem.fromFirestore(doc))
            .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final batch = _firestore.batch();
    final querySnapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> clearAll() async {
    final batch = _firestore.batch();
    final querySnapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: 'admin')
        .get();

    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Notify all users about a new product or general update
  static Future<void> notifyAllUsers({
    required String title,
    required String message,
    String type = 'product',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('NotificationService: Notifying all users: $title');
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      debugPrint('NotificationService: Found ${usersSnapshot.docs.length} users');
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in usersSnapshot.docs) {
        final ref = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(ref, {
          'userId': doc.id,
          'title': title,
          'message': message,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': metadata,
        });
      }
      await batch.commit();
      debugPrint('NotificationService: All user notifications sent successfully');
    } catch (e) {
      debugPrint('NotificationService: Error notifying all users: $e');
    }
  }

  /// Notify a specific user (targeted notifications like "Handpicked")
  static Future<void> notifyUser({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('NotificationService: Sending targeted notification to $userId: $title');
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
      debugPrint('NotificationService: Targeted notification sent successfully');
    } catch (e) {
      debugPrint('NotificationService: Error sending targeted notification: $e');
    }
  }
}
