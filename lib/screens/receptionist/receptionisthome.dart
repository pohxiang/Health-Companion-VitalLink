import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:vitallinkv2/screens/addotherroles.dart';
import 'package:vitallinkv2/screens/receptionist/receptionistappointmentspage.dart';
import 'package:vitallinkv2/screens/receptionist/receptionistmedicines.dart';
import 'package:vitallinkv2/screens/receptionist/receptionistorder.dart';
import 'package:vitallinkv2/screens/receptionist/receptionistqueue.dart';
import 'package:vitallinkv2/screens/receptionist/receptionistchat.dart';
import 'package:vitallinkv2/screens/loginpage.dart';

class ReceptionistHomePage extends StatefulWidget {
  const ReceptionistHomePage({Key? key}) : super(key: key);

  @override
  State<ReceptionistHomePage> createState() => _ReceptionistHomePageState();
}

class _ReceptionistHomePageState extends State<ReceptionistHomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _receptionistData;
  bool _isLoading = true;
  // ignore: unused_field
  String? _receptionistId;

  @override
  void initState() {
    super.initState();
    _loadReceptionistData();
  }

  /// Loads receptionist data from Firestore
  Future<void> _loadReceptionistData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _firestoreService.getCurrentUser();
      if (user != null) {
        // Sanitize email to use as document ID
        String docId = user.email!.replaceAll(RegExp(r'[.#$[\]]'), '_');
        _receptionistId = docId;

        DocumentSnapshot docSnapshot =
            await _firestoreService.receptionistsCollection.doc(docId).get();

        if (docSnapshot.exists) {
          setState(() {
            _receptionistData = docSnapshot.data() as Map<String, dynamic>?;
          });
        }
      }
    } catch (e) {
      print('Error loading receptionist data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receptionistData == null
              ? const Center(child: Text('No receptionist data found'))
              : RefreshIndicator(
                  onRefresh: _loadReceptionistData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Space for safe area
                        const SizedBox(height: 40),
                        _buildProfileHeader(),
                        const SizedBox(height: 30),
                        _buildNavigationGrid(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Profile header with gradient background and avatar
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await _firestoreService.signOut();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ],
          ),
          Material(
            elevation: 5,
            shape: const CircleBorder(),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 60,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            '${_receptionistData?['firstName'] ?? 'Receptionist'} ${_receptionistData?['lastName'] ?? ''}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _receptionistData?['role'] ?? 'Front Desk',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Grid layout for navigation buttons
  Widget _buildNavigationGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.2,
        children: [
          _buildNavButton(
            icon: Icons.medical_services,
            label: 'Medicines',
            onTap: () => _navigateToPage(const ReceptionistMedicinesPage()),
          ),
          _buildNavButton(
            icon: Icons.calendar_today,
            label: 'Appointments',
            onTap: () => _navigateToPage(const ReceptionistAppointmentsPage()),
          ),
          _buildNavButton(
            icon: Icons.person_add,
            label: 'Add Staff',
            onTap: () => _navigateToPage(const AddOtherRoles()),
          ),
          _buildNavButton(
            icon: Icons.message,
            label: 'Messaging',
            onTap: () => _navigateToPage(const ReceptionistChatPage()),
          ),
          _buildNavButton(
            icon: Icons.shopping_cart,
            label: 'Orders',
            onTap: () => _navigateToPage(const ReceptionistOrderPage()),
          ),
          _buildNavButton(
            icon: Icons.queue,
            label: 'eQueue',
            onTap: () => _navigateToPage(const ReceptionistEQueuePage()),
          ),
        ],
      ),
    );
  }

  /// Individual navigation button component
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.blue[700]),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles navigation to different pages
  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
