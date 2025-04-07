import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:vitallinkv2/screens/doctor/doctorappointmentspage.dart';
import 'package:vitallinkv2/screens/doctor/patientspage.dart';
import 'package:vitallinkv2/screens/doctor/messaging.dart';
import 'package:vitallinkv2/screens/doctor/doctorqueue.dart';

class DoctorNotificationsPage extends StatefulWidget {
  const DoctorNotificationsPage({Key? key}) : super(key: key);

  @override
  State<DoctorNotificationsPage> createState() =>
      _DoctorNotificationsPageState();
}

class _DoctorNotificationsPageState extends State<DoctorNotificationsPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  String? _doctorId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getCurrentDoctor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentDoctor() async {
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      setState(() {
        _doctorId = user.uid;
      });
      await _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (_doctorId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get notifications from Firestore
      final notificationsSnapshot = await _firestoreService.firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: _doctorId)
          .orderBy('timestamp', descending: true)
          .get();

      // Transform to a more usable format
      final notifications = notificationsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Notification',
          'message': data['message'] ?? '',
          'type': data['type'] ?? 'general',
          'read': data['read'] ?? false,
          'timestamp': data['timestamp'] as Timestamp,
          'priority': data['priority'] ?? 'normal',
          'actionable': data['actionable'] ?? false,
          'actionId': data['actionId'],
          'actionType': data['actionType'],
        };
      }).toList();

      // Count unread notifications
      int unreadCount = notifications
          .where((notification) => !(notification['read'] as bool))
          .length;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestoreService.firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        final index = _notifications
            .indexWhere((notification) => notification['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['read'] = true;
          _unreadCount = _notifications
              .where((notification) => !(notification['read'] as bool))
              .length;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty) return;

    try {
      // Get all unread notification IDs
      final unreadIds = _notifications
          .where((notification) => !(notification['read'] as bool))
          .map((notification) => notification['id'] as String)
          .toList();

      // Create a batch to update multiple documents
      final batch = _firestoreService.firestore.batch();

      // Add each update to the batch
      for (final id in unreadIds) {
        final docRef =
            _firestoreService.firestore.collection('notifications').doc(id);
        batch.update(docRef, {'read': true});
      }

      // Commit the batch
      await batch.commit();

      // Update local state
      setState(() {
        for (var notification in _notifications) {
          notification['read'] = true;
        }
        _unreadCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      print('Error marking all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestoreService.firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();

      setState(() {
        final index = _notifications
            .indexWhere((notification) => notification['id'] == notificationId);
        if (index != -1) {
          final wasUnread = !(_notifications[index]['read'] as bool);
          _notifications.removeAt(index);
          if (wasUnread) {
            _unreadCount--;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _handleNotificationAction(Map<String, dynamic> notification) async {
    // Mark as read first
    await _markAsRead(notification['id']);

    // Handle different action types
    switch (notification['actionType']) {
      case 'appointment':
        // Navigate to appointment details
        if (notification['actionId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentDetailPage(
                appointmentId: notification['actionId'],
              ),
            ),
          );
        }
        break;

      case 'patient':
        // Navigate to patient profile
        if (notification['actionId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailPage(
                patientID: notification['actionId'],
              ),
            ),
          );
        }
        break;

      case 'queue':
        // Navigate to queue management
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DoctorQueuePage()),
        );
        break;

      case 'message':
        // Navigate to messaging with preselected conversation
        if (notification['actionId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessagingPage(
                initialConversationId: notification['actionId'],
              ),
            ),
          );
        } else {
          // Just open the messaging page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MessagingPage()),
          );
        }
        break;

      default:
        // No specific action needed for general notifications
        break;
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    switch (_tabController.index) {
      case 0: // All notifications
        return _notifications;
      case 1: // Unread notifications
        return _notifications
            .where((notification) => !(notification['read'] as bool))
            .toList();
      case 2: // Important notifications
        return _notifications
            .where((notification) => notification['priority'] == 'high')
            .toList();
      default:
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue[700],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'All'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unread'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadCount.toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Important'),
          ],
          onTap: (index) {
            setState(() {});
          },
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsList(),
                _buildNotificationsList(),
                _buildNotificationsList(),
              ],
            ),
    );
  }

  Widget _buildNotificationsList() {
    final filteredNotifications = _getFilteredNotifications();

    if (filteredNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesome.bell_slash_o,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 1
                  ? 'No unread notifications'
                  : _tabController.index == 2
                      ? 'No important notifications'
                      : 'No notifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = filteredNotifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['read'] as bool;
    final String type = notification['type'] as String;
    final String priority = notification['priority'] as String;
    final bool isActionable = notification['actionable'] as bool;
    final Timestamp timestamp = notification['timestamp'] as Timestamp;

    // Determine icon and color based on notification type
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'appointment':
        icon = FontAwesome.calendar_plus_o;
        iconColor = Colors.blue;
        break;
      case 'patient':
        icon = FontAwesome.user_md;
        iconColor = Colors.green;
        break;
      case 'message':
        icon = FontAwesome.envelope_o;
        iconColor = Colors.purple;
        break;
      case 'alert':
        icon = FontAwesome.exclamation_triangle;
        iconColor = Colors.orange;
        break;
      default:
        icon = FontAwesome.bell_o;
        iconColor = Colors.blue[700]!;
    }

    // Adjust color for priority
    if (priority == 'high') {
      iconColor = Colors.red;
    }

    return Dismissible(
      key: Key(notification['id']),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteNotification(notification['id']);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead ? Colors.transparent : Colors.blue[300]!,
            width: isRead ? 0 : 1,
          ),
        ),
        elevation: isRead ? 1 : 2,
        child: InkWell(
          onTap: () {
            if (!isRead) {
              _markAsRead(notification['id']);
            }

            if (isActionable) {
              _handleNotificationAction(notification);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isRead
                  ? iconColor.withOpacity(0.1)
                  : iconColor.withOpacity(0.2),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            title: Text(
              notification['title'],
              style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notification['message'],
                  style: TextStyle(
                      color: isRead ? Colors.grey[600] : Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(timestamp.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isRead)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: priority == 'high' ? Colors.red : Colors.blue,
                    ),
                  ),
                if (isActionable) ...[
                  const SizedBox(height: 8),
                  Icon(
                    FontAwesome.chevron_right,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
