import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:intl/intl.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  DateTime? _selectedDate;
  final FirestoreService firestoreService = FirestoreService();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = firestoreService.getCurrentUser();

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medical Records')),
        body: const Center(child: Text('Please log in to view medical records')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical History'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _selectDate(context),
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
            ),
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getMedicalRecords(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<QueryDocumentSnapshot> records = snapshot.data!.docs;

          // Apply date filter if selected
          if (_selectedDate != null) {
            records = records.where((record) {
              final recordDate = (record['date'] as Timestamp).toDate();
              return recordDate.year == _selectedDate!.year &&
                     recordDate.month == _selectedDate!.month &&
                     recordDate.day == _selectedDate!.day;
            }).toList();
          }

          if (records.isEmpty) {
            return Center(
              child: Text(
                _selectedDate == null 
                  ? 'No medical records found'
                  : 'No records found for ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final data = record.data() as Map<String, dynamic>;
              
              final date = (data['date'] as Timestamp).toDate();
              final formattedDate = DateFormat('MMM dd, yyyy').format(date);

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
                          Text(formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                          Chip(
                            label: Text(data['condition']?? 'No Diagnosis'),
                            backgroundColor: Colors.blue[50],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Diagnosis:', data['condition']),
                      _buildInfoRow('Prescription:', data['prescription']),
                      if (data['feedback']?.isNotEmpty ?? false)
                        _buildInfoRow('Doctor Feedback:', data['feedback']),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Color.fromARGB(255, 111, 102, 102))),
          ),
        ],
      ),
    );
  }
}