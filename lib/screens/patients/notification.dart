import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = firestoreService.getCurrentUser();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue[800], 
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blue[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildNotificationList(user.uid),
      ),
    );
  }

  Widget _buildNotificationList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getPatientAppointments(userId),
      builder: (context, appointmentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().patientsCollection
              .doc(userId)
              .collection('orders')
              .snapshots(),
          builder: (context, orderSnapshot) {
            final appointments = _processAppointments(appointmentSnapshot);
            final orders = _processOrders(orderSnapshot);
            final allNotifications = [...appointments, ...orders]..sort((a, b) => 
                b['timestamp'].compareTo(a['timestamp']));

            if (allNotifications.isEmpty) {
              return const Center(
                child: Text('No notifications yet'),
              );
            }

            return ListView.builder(
              itemCount: allNotifications.length,
              itemBuilder: (context, index) {
                final notification = allNotifications[index];
                return _buildNotificationItem(notification);
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _processAppointments(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData) return [];
    
    return snapshot.data!.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'type': 'appointment',
        'title': 'Appointment ${data['status']}',
        'assignedDoctor': data['assignedDoctor'],
        'timestamp': data['startTime'] as Timestamp,
        'status': data['status'],
        'date': DateFormat('MMM dd, yyyy - hh:mm a')
            .format((data['startTime'] as Timestamp).toDate()),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _processOrders(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (!snapshot.hasData) return [];
    
    return snapshot.data!.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'type': 'order',
        'title': 'Order ${data['status']}',
        'details': '${data['items']?.length ?? 0} items - \$${data['total']?.toStringAsFixed(2)}',
        'timestamp': data['createdAt'] as Timestamp,
        'status': data['status'],
        'date': DateFormat('MMM dd, yyyy - hh:mm a')
            .format((data['createdAt'] as Timestamp).toDate()),
      };
    }).toList();
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    IconData icon;
    Color color;

    switch (notification['type']) {
      case 'appointment':
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case 'order':
        icon = Icons.local_pharmacy;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(notification['title']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification['type'] == 'appointment')
              FutureBuilder<DocumentSnapshot>(
                future: FirestoreService().getDoctor(notification['assignedDoctor']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text('Loading doctor name...');
                  }
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return Text('Dr. Unknown');
                  }
                  final doctorData = snapshot.data!.data() as Map<String, dynamic>;
                  final lastName = doctorData['lastName'] ?? 'Unknown Doctor';
                  return Text('Dr. $lastName');
                },
              )
            else
              Text(notification['details']),
            const SizedBox(height: 4),
            Text(
              notification['date'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: _buildStatusIndicator(notification['status']), // Add status indicator here
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'delivered':
        color = Colors.green;
        break;
      case 'processing':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}