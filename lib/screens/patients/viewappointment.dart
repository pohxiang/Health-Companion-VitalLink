import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class AllAppointmentsScreen extends StatelessWidget {
  const AllAppointmentsScreen({super.key});

  void _showCancelConfirmation(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // Use dialogContext here
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first
              await _cancelAppointment(context, appointmentId); // Use original context
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  Future<void> _cancelAppointment(BuildContext context, String appointmentId) async {
    final firestoreService = FirestoreService();
    try {
      await firestoreService.cancelAppointment(appointmentId);
      if (context.mounted) { // Check if widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling appointment: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = firestoreService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Appointments'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blue[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getPatientAppointments(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final startTimestamp = data['startTime'] as Timestamp?;
            final status = data['status'] as String?;
            if (startTimestamp == null || status == null) return false;
            final startTime = startTimestamp.toDate();
            return startTime.isAfter(DateTime.now()) &&
                (status == 'waiting' || status == 'requested');
          }).toList();

          if (appointments.isEmpty) {
            return const Center(child: Text('No upcoming appointments.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              final data = appointment.data() as Map<String, dynamic>;
              final startTime = (data['startTime'] as Timestamp).toDate();
              final endTime = (data['endTime'] as Timestamp?)?.toDate() ??
                  startTime.add(const Duration(hours: 1));
              final status = data['status'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text(DateFormat('dd MMMM, y').format(startTime)),
                  subtitle: Text('${DateFormat('hh:mm a').format(startTime)} - '
                      '${DateFormat('hh:mm a').format(endTime)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(
                          status,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor:
                            status == 'waiting' ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      if (status == 'waiting' || status == 'requested')
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () =>
                              _showCancelConfirmation(context, appointment.id),
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
