import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/notification_model.dart';
import 'services/notification_service.dart';
import 'login_page.dart';

import 'views/overview_view.dart';
import 'views/orders_view.dart';
import 'views/products_view.dart';
import 'views/vendors_view.dart';
import 'views/users_view.dart';
import 'views/categories_view.dart';
import 'views/banners_view.dart';
import 'views/recently_added_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final NotificationService _notificationService = NotificationService();
  String _connectionStatus = 'Connecting...';
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _notificationService.initializeFCM();
    _notificationService.getAdminNotifications().listen((notifs) {
      debugPrint('Admin received ${notifs.length} notifications');
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _unreadCount = notifs.where((n) => !n.isRead).length;
          _connectionStatus = 'Connected';
        });
      }
    }, onError: (e) {
      debugPrint('Admin Notification Listener Error: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = 'Error: $e';
        });
      }
    });
  }


  final List<Widget> _views = [
    const OverviewView(),
    const OrdersView(),
    const ProductsView(),
    const VendorsView(),
    const UsersView(),
    const CategoriesView(),
    const BannersView(),
    const RecentlyAddedView(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: isMobile 
        ? AppBar(
            backgroundColor: const Color(0xFF111C43),
            title: const Text('Admin Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          )
        : null,
      drawer: isMobile ? Drawer(
        backgroundColor: const Color(0xFF111C43),
        child: _buildSidebarContent(),
      ) : null,
      body: Row(
        children: [
          // Left Sidebar (Only visible on Desktop)
          if (!isMobile)
            Container(
              width: 250,
              color: const Color(0xFF111C43),
              child: _buildSidebarContent(),
            ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header (Only visible on Desktop or when needed)
                if (!isMobile)
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        )
                      ]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getPageTitle(_selectedIndex),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111C43),
                          ),
                        ),
                        Row(
                          children: [
                            // Connection Status Indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              margin: const EdgeInsets.only(right: 15),
                              decoration: BoxDecoration(
                                color: _connectionStatus == 'Connected' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _connectionStatus == 'Connected' ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _connectionStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _connectionStatus == 'Connected' ? Colors.green.shade700 : Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_none, color: Color(0xFF111C43)),
                                  onPressed: _showNotificationsDropdown,
                                ),
                                if (_unreadCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(
                                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            const CircleAvatar(
                              backgroundColor: Color(0xFF4CA1AF),
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                // View Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 30.0),
                    child: _views[_selectedIndex],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showNotificationsDropdown() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(top: 80, right: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StreamBuilder<List<NotificationItem>>(
          stream: _notificationService.getAdminNotifications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final notifs = snapshot.data ?? [];
            final unreadCount = notifs.where((n) => !n.isRead).length;

            return Container(
              width: 400,
              height: 500,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111C43)),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () => _notificationService.markAllAsRead(),
                          child: const Text('Mark all read'),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: notifs.isEmpty
                        ? const Center(child: Text('No notifications'))
                        : ListView.builder(
                            itemCount: notifs.length,
                            itemBuilder: (context, index) {
                              final n = notifs[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: n.type == 'order' ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  child: Icon(
                                    n.type == 'order' ? Icons.shopping_basket : Icons.notification_important,
                                    size: 18,
                                    color: n.type == 'order' ? Colors.blue : Colors.orange,
                                  ),
                                ),
                                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                                subtitle: Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                                trailing: n.isRead ? null : const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
                                onTap: () => _notificationService.markAsRead(n.id),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Center(
                    child: TextButton(
                      onPressed: () => _notificationService.clearAll(),
                      child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }


  Widget _buildSidebarContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        // Brand Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'Admin Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Navigation Items
        _buildNavItem(Icons.analytics_outlined, 'Overview', 0),
        _buildNavItem(Icons.receipt_long_outlined, 'Orders', 1),
        _buildNavItem(Icons.inventory_2_outlined, 'Products', 2),
        _buildNavItem(Icons.storefront_outlined, 'Vendors', 3),
        _buildNavItem(Icons.people_outline, 'Customer Users', 4),
        _buildNavItem(Icons.category_outlined, 'Categories', 5),
        _buildNavItem(Icons.campaign_outlined, 'Handpicked Banners', 6),
        _buildNavItem(Icons.settings_outlined, 'Recently Added', 7),
        
        const Divider(color: Colors.white10, indent: 20, endIndent: 20),
        
        // Debug Button
        ListTile(
          leading: const Icon(Icons.bug_report, color: Colors.orangeAccent, size: 20),
          title: const Text('Test Notification', style: TextStyle(color: Colors.white70, fontSize: 14)),
          onTap: () async {
            try {
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': 'admin',
                'title': 'Test Admin Notice',
                'message': 'This is a test notification generated from the dashboard.',
                'type': 'general',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent! Check the bell icon.')),
                );
              }
            } catch (e) {
               if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
        ),
        
        const Spacer(),
        
        const Divider(color: Colors.white24, height: 1),
        _buildNavItem(Icons.logout, 'Logout', -1, isLogout: true),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index, {bool isLogout = false}) {
    bool isSelected = _selectedIndex == index;
    
    return InkWell(
      onTap: () async {
        if (isLogout) {
           await FirebaseAuth.instance.signOut();
           final prefs = await SharedPreferences.getInstance();
           await prefs.setBool('isLoggedIn', false);
           if (context.mounted) {
             Navigator.pushReplacement(
               context,
               MaterialPageRoute(builder: (context) => const LoginPage()),
             );
           }
           return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        color: isSelected ? const Color(0xFF4CA1AF).withOpacity(0.2) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4CA1AF) : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getPageTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard Overview';
      case 1: return 'Live Orders Management';
      case 2: return 'Inventory & Products';
      case 3: return 'Vendor Management';
      case 4: return 'Customer Users Directory';
      case 5: return 'Shop Categories';
      case 6: return 'Handpicked Banners';
      case 7: return 'Recently Added Products';
      default: return '';
    }
  }
}
