import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Processing':
        return Colors.orange;
      case 'Shipped':
        return Colors.blue;
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final currentUser = firestoreService.getCurrentUser();

    // Handle null user
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Status')),
        body: const Center(
          child: Text('Please log in to view order history'),
        ),
      );
    }

    final userId = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
      title: const Text('Order Status'),
      backgroundColor: Colors.blue[800], 
      foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blue[50], 
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.patientsCollection
            .doc(userId) // Direct patient document reference
            .collection('orders') // Access orders subcollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final order = snapshot.data!.docs[index];
              final data = order.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 8)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Chip(
                            label: Text(data['status']),
                            backgroundColor: _getStatusColor(data['status']),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: \$${data['total'].toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Medications:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...List<Widget>.from(
                        (data['items'] as List).map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.medical_services),
                            title: Text(item['name']),
                            trailing: Text(
                              '${item['quantity']} × \$${item['price']}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}