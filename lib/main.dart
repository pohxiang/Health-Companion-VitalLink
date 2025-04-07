import 'package:flutter/material.dart';
import 'package:vitallinkv2/screens/intropage.dart';
// import 'package:vitallinkv2/screens/addotherroles.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'dart:async';

// Add this timer as a global variable
Timer? _queueCheckTimer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the Firestore queue collection
  await FirestoreService().initializeQueueCollection();

  // Start periodic queue checks (every 5 minutes)
  _startQueueMonitoring();

  runApp(const MaterialApp(
      //run intropage
      home: Intropage()));
}

void _startQueueMonitoring() {
  // Cancel any existing timer
  _queueCheckTimer?.cancel();

  // Create a new timer that runs every 5 minutes
  _queueCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    print('Running periodic queue check...');
    await _checkAllDoctorQueues();
  });

  // Run an immediate check on startup
  _checkAllDoctorQueues().then((_) {
    print('Initial queue check completed.');
  }).catchError((error) {
    print('Error in initial queue check: $error');
  });
}

Future<void> _checkAllDoctorQueues() async {
  try {
    final FirestoreService firestoreService = FirestoreService();

    // Get all doctors with active queues
    final activeDoctorsSnapshot = await firestoreService.equeueCollection
        .where('status', isEqualTo: 'waiting')
        .get();

    print('Found ${activeDoctorsSnapshot.docs.length} active queue entries');

    // Extract unique doctor IDs from queue entries
    final Set<String> doctorIds = {};
    for (var doc in activeDoctorsSnapshot.docs) {
      var data = doc.data();
      String? doctorId = data['doctorId'];
      if (doctorId != null && doctorId != 'system') {
        doctorIds.add(doctorId);
        print('Added doctor ID to check: $doctorId');
      }
    }

    // Check queue threshold for each doctor
    for (String doctorId in doctorIds) {
      await firestoreService.checkQueueThreshold(doctorId);
    }

    print('Checked queues for ${doctorIds.length} doctors');
  } catch (e) {
    print('Error in periodic queue check: $e');
  }
}
