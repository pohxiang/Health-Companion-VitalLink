import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class ReceptionistOrderPage extends StatefulWidget {
  const ReceptionistOrderPage({Key? key}) : super(key: key);

  @override
  State<ReceptionistOrderPage> createState() => _ReceptionistOrderPageState();
}

class _ReceptionistOrderPageState extends State<ReceptionistOrderPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPatientId;
  String _selectedPatientName = '';
  final List<String> _statusOptions = [
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.blue[700],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildSearchBar(),
            _buildPatientInfo(),
            Expanded(
              child: _selectedPatientId != null
                  ? _buildOrdersList()
                  : const Center(
                child: Text('Select a patient to view orders'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by patient name...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedPatientId = null;
                _selectedPatientName = '';
              });
            },
          ),
        ),
        onChanged: (value) => _searchPatients(value),
      ),
    );
  }

  //Selected patient information and order
  Widget _buildPatientInfo() {
    if (_selectedPatientId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: ListTile(
          title: Text(_selectedPatientName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getOrdersByPatient(_selectedPatientId!),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Text('$count order${count == 1 ? '' : 's'} found');
            },
          ),
        ),
      ),
    );
  }

  // Build the list from Firestore data
  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getOrdersByPatient(_selectedPatientId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            return _buildOrderItem(orders[index].id, order);
          },
        );
      },
    );
  }

  // Creates an individual order list item with status display
  // Show total amount, item count, and status
  Widget _buildOrderItem(String orderId, Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text('\$${order['total'].toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order['items'].length} item(s)'),
            const SizedBox(height: 4),
            Chip(
              label: Text(order['status']),
              backgroundColor: _getStatusColor(order['status']),
            ),
          ],
        ),
        trailing: const Icon(Icons.edit),
        onTap: () => _showStatusDialog(orderId, order),
      ),
    );
  }

  // Dialog for updating order status
  void _showStatusDialog(String orderId, Map<String, dynamic> order) {
    String selectedStatus = order['status'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: DropdownButtonFormField<String>(
          value: selectedStatus,
          items: _statusOptions
              .map((status) => DropdownMenuItem(
            value: status,
            child: Text(status),
          ))
              .toList(),
          onChanged: (value) => selectedStatus = value!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestoreService.updateOrderStatus(
                  patientDocId: _selectedPatientId!,
                  orderId: orderId,
                  newStatus: selectedStatus,
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: ${e.toString()}')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Return colour based on order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Processing':
        return Colors.orange[300]!;
      case 'Shipped':
        return Colors.blue[300]!;
      case 'Delivered':
        return Colors.green[300]!;
      case 'Cancelled':
        return Colors.red[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  // Search patients by name using Firestore query, create a selectable list of patients
  // This is for viewing orders
  void _searchPatients(String query) async {
    if (query.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('patients')
        .get();

    final filteredPatients = snapshot.docs.where((doc) {
      final patient = doc.data();
      final fullName = '${patient['firstName']} ${patient['lastName']}'.toLowerCase();
      return fullName.contains(query.toLowerCase());
    }).toList();

    if (filteredPatients.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Patient'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredPatients.length,
              itemBuilder: (context, index) {
                final patient = filteredPatients[index];
                return ListTile(
                  title: Text(
                    '${patient['firstName']} ${patient['lastName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedPatientId = patient.id;
                      _selectedPatientName = '${patient['firstName']} ${patient['lastName']}';
                      _searchController.text = _selectedPatientName;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      );
    }
  }
}