import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class ReceptionistMedicinesPage extends StatefulWidget {
  const ReceptionistMedicinesPage({Key? key}) : super(key: key);

  @override
  _ReceptionistMedicinesPageState createState() =>
      _ReceptionistMedicinesPageState();
}

class _ReceptionistMedicinesPageState extends State<ReceptionistMedicinesPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController(); // New controller for description
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  // ignore: unused_field
  String? _currentMedicineId;

  //Dialog for adding/editing medicines.
  void _showMedicineDialog(DocumentSnapshot? medicine) {
    // Initialize form with existing data if editing
    if (medicine != null) {
      final data = medicine.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _quantityController.text = data['quantity']?.toString() ?? '';
      _priceController.text = data['price']?.toStringAsFixed(2) ?? '';
      _currentMedicineId = medicine.id;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medicine == null ? 'Add Medicine' : 'Edit Medicine'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Medicine name field
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Medicine Name*'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                // Medicine description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  // Description is optional, so no validator is needed
                ),
                // Quantity input field
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity*'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                // Price input field
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price*'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Save/Add button
          ElevatedButton(
            onPressed: () => _handleSubmit(medicine != null),
            child: Text(medicine == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  // Clear form
  void _clearForm() {
    _currentMedicineId = null;
    _nameController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _priceController.clear();
  }

  // Form submission for both add and update
  // If isUpdate is true, updates an existing medicine; otherwise, adds a new one.
  void _handleSubmit(bool isUpdate) async {
    if (_formKey.currentState!.validate()) {
      try {
        // Prepare medicine data for Firestore
        final medicineData = {
          'name': _nameController.text,
          'quantity': int.parse(_quantityController.text),
          'price': double.parse(_priceController.text),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // Add description if description field not empty
        if (_descriptionController.text.isNotEmpty) {
          medicineData['description'] = _descriptionController.text;
        }

        // Update medicine or add new medicine based on isUpdate flag.
        if (isUpdate && _currentMedicineId != null) {
          await _firestoreService.updateMedicine(_currentMedicineId!, medicineData);
        } else {
          await _firestoreService.addMedicine(medicineData);
        }

        // Close dialog and clear form
        Navigator.pop(context);
        _clearForm();
      } catch (e) {
        // Error message if operation fail
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Delete confirmaton
  void _confirmDelete(String medicineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: const Text('Are you sure you want to delete this medicine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestoreService.deleteMedicine(medicineId);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Error deleting medicine: ${e.toString()}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines Management'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Search bar for medicines
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // List of medicines from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getMedicines(),
              builder: (context, snapshot) {
                // Handle error state
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                // Loading indicator while waiting for data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Filter medicines based on search query
                final searchQuery = _searchController.text.toLowerCase();
                final medicines = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['name']
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery);
                }).toList();

                // Build list items for each medicine
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final medicine = medicines[index];
                    final data = medicine.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          data['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description text (if available)
                            Text(data['description'] ??
                                'No description available'),
                            Text('Quantity: ${data['quantity']}'),
                            Text(
                                'Price: \$${data['price']?.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(medicine.id),
                        ),
                        // Tapping opens the add/edit dialog for this medicine
                        onTap: () => _showMedicineDialog(medicine),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Button to add a new medicine
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMedicineDialog(null),
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue[700],
      ),
    );
  }
}
