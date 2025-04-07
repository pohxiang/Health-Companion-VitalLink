import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';

class DoctorQueuePage extends StatefulWidget {
  const DoctorQueuePage({Key? key}) : super(key: key);

  @override
  State<DoctorQueuePage> createState() => _DoctorQueuePageState();
}

class _DoctorQueuePageState extends State<DoctorQueuePage> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _doctorId;
  bool _isLoading = true;
  Map<String, dynamic>? _currentPatient;
  int _queueLength = 0;
  int _averageWaitTime = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentDoctor();
  }

  Future<void> _getCurrentDoctor() async {
    try {
      final user = _firestoreService.getCurrentUser();
      if (user != null) {
        setState(() {
          _doctorId = user.uid;
          _isLoading = true;
        });

        // Load data
        await Future.wait([
          _loadCurrentPatient(),
          _calculateQueueStatistics(),
        ]);

        // Add this line to check threshold whenever doctor opens queue page
        if (_doctorId != null) {
          await _firestoreService.checkQueueThreshold(_doctorId!);
        }
      } else {
        // Handle case where there is no current doctor
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No doctor account found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading doctor data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentPatient() async {
    if (_doctorId == null) return;

    try {
      QuerySnapshot servingSnapshot = await _firestoreService.equeueCollection
          .where('doctorId', isEqualTo: _doctorId)
          .where('status', isEqualTo: 'serving')
          .limit(1)
          .get();

      if (servingSnapshot.docs.isNotEmpty) {
        var doc = servingSnapshot.docs.first;
        setState(() {
          _currentPatient = {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        });
      } else {
        setState(() {
          _currentPatient = null;
        });
      }
    } catch (e) {
      print('Error loading current patient: $e');
    }
  }

  Future<void> _calculateQueueStatistics() async {
    if (_doctorId == null) return;

    try {
      QuerySnapshot waitingSnapshot = await _firestoreService.equeueCollection
          .where('doctorId', isEqualTo: _doctorId)
          .where('status', isEqualTo: 'waiting')
          .get();

      // Get completed patients today to calculate average wait time
      DateTime today = DateTime.now();
      DateTime startOfDay = DateTime(today.year, today.month, today.day);

      QuerySnapshot completedSnapshot = await _firestoreService.equeueCollection
          .where('doctorId', isEqualTo: _doctorId)
          .where('status', isEqualTo: 'completed')
          .where('completedTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Calculate average wait time
      int totalWaitMinutes = 0;
      int validEntries = 0;

      for (var doc in completedSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['checkInTime'] != null && data['serveTime'] != null) {
          Timestamp checkIn = data['checkInTime'];
          Timestamp serve = data['serveTime'];
          int waitMinutes = ((serve.seconds - checkIn.seconds) / 60).round();
          totalWaitMinutes += waitMinutes;
          validEntries++;
        }
      }

      setState(() {
        _queueLength = waitingSnapshot.docs.length;
        _averageWaitTime =
            validEntries > 0 ? (totalWaitMinutes / validEntries).round() : 0;
      });
    } catch (e) {
      print('Error calculating queue statistics: $e');
    }
  }

  Future<void> _callNextPatient() async {
    if (_doctorId == null) return;
    if (_currentPatient != null) {
      // Confirm action
      // ignore: unused_local_variable
      bool confirm = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Patient Still In Progress'),
                    content: const Text(
                        'You have a patient currently being served. Complete or cancel their session before calling the next patient.'),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  )) ??
          false;

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var result = await _firestoreService.callNextPatientForDoctor(_doctorId!);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Now serving: ${result['patientName'] ?? 'Next patient'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No patients waiting in the queue'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadCurrentPatient();
      await _calculateQueueStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeCurrentPatient() async {
    if (_currentPatient == null || _doctorId == null) return;

    // Confirm action
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Complete Consultation'),
            content: const Text(
                'Are you sure you want to mark this consultation as completed?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Complete'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.updateQueueEntryStatus(
        queueEntryId: _currentPatient!['id'],
        status: 'completed',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient consultation completed'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadCurrentPatient();
      await _calculateQueueStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markNoShow() async {
    if (_currentPatient == null || _doctorId == null) return;

    // Confirm action
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mark as No-Show'),
            content: const Text('Are you sure this patient did not show up?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Mark No-Show'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.updateQueueEntryStatus(
        queueEntryId: _currentPatient!['id'],
        status: 'no-show',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient marked as no-show'),
          backgroundColor: Colors.orange,
        ),
      );

      await _loadCurrentPatient();
      await _calculateQueueStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('h:mm a').format(dateTime);
  }

  Duration _calculateWaitTime(Timestamp? checkInTime) {
    if (checkInTime == null) return const Duration();
    final DateTime checkIn = checkInTime.toDate();
    final DateTime now = DateTime.now();
    return now.difference(checkIn);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);
    return "$twoDigitHours:$twoDigitMinutes";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadCurrentPatient();
              await _calculateQueueStatistics();
              setState(() {
                _isLoading = false;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadCurrentPatient();
                await _calculateQueueStatistics();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQueueStats(),
                      const SizedBox(height: 24),
                      _buildCurrentPatient(),
                      const SizedBox(height: 24),
                      _buildWaitingList(),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: _currentPatient == null
          ? FloatingActionButton.extended(
              onPressed: _callNextPatient,
              backgroundColor: Colors.green,
              icon: const Icon(FontAwesome.user_plus),
              label: const Text('CALL NEXT'),
            )
          : null,
    );
  }

  Widget _buildQueueStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Queue Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: FontAwesome.users,
                  value: _queueLength.toString(),
                  label: 'Waiting',
                  iconColor: Colors.blue[700]!,
                ),
                _buildStatItem(
                  icon: FontAwesome.clock_o,
                  value: '$_averageWaitTime',
                  label: 'Avg. Wait (min)',
                  iconColor: Colors.orange,
                ),
                _buildStatItem(
                  icon: _currentPatient != null
                      ? FontAwesome.user_md
                      : FontAwesome.user_o,
                  value: _currentPatient != null ? 'Active' : 'None',
                  label: 'Current Patient',
                  iconColor:
                      _currentPatient != null ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPatient() {
    if (_currentPatient == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  FontAwesome.user_md,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Patient Currently Being Served',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _callNextPatient,
                  icon: const Icon(FontAwesome.user_plus),
                  label: const Text('CALL NEXT PATIENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate wait time
    Duration waitTime = _calculateWaitTime(_currentPatient!['checkInTime']);
    String waitTimeFormatted = _formatDuration(waitTime);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[700],
                  child: const Icon(
                    FontAwesome.user,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _currentPatient!['patientName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Now Serving',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(FontAwesome.clock_o,
                              size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Check-in: ${_formatTimestamp(_currentPatient!['checkInTime'])}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(FontAwesome.hourglass_half,
                              size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Wait time: $waitTimeFormatted hrs',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (_currentPatient!['reason'] != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Reason for visit:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentPatient!['reason'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _completeCurrentPatient,
                  icon: const Icon(FontAwesome.check_circle),
                  label: const Text('COMPLETE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _markNoShow,
                  icon: const Icon(FontAwesome.user_times),
                  label: const Text('NO SHOW'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Waiting List',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total: $_queueLength',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_doctorId != null) _buildQueueStream(),
      ],
    );
  }

  Widget _buildQueueStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.equeueCollection
          .where('doctorId', isEqualTo: _doctorId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('priority', descending: true)
          .orderBy('checkInTime',
              descending: false) // Change timestamp to checkInTime
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
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(FontAwesome.warning, size: 40, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading queue: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Force UI refresh
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FontAwesome.list_alt,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No patients waiting in queue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
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
            var data = doc.data() as Map<String, dynamic>;

            // Calculate wait time in minutes
            Duration waitTime = _calculateWaitTime(data['checkInTime']);
            int waitMinutes = waitTime.inMinutes;

            String waitDisplay = waitMinutes <= 60
                ? '$waitMinutes mins'
                : '${(waitMinutes / 60).toStringAsFixed(1)} hrs';

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[700],
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(FontAwesome.clock_o,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Check-in: ${_formatTimestamp(data['checkInTime'])}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(FontAwesome.hourglass_half,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Waiting: $waitDisplay',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(data['priority']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['priority']?.toString().toUpperCase() ?? 'NORMAL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(dynamic priority) {
    switch (priority?.toString().toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
