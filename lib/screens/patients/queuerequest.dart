import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/screens/patients/patienthome.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'dart:async';


final GlobalKey<ScaffoldMessengerState> _scaffoldKey = 
  GlobalKey<ScaffoldMessengerState>();


class QueueSystem extends StatelessWidget {
  const QueueSystem({super.key});


  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hospital Queue System'),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
        ),
        body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SpecialistSelectionQueueScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: const Text('Join New Queue', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QueueStatusScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: const Text('View My Queue', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
      )
        );
  
    }
  }

class SpecialistSelectionQueueScreen extends StatefulWidget {
  const SpecialistSelectionQueueScreen({super.key});

  @override
  State<SpecialistSelectionQueueScreen> createState() => _SpecialistSelectionQueueScreenState();
}

class _SpecialistSelectionQueueScreenState extends State<SpecialistSelectionQueueScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<String> _specialties = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSpecialties();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() => _searchQuery = _searchController.text.toLowerCase());

  Future<void> _fetchSpecialties() async {
    final snapshot = await _firestoreService.doctorsCollection.get();
    final specialties = snapshot.docs
        .map((doc) => doc['department'] as String)
        .toSet()
        .toList();
    setState(() => _specialties = specialties);
  }

  List<String> get _filteredSpecialties => _specialties
      .where((spec) => spec.toLowerCase().contains(_searchQuery))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Specialist'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search specialists...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredSpecialties.length,
              itemBuilder: (context, index) {
                final specialty = _filteredSpecialties[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text(specialty),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorSelectionScreen(specialty: specialty),
                    ),
                  ),
                  )
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class DoctorSelectionScreen extends StatefulWidget {
  final String specialty;
  const DoctorSelectionScreen({super.key, required this.specialty});

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() => _searchQuery = _searchController.text.toLowerCase());

  List<QueryDocumentSnapshot> _filterDoctors(List<QueryDocumentSnapshot> doctors) {
    return doctors.where((doc) {
      final firstName = doc['firstName']?.toString().toLowerCase() ?? '';
      final lastName = doc['lastName']?.toString().toLowerCase() ?? '';
      return '$firstName $lastName'.contains(_searchQuery);
    }).toList();
  }

  Future<void> _joinQueue(BuildContext context, DocumentSnapshot doctor) async {
    final user = _firestoreService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join queue')),
      );
      return;
    }

    try {
      // Fetch patient details
      final patientDoc = await _firestoreService.getPatient(user.uid);
      final patientName = '${patientDoc['firstName']} ${patientDoc['lastName']}';
      final doctorName = 'Dr. ${doctor['firstName']} ${doctor['lastName']}';

      await _firestoreService.addPatientToQueue(
        patientId: user.uid,
        patientName: patientName,
        doctorId: doctor.id,
        doctorName: doctorName,
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QueueStatusScreen()),
      );
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
        title: Text('Available ${widget.specialty} Doctors'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.doctorsCollection
                  .where('department', isEqualTo: widget.specialty)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final doctors = _filterDoctors(snapshot.data!.docs);
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                        title: Text('Dr. ${doctor['firstName']} ${doctor['lastName']}'),
                        subtitle: Text(doctor['department']),
                        trailing: IconButton(
                          icon: const Icon(Icons.queue, color: Colors.blue),
                          onPressed: () => _joinQueue(context, doctor),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class QueueStatusScreen extends StatefulWidget {
  const QueueStatusScreen({super.key});

  @override
  State<QueueStatusScreen> createState() => _QueueStatusScreenState();
}

class _QueueStatusScreenState extends State<QueueStatusScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Timer _timer;
  User? user;

  @override
  void initState() {
    super.initState();
    user = _firestoreService.getCurrentUser();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
    });
      setState(() {});
    }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
    onWillPop: () async {
      // Navigate to home page and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => PatientDashboard()),
        (route) => false,
      );
      return false; // Prevent default back behavior
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Queue Status'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please login to view queue status'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.equeueCollection
                  .where('patientId', isEqualTo: user!.uid)
                  .where('status', whereIn: ['waiting', 'serving'])
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final queues = snapshot.data?.docs ?? [];
                return queues.isEmpty 
                    ? _buildEmptyState(context)
                    : _buildQueueList(queues);
              },
            ),
    )
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_play_next, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'No Active Queues',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Join a queue to see your status here',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SpecialistSelectionQueueScreen()),
              ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Join Queue', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<QueryDocumentSnapshot<Map<String, dynamic>>> queues) {
    return Container(
      child: Column( 
        children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Active Queues',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: queues.length,
            itemBuilder: (context, index) {
              final queueSnapshot = queues[index];
              return _buildQueueCard(
                context: context,
                queue: queueSnapshot, // Pass the full DocumentSnapshot
                queueId: queueSnapshot.id, // Document ID from Firestore
                index: index,
              );
            },
          )
          )
      ]
    )
    );
        }

  Widget _buildQueueCard({
    required BuildContext context,
    required DocumentSnapshot queue,
    required String queueId,
    required int index,
  }) {
    final queueData = queue.data() as Map<String, dynamic>;
    final truncatedQueueId = queueId.substring(0, 6);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Name
          FutureBuilder<DocumentSnapshot>(
            future: _firestoreService.doctorsCollection.doc(queueData['doctorId']).get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final doctor = snapshot.data!.data() as Map<String, dynamic>;
                return Text(
                  'Dr. ${doctor['firstName']} ${doctor['lastName']}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          const SizedBox(height: 20),

          // Queue Information
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<int>(
                    future: _firestoreService.getPatientQueuePosition(
                      patientId: queueData['patientId'],
                      doctorId: queueData['doctorId'],
                    ),
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? 0;
                      return _buildStatusItem(
                        label: 'Current Position',
                        value: position > 0 ? '$position' : 'Pending',
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStatusItem(
                    label: 'Queue ID',
                    value: truncatedQueueId,
                  ),
                ],
              ),
              FutureBuilder<int>(
                future: _firestoreService.getPatientQueuePosition(
                  patientId: queueData['patientId'],
                  doctorId: queueData['doctorId'],
                ),
                builder: (context, snapshot) {
                  final position = snapshot.data ?? 0;
                  int estimatedWait = (position > 0) ? (position - 1) * 15 : 0;
                  Timestamp? checkInTimestamp = queueData['checkInTime'] as Timestamp?;
                  if (checkInTimestamp != null) {
                    DateTime checkInTime = checkInTimestamp.toDate();
                    DateTime now = DateTime.now();
                    int elapsedMinutes = now.difference(checkInTime).inMinutes;
                    estimatedWait = (estimatedWait - elapsedMinutes).clamp(0, estimatedWait);
                  }
                  return Column(
                    children: [
                      Text(
                        'Estimated Wait',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$estimatedWait mins',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 25),

          // Cancel Button - Now placed below the Row
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _cancelQueue(context, queueId: queue.id),
              child: const Text(
                'Cancel Queue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  // Cancel Queue Handler
  Future<void> _cancelQueue(BuildContext context, {required String queueId}) async {
    try {
      await _firestoreService.removePatientFromQueue(queueId);
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Queue cancelled successfully!')),
      );
    } catch (e) {
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to cancel queue: $e')),
      );
    }
  }
}