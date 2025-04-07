import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class ReceptionistEQueuePage extends StatefulWidget {
  const ReceptionistEQueuePage({Key? key}) : super(key: key);

  @override
  State<ReceptionistEQueuePage> createState() => _ReceptionistEQueuePageState();
}

class _ReceptionistEQueuePageState extends State<ReceptionistEQueuePage> {
  final FirestoreService _firestoreService = FirestoreService();
  int _queueLength = 0;
  int _servingCount = 0;
  int _averageWaitTime = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Queue Management'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshQueue,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.equeueCollection
            .orderBy('priority', descending: true)
            .orderBy('checkInTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final queueEntries = snapshot.data!.docs;
          _calculateQueueStatistics(
              queueEntries); // Calculate from existing data

          return Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                _buildQueueStats(),
                Expanded(
                  child: queueEntries.isEmpty
                      ? _buildEmptyState()
                      : _buildQueueList(queueEntries),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatientToQueue,
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.person_add),
        label: const Text('ADD PATIENT'),
      ),
    );
  }

  Widget _buildQueueStats() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Queue Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    icon: Icons.people_alt,
                    value: _queueLength.toString(),
                    label: 'Waiting'),
                _buildStatItem(
                    icon: Icons.access_time,
                    value: '$_averageWaitTime',
                    label: 'Avg. Wait (min)'),
                _buildStatItem(
                    icon: Icons.person,
                    value: _servingCount.toString(),
                    label: 'Serving'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.blue[700]),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
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

  // Modified to handle missing fields gracefully
  void _calculateQueueStatistics(List<QueryDocumentSnapshot> docs) {
    // Calculate waiting and serving counts using a safe cast
    final waiting = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['status'] == 'waiting';
    }).length;
    final serving = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['status'] == 'serving';
    }).length;

    // Filter documents that have a 'completedTime' field and are completed today
    final completedToday = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      if (!data.containsKey('completedTime')) {
        // If completedTime does not exist, skip this entry
        debugPrint('Skipping entry without completedTime: ${d.id}');
        return false;
      }
      final completedTime = data['completedTime'] as Timestamp?;
      return data['status'] == 'completed' &&
          (completedTime?.toDate().isAfter(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ) ??
              false);
    });

    int totalWait = 0, validEntries = 0;
    for (final doc in completedToday) {
      // Check if the document has the 'checkInTime' and 'serveTime' fields
      // Cast the document data to a Map<String, dynamic>
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('checkInTime') || !data.containsKey('serveTime')) {
        debugPrint(
            'Skipping invalid entry (missing checkInTime/serveTime): ${doc.id}');
        continue;
      }
      final checkIn = data['checkInTime'] as Timestamp?;
      final serve = data['serveTime'] as Timestamp?;

      if (checkIn == null || serve == null) {
        debugPrint('Skipping invalid entry (null checkIn/serve): ${doc.id}');
        continue;
      }

      // Calculate wait time only if both timestamps exist
      totalWait += ((serve.seconds - checkIn.seconds) / 60).round();
      validEntries++;
    }

    _queueLength = waiting;
    _servingCount = serving;
    _averageWaitTime = validEntries > 0 ? (totalWait ~/ validEntries) : 0;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_play_next,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          const Text(
            'No patients in queue',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<QueryDocumentSnapshot> entries) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final data = entry.data() as Map<String, dynamic>;

        // Check if fields exist before accessing
        final checkInTime = data.containsKey('checkInTime')
            ? data['checkInTime'] as Timestamp?
            : null;
        final serveTime = data.containsKey('serveTime')
            ? data['serveTime'] as Timestamp?
            : null;
        final status = data['status'] as String? ?? 'waiting';

        // Calculate wait time
        String waitTimeDisplay = 'N/A';
        if (checkInTime != null) {
          final DateTime checkedIn = checkInTime.toDate();
          if (status == 'completed' || status == 'serving') {
            waitTimeDisplay = serveTime != null
                ? '${serveTime.toDate().difference(checkedIn).inMinutes} mins'
                : 'Time data missing';
          } else {
            waitTimeDisplay =
                '${DateTime.now().difference(checkedIn).inMinutes} mins';
          }
        }

        return Card(
          key: ValueKey(entry.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: _buildPriorityIndicator(data['priority']),
            title: Text(data['patientName'] ?? 'Unknown Patient'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${data['status']}'),
                Text('Wait Time: $waitTimeDisplay'),
                if (data['doctorId'] != null)
                  Text('Doctor: ${data['doctorId']}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _manageQueueEntry(entry.id, data),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityIndicator(String priority) {
    Color color;
    // Updated switch to reflect new priority values if needed
    switch (priority.toLowerCase()) {
      case 'urgent':
        color = Colors.orange;
        break;
      case 'emergency':
        color = Colors.red;
        break;
      case 'normal':
      default:
        color = Colors.green;
    }

    return Container(
      width: 10,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  // ignore: unused_element
  Duration _calculateWaitTime(Timestamp? checkInTime) {
    if (checkInTime == null) return const Duration();
    return DateTime.now().difference(checkInTime.toDate());
  }

  Future<void> _refreshQueue() async {
    await _firestoreService.equeueCollection.get();
    setState(() {}); // Force rebuild
  }

  Future<void> _addPatientToQueue() async {
    // Implement patient addition logic
  }

  // Updated to allow changing both status and priority via drop down menus.
  Future<void> _manageQueueEntry(
      String entryId, Map<String, dynamic> data) async {
    String currentStatus = data['status'] ?? 'waiting';
    String? selectedStatus = currentStatus;

    // Use the new priority values: normal, urgent, emergency.
    String currentPriority = data['priority'] ?? 'normal';
    String? selectedPriority = currentPriority;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Queue Status & Priority'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select new status:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'waiting',
                        child: Text('Waiting'),
                      ),
                      DropdownMenuItem(
                        value: 'serving',
                        child: Text('Serving'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'no-show',
                        child: Text('No Show'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Select new priority:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPriority,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Normal'),
                      ),
                      DropdownMenuItem(
                        value: 'urgent',
                        child: Text('Urgent'),
                      ),
                      DropdownMenuItem(
                        value: 'emergency',
                        child: Text('Emergency'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedPriority = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                  ),
                  onPressed: () async {
                    // Update only if changes were made
                    if ((selectedStatus != null &&
                            selectedStatus != currentStatus) ||
                        (selectedPriority != null &&
                            selectedPriority != currentPriority)) {
                      try {
                        // Use a method that accepts a map to update both status and priority.
                        await _firestoreService.updateQueueEntry(
                          queueEntryId: entryId,
                          data: {
                            'status': selectedStatus!,
                            'priority': selectedPriority!,
                          },
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Status and priority updated successfully!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating entry: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
