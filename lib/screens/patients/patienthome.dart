import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import "package:flutter/material.dart";
import 'package:vitallinkv2/screens/loginpage.dart';
import 'package:vitallinkv2/screens/patients/medicalrecord.dart';
import 'package:vitallinkv2/screens/patients/patientappointment.dart';
import 'package:vitallinkv2/screens/patients/prescriptionrefill.dart';
import 'package:vitallinkv2/screens/patients/queuerequest.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/screens/patients/viewappointment.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:vitallinkv2/screens/patients/notification.dart';
import 'package:vitallinkv2/screens/patients/patientchat.dart';

class PatientDashboard extends StatelessWidget {
  PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitallink'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationPage()),
              );
            },
          )
        ],
      ),
      backgroundColor: Colors.blue[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildWelcomeHeader(context),
            const SizedBox(height: 20),
            _buildUpcomingAppointment(context),
            const SizedBox(height: 30),
            _buildDashboardGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = firestoreService.getCurrentUser();

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.patientsCollection
          .where('uid', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Welcome back,',
              style: TextStyle(fontSize: 18, color: Colors.grey));
        }

        final patientData = 
            snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final firstName = patientData['firstName'] ?? '';
        final lastName = patientData['lastName'] ?? '';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('$firstName $lastName',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.blue),
              onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()), // Replace with your actual login widget
                (route) => false,
              );
            }
            ),
          ]
                );
              },
            );
      }
  

  final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.blue,
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _buildUpcomingAppointment(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = firestoreService.getCurrentUser();

    // Early return for null user
    if (user == null || user.uid.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
        decoration: _cardDecoration,
        child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AllAppointmentsScreen()),
        );
      },
        child: Card(
          elevation: 0, // Remove default card shadow
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              // Use the CORRECT appointments collection
              stream: firestoreService.getPatientAppointments(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Handle empty data first
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoAppointmentsUI();
                }

                final appointments = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Null-safe timestamp handling
                  final startTimestamp = data['startTime'] as Timestamp?;
                  final status = data['status'] as String?;

                  if (startTimestamp == null || status == null) return false;

                  final startTime = startTimestamp.toDate();
                  return startTime.isAfter(DateTime.now()) &&
                      (status == 'waiting');
                }).toList();

                if (appointments.isEmpty) {
                  return _buildNoAppointmentsUI();
                }

                // Find nearest appointment with null checks
                // Find nearest appointment with explicit data casting
                appointments.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['startTime'] as Timestamp).toDate();
                  final bTime = (bData['startTime'] as Timestamp).toDate();
                  return aTime.compareTo(bTime);
                });

                final nearestAppointment = appointments.first;

                final startTime =
                    (nearestAppointment['startTime'] as Timestamp).toDate();
                final endTime =
                    (nearestAppointment['endTime'] as Timestamp?)?.toDate() ??
                        startTime.add(const Duration(hours: 1));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Appointment',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMMM, y').format(startTime)),
                            Text(
                              '${DateFormat('hh:mm a').format(startTime)} - '
                              '${DateFormat('hh:mm a').format(endTime)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        )
        )
    );
  }

  Widget _buildNoAppointmentsUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Appointment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'No upcoming appointments',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    final items = [
      {
        'icon': Icons.add,
        'title': 'Book Appointment',
        'route': const SpecialistSelectionScreen()
      },
      {
        'icon': Icons.medical_services,
        'title': 'View Medical Records',
        'route': const MedicalRecordsScreen()
      },
      {
        'icon': Icons.people,
        'title': 'My Queue Status',
        'route': QueueStatusScreen()
      },
      {
        'icon': Icons.medication,
        'title': 'Prescription Refills',
        'route': const PrescriptionRefillsScreen(),
      },
      {
        'icon': Icons.message,
        'title': 'Messages & Support',
        'route': const PatientChatPage(),
      }
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: items.map((item) {
        return Container(
            decoration: _cardDecoration,
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (item['route'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            item['route'] as Widget, // Capitalize Widget
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('${item['title']} feature coming soon!')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['icon'] as IconData,
                          size: 32, color: Colors.blue),
                      const SizedBox(height: 10),
                      Text(
                        item['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ));
      }).toList(),
    );
  }
}
