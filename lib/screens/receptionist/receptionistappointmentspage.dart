import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:intl/intl.dart';

class ReceptionistAppointmentsPage extends StatefulWidget {
  const ReceptionistAppointmentsPage({Key? key}) : super(key: key);

  @override
  State<ReceptionistAppointmentsPage> createState() =>
      _ReceptionistAppointmentsPageState();
}

class _ReceptionistAppointmentsPageState
    extends State<ReceptionistAppointmentsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate; // Currently selected date for filtering
  String _searchQuery = ''; // Current search query text

  // Fetch patient data from Firestore using patient ID
  Future<Map<String, dynamic>> _getPatientInfo(String patientId) async {
    final doc = await _firestoreService.patientsCollection.doc(patientId).get();
    return doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  // Fetch doctor data from Firestore using doctor ID
  Future<Map<String, dynamic>> _getDoctorInfo(String doctorId) async {
    final doc = await _firestoreService.doctorsCollection.doc(doctorId).get();
    return doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  // Format Firestore timestamp to date-time string
  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
  }

  // Return colour based on appointment status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.green;
      case 'requested':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Date picker dialog and updates selected date filter
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // Dialog for updating appointment details
  void _showEditAppointmentDialog(
      DocumentSnapshot appointment, Map<String, dynamic> data) {
    // Initialize form values with current appointment data
    String status = data['status'];
    DateTime startTime = (data['startTime'] as Timestamp).toDate();
    DateTime endTime = (data['endTime'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Appointment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // STATUS DROPDOWN
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(
                          value: 'waiting', child: Text('Waiting')),
                      DropdownMenuItem(
                          value: 'requested', child: Text('Requested')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (value) => setState(() => status = value!),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 20),

                  // START TIME PICKER
                  Row(
                    children: [
                      const Text('Start Time:'),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () async {
                          final date = await _pickDateTime(context, startTime);
                          if (date != null) setState(() => startTime = date);
                        },
                        child: Text(DateFormat('MMM dd, yyyy - HH:mm')
                            .format(startTime)),
                      ),
                    ],
                  ),

                  // END TIME PICKER
                  Row(
                    children: [
                      const Text('End Time:'),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () async {
                          final date = await _pickDateTime(context, endTime);
                          if (date != null) setState(() => endTime = date);
                        },
                        child: Text(
                            DateFormat('MMM dd, yyyy - HH:mm').format(endTime)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _handleAppointmentUpdate(
                  appointment.id,
                  status,
                  startTime,
                  endTime,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Date and time picking
  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime initialDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    return time == null
        ? null
        : DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
  }

  // Update appointment in Firestore with new data
  Future<void> _handleAppointmentUpdate(
    String appointmentId,
    String status,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      if (endTime.isBefore(startTime)) {
        throw Exception('End time cannot be before start time');
      }

      await _firestoreService.updateAppointment(
        appointmentId: appointmentId,
        status: status,
        startTime: startTime,
        endTime: endTime,
      );

      Navigator.pop(context);
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
        title: const Text('Appointments'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // SEARCH BAR SECTION
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),

          // APPOINTMENTS LIST SECTION
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.appointmentsCollection
                  .orderBy('startTime')
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Handle error state
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Build appointments list
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final appointment = snapshot.data!.docs[index];
                    final data = appointment.data() as Map<String, dynamic>;

                    // Use unique key for each list item
                    return KeyedSubtree(
                      key: ValueKey(appointment.id),
                      child: FutureBuilder(
                        future: Future.wait([
                          _getPatientInfo(data['patientID']),
                          _getDoctorInfo(data['assignedDoctor'])
                        ]),
                        builder:
                            (context, AsyncSnapshot<List<dynamic>> snapshot) {
                          // Show loading indicator while fetching data
                          if (!snapshot.hasData) {
                            return const ListTile(
                              title: Text('Loading appointment details...'),
                              leading: CircularProgressIndicator(),
                            );
                          }

                          // Extract fetched data
                          final patientData =
                              snapshot.data![0] as Map<String, dynamic>;
                          final doctorData =
                              snapshot.data![1] as Map<String, dynamic>;
                          final fullName =
                              '${patientData['firstName']} ${patientData['lastName']}'
                                  .toLowerCase();
                          final appointmentDate =
                              (data['startTime'] as Timestamp).toDate();

                          // FILTER LOGIC
                          // Apply search filter
                          final showItem = _searchQuery.isEmpty ||
                              fullName.contains(_searchQuery);

                          // Apply date filter
                          final dateMatch = _selectedDate == null ||
                              (appointmentDate.year == _selectedDate!.year &&
                                  appointmentDate.month ==
                                      _selectedDate!.month &&
                                  appointmentDate.day == _selectedDate!.day);

                          // Skip rendering if doesn't match filters
                          if (!showItem || !dateMatch) {
                            return const SizedBox.shrink();
                          }

                          // BUILD LIST ITEM
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              key: Key(appointment.id), // Unique key
                              onTap: () =>
                                  _showEditAppointmentDialog(appointment, data),
                              title: Text(
                                '${patientData['firstName']} ${patientData['lastName']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Doctor: ${doctorData['firstName']} ${doctorData['lastName']}'),
                                  Text(
                                      'Start: ${_formatTimestamp(data['startTime'])}'),
                                  Text(
                                      'End: ${_formatTimestamp(data['endTime'])}'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  data['status'].toString().toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor:
                                    _getStatusColor(data['status']),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // DATE FILTER CONTROLS
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date picker button
          FloatingActionButton(
            onPressed: () => _selectDate(context),
            backgroundColor: Colors.blue[700],
            mini: true,
            child: const Icon(Icons.calendar_today),
          ),
          const SizedBox(height: 8),
          // Clear filter button
          FloatingActionButton(
            onPressed: () => setState(() => _selectedDate = null),
            backgroundColor: Colors.blue[700],
            mini: true,
            child: const Icon(Icons.clear_all),
          ),
        ],
      ),
    );
  }
}
