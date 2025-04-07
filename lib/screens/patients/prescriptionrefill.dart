
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:vitallinkv2/screens/patients/orderstatus.dart';


class PrescriptionRefillsScreen extends StatefulWidget {
  const PrescriptionRefillsScreen({super.key});

  @override
  State<PrescriptionRefillsScreen> createState() => _PrescriptionRefillsScreenState();
}

class _PrescriptionRefillsScreenState extends State<PrescriptionRefillsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedMedicines = <String>{}; // Track selected medicines
  final Map<String, dynamic> _cartItems = {}; // Store selected medicine details

  void _toggleSelection(DocumentSnapshot medicine) {
    setState(() {
      final medicineId = medicine.id;
      if (_selectedMedicines.contains(medicineId)) {
        _selectedMedicines.remove(medicineId);
        _cartItems.remove(medicineId);
      } else {
        _selectedMedicines.add(medicineId);
        _cartItems[medicineId] = {
          'name': medicine['name'],
          'price': medicine['price'],
          'quantity': 1, // Default quantity
          'maxQuantity': medicine['quantity'],
        };
      }
    });
  }

  Widget _buildMedicineCard(DocumentSnapshot medicine, BuildContext context) {
    final data = medicine.data() as Map<String, dynamic>;
    final isSelected = _selectedMedicines.contains(medicine.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isSelected ? Colors.blue[200] : null,
      child: InkWell(
        onTap: () => _toggleSelection(medicine),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.medical_services, size: 40),
          title: Text(data['name'], 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['description']),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$${data['price'].toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green)),
                  Text('Available: ${data['quantity']}',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              if (isSelected) _buildQuantitySelector(medicine.id, data['quantity']),
            ],
          ),
          trailing: isSelected 
              ? const Icon(Icons.check_circle, color: Colors.blue)
              : null,
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(String medicineId, int maxQuantity) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () {
            setState(() {
              if (_cartItems[medicineId]['quantity'] > 1) {
                _cartItems[medicineId]['quantity']--;
              }
            });
          },
        ),
        Text(_cartItems[medicineId]['quantity'].toString()),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            setState(() {
              if (_cartItems[medicineId]['quantity'] < maxQuantity) {
                _cartItems[medicineId]['quantity']++;
              }
            });
          },
        ),
      ],
    );
  }

  void _checkout() {
    if (_selectedMedicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select medicines to checkout')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _cartItems.values.map((item) => ListTile(
            title: Text(item['name']),
            subtitle: Text('Quantity: ${item['quantity']}'),
            trailing: Text('\$${(item['price'] * item['quantity']).toStringAsFixed(2)}'),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _processOrder(),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _processOrder() async {
    Navigator.pop(context);
    try {
      final currentUser = _firestoreService.getCurrentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
        return;
      }
      final userId = currentUser.uid;

      WriteBatch batch = _firestoreService.firestore.batch();
      List<Map<String, dynamic>> orderItems = [];
      double total = 0.0;

      // Medicine stock check and batch updates
      for (var entry in _cartItems.entries) { // Fixed variable name
        final medicineRef = _firestoreService.medicinesCollection.doc(entry.key);
        final item = entry.value;

        final medicineDoc = await medicineRef.get();
        if (medicineDoc['quantity'] < item['quantity']) {
          throw Exception('Insufficient stock for ${item['name']}'); // Fixed string interpolation
        }

        batch.update(medicineRef, {
          'quantity': FieldValue.increment(-item['quantity'])
        });

        orderItems.add({
          'name': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
        });
        total += item['price'] * item['quantity'];
      }

      final patientDocRef = _firestoreService.patientsCollection.doc(userId);
      final orderRef = patientDocRef.collection('orders').doc();
      
      batch.set(orderRef, {
        'items': orderItems,
        'total': total,
        'status': 'Processing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order processed successfully!')),
      );
      
      setState(() {
        _selectedMedicines.clear();
        _cartItems.clear();
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Refills',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrderStatusScreen()),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Medicines...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.medicinesCollection
                  .where('name', isGreaterThanOrEqualTo: _searchQuery)
                  .where('name', isLessThan: '${_searchQuery}z')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final medicines = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicines[index];
                    return _buildMedicineCard(medicine, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _checkout,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[900], // Dark blue background
        foregroundColor: Colors.white,
       ), // White text
          child: Text('CHECKOUT (${_selectedMedicines.length})',
              style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}