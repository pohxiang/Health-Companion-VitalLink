import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/screens/doctor/doctorappointmentspage.dart';
import 'package:vitallinkv2/screens/doctor/messaging.dart';
import 'package:vitallinkv2/screens/doctor/patientspage.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:vitallinkv2/screens/doctor/doctorqueue.dart';
import 'package:vitallinkv2/screens/doctor/doctordetailappointment.dart';
import 'package:vitallinkv2/screens/doctor/doctorcreateappointment.dart';
import 'package:vitallinkv2/screens/loginpage.dart';

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({Key? key}) : super(key: key);

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _doctorData;
  bool _isLoading = true;
  int _appointmentCount = 0;
  int _patientCount = 0;
  String? _doctorId;
  int _selectedIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _firestoreService.getCurrentUser();
      if (user != null) {
        // First try with user's UID
        var doctorDoc =
            await _firestoreService.doctorsCollection.doc(user.uid).get();

        // If not found, try with sanitized email
        if (!doctorDoc.exists) {
          String sanitizedEmail =
              user.email!.replaceAll(RegExp(r'[.#$[\]]'), '_');
          doctorDoc = await _firestoreService.doctorsCollection
              .doc(sanitizedEmail)
              .get();
        }

        if (doctorDoc.exists) {
          _doctorId = doctorDoc.id; // Use the actual document ID

          setState(() {
            _doctorData = doctorDoc.data() as Map<String, dynamic>?;
          });

          // Get count of appointments for this doctor
          QuerySnapshot appointmentsSnapshot = await _firestoreService
              .appointmentsCollection
              .where('assignedDoctor', isEqualTo: _doctorId)
              .get();

          // Count unique patients
          Set<String> uniquePatients = {};
          for (var doc in appointmentsSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String? patientId = data['patientID']?.toString();
            if (patientId != null) {
              uniquePatients.add(patientId);
            }
          }

          setState(() {
            _appointmentCount = appointmentsSnapshot.docs.length;
            _patientCount = uniquePatients.length;
          });
        }
      }
    } catch (e) {
      print('Error loading doctor data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar; we'll disable the top SafeArea to extend our header
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false, // Disable top safe area
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _doctorData == null
                ? const Center(child: Text('No doctor data found'))
                : RefreshIndicator(
                    onRefresh: _loadDoctorData,
                    child:
                        NotificationListener<OverscrollIndicatorNotification>(
                      onNotification:
                          (OverscrollIndicatorNotification overscroll) {
                        overscroll.disallowIndicator();
                        return true;
                      },
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Remove the extra spacing if needed
                            _buildProfileHeader(),
                            const SizedBox(height: 20),
                            _buildStatCards(),
                            const SizedBox(height: 20),
                            _buildSectionTitle(
                              'Today\'s Appointments',
                              icon: FontAwesome.calendar_check_o,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DoctorAppointmentsPage(),
                                  ),
                                );
                              },
                            ),
                            _buildUpcomingAppointments(),
                            const SizedBox(height: 20),
                            _buildSectionTitle(
                              'Recent Patients',
                              icon: FontAwesome.user_md,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DoctorPatientsPage(),
                                  ),
                                );
                              },
                            ),
                            _buildRecentPatients(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        child:
                            Icon(FontAwesome.users, color: Colors.purple[700]),
                      ),
                      title: const Text('Manage Patient Queue'),
                      subtitle: const Text('View waiting patients'),
                      trailing: Icon(FontAwesome.angle_right,
                          color: Colors.grey[400]),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DoctorQueuePage(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Icon(FontAwesome.calendar_plus_o,
                            color: Colors.blue[700]),
                      ),
                      title: const Text('New Appointment'),
                      subtitle: const Text('Schedule a consultation'),
                      trailing: Icon(FontAwesome.angle_right,
                          color: Colors.grey[400]),
                      onTap: () {
                        Navigator.pop(context); // Close the bottom sheet first
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const DoctorCreateAppointment(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: Icon(FontAwesome.user_plus,
                            color: Colors.green[700]),
                      ),
                      title: const Text('Add Patient'),
                      subtitle: const Text('Register new patient'),
                      trailing: Icon(FontAwesome.angle_right,
                          color: Colors.grey[400]),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add Patient')),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(FontAwesome.plus, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ---------------------------
  // Bottom Navigation Bar
  // ---------------------------
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blue[400],
          unselectedItemColor: Colors.grey[600],
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 8,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 0 ? FontAwesome.home : FontAwesome.home,
              ),
              label: 'Home',
              backgroundColor: Colors.black,
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 1
                    ? FontAwesome.calendar
                    : FontAwesome.calendar_o,
              ),
              label: 'Appointments',
              backgroundColor: Colors.black,
            ),
            const BottomNavigationBarItem(
              icon: Icon(null), // Empty space for FAB
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 3
                    ? FontAwesome.user_circle
                    : FontAwesome.user_circle_o,
              ),
              label: 'Patients',
              backgroundColor: Colors.black,
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 4
                    ? FontAwesome.comments
                    : FontAwesome.comments_o,
              ),
              label: 'Messages',
              backgroundColor: Colors.black,
            ),
          ],
          onTap: (index) {
            if (index == 2) return; // Skip the middle item (FAB)
            setState(() {
              _selectedIndex = index;
            });
            switch (index) {
              case 1:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DoctorAppointmentsPage(),
                  ),
                );
                break;
              case 3:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DoctorPatientsPage(),
                  ),
                );
                break;
              case 4:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MessagingPage(),
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }

  // ---------------------------
  // Profile Header (Custom)
  // ---------------------------
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Removed notification bell; only sign out remains on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(FontAwesome.sign_out, color: Colors.white),
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(
                FontAwesome.user_md,
                size: 50,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Dr. ${_doctorData?['firstName'] ?? ''} ${_doctorData?['lastName'] ?? ''}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Colors.black26,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FontAwesome.stethoscope,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  _doctorData?['department'] ?? 'General Practitioner',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Section Title
  // ---------------------------
  Widget _buildSectionTitle(String title,
      {required VoidCallback onPressed, IconData icon = FontAwesome.list}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(FontAwesome.angle_right, size: 16, color: Colors.blue),
            label: Text('See All',
                style: TextStyle(color: Colors.blue, fontSize: 14)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Stat Cards
  // ---------------------------
  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard('Patients', _patientCount.toString(),
                  FontAwesome.users, Colors.green),
              const SizedBox(width: 20),
              _buildStatCard('Appointments', _appointmentCount.toString(),
                  FontAwesome.calendar_check_o, Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          // Large button for queue management
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DoctorQueuePage()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[800]!, Colors.purple[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(FontAwesome.users, color: Colors.purple),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Queue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Manage waiting patients',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(FontAwesome.arrow_circle_right,
                      color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color.withOpacity(0.4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------
  // Today's Appointments
  // ---------------------------
  Widget _buildUpcomingAppointments() {
    // Create datetime range for today (from midnight to tomorrow midnight)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.appointmentsCollection
          .where('assignedDoctor', isEqualTo: _doctorId)
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('startTime')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading appointments: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                children: [
                  Icon(FontAwesome.calendar_o,
                      size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No appointments for today',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // For testing: Add a sample appointment for today
                      _addSampleAppointmentForToday();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    child: const Text('Add Test Appointment'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var appointment = doc.data() as Map<String, dynamic>;
            appointment['id'] = doc.id; // Add document ID to map

            return _buildAppointmentCard(appointment);
          },
        );
      },
    );
  }

  // For testing: add a sample appointment
  Future<void> _addSampleAppointmentForToday() async {
    try {
      if (_doctorId == null) return;

      final now = DateTime.now();
      final appointmentTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour + 1, // One hour from now
        0,
      );

      await _firestoreService.appointmentsCollection.add({
        'patientID': 'test_patient_id',
        'patientName': 'Test Patient',
        'assignedDoctor': _doctorId,
        'startTime': Timestamp.fromDate(appointmentTime),
        'endTime': Timestamp.fromDate(
          appointmentTime.add(const Duration(minutes: 30)),
        ),
        'reason': 'Annual checkup',
        'status': 'Confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test appointment added')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ---------------------------
  // Recent Patients
  // ---------------------------
  Widget _buildRecentPatients() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestoreService.appointmentsCollection
          .where('assignedDoctor', isEqualTo: _doctorId)
          .orderBy('startTime', descending: true)
          .limit(5)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text('No recent patients')),
          );
        }

        // Extract unique patients from appointments
        Map<String, Map<String, dynamic>> uniquePatients = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String patientId = data['patientID']?.toString() ?? 'unknown';
          if (!uniquePatients.containsKey(patientId)) {
            uniquePatients[patientId] = data;
          }
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: uniquePatients.length,
          itemBuilder: (context, index) {
            var patientData = uniquePatients.values.elementAt(index);
            return _buildPatientListItem(patientData);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    Timestamp timestamp = appointment['startTime'];
    DateTime dateTime = timestamp.toDate();
    String formattedTime = DateFormat('h:mm a').format(dateTime);
    String status = appointment['status'] ?? 'Scheduled';

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 8), // Reduced vertical margin from 10 to 8
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DoctorAppointmentDetailPage(
                appointmentId: appointment['id'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10), // Adjusted padding to be more balanced
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Ensure proper vertical alignment
            children: [
              Container(
                // Increase the width so "12:32 pm" or "10:06 am" fits in one line
                width: 72,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FontAwesome.clock_o,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedTime, // e.g. "10:06 am"
                      maxLines: 1, // Force one-line display
                      overflow: TextOverflow.clip,
                      softWrap: false, // Don’t allow wrapping
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize
                      .min, // Add this to ensure the column takes minimum vertical space
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(FontAwesome.user,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(
                          // Wrap with Flexible to prevent overflow
                          child: Text(
                            appointment['patientName'] ?? 'Patient',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow
                                .ellipsis, // Add this to handle long names
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(FontAwesome.stethoscope,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(
                          // Wrap with Flexible to prevent overflow
                          child: Text(
                            appointment['reason'] ?? 'Consultation',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow
                                .ellipsis, // Add this to handle long text
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4), // Reduced vertical padding from 5 to 4
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(status),
                        size: 12, color: _getStatusColor(status)),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------
  // Patient List Item
  // ---------------------------
  Widget _buildPatientListItem(Map<String, dynamic> patientData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(FontAwesome.user_o, color: Colors.blue[700]),
          ),
        ),
        title: Text(
          patientData['patientName'] ?? 'Unknown Patient',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(FontAwesome.calendar_o, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('Last visit: ${_formatTimestamp(patientData['startTime'])}'),
          ],
        ),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child:
              Icon(FontAwesome.angle_right, color: Colors.blue[700], size: 16),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientDetailPage(
                patientId: patientData['patientID'] ?? '',
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return FontAwesome.check_circle;
      case 'pending':
        return FontAwesome.clock_o;
      case 'cancelled':
        return FontAwesome.times_circle;
      case 'completed':
        return FontAwesome.check_circle_o;
      default:
        return FontAwesome.question_circle;
    }
  }
}

class PatientDetailPage extends StatelessWidget {
  final String patientId;
  const PatientDetailPage({Key? key, required this.patientId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: Center(child: Text('Patient ID: $patientId')),
    );
  }
}

// Replace this placeholder class at the end of the file
class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;
  const AppointmentDetailPage({Key? key, required this.appointmentId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DoctorAppointmentDetailPage(appointmentId: appointmentId);
  }
}
