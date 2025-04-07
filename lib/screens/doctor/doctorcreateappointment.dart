import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';

class DoctorCreateAppointment extends StatefulWidget {
  const DoctorCreateAppointment({Key? key}) : super(key: key);

  @override
  State<DoctorCreateAppointment> createState() =>
      _DoctorCreateAppointmentState();
}

class _DoctorCreateAppointmentState extends State<DoctorCreateAppointment> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _selectedPatientId;
  String? _selectedPatientName;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 30;
  String _reason = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all patients
      final snapshot = await _firestoreService.patientsCollection.get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'email': data['email'] ?? '',
            'fullName': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
          };
        }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error loading patients: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _createAppointment() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedPatientId == null) {
      _showErrorSnackBar('Please select a patient');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate start and end times
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final endTime = startTime.add(Duration(minutes: _durationMinutes));

      // Check for time conflicts
      final isTimeConflict = await _checkTimeConflict(startTime, endTime);
      if (isTimeConflict) {
        _showErrorSnackBar(
            'This time slot conflicts with an existing appointment');
        setState(() => _isLoading = false);
        return;
      }

      // Create the appointment
      final appointmentId = await _firestoreService.createAppointment(
        assignedDoctor: _currentUser!.uid,
        startTime: startTime,
        endTime: endTime,
        patientID: _selectedPatientId!,
        createdBy: _currentUser.uid,
        status: 'scheduled',
      );

      // Set additional appointment details
      await _firestoreService.appointmentsCollection.doc(appointmentId).update({
        'reason': _reason,
        'patientName': _selectedPatientName,
      });

      // Show success message
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create appointment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkTimeConflict(DateTime startTime, DateTime endTime) async {
    try {
      // Check for conflicting appointments for this doctor
      final conflictsQuery = await _firestoreService.appointmentsCollection
          .where('assignedDoctor', isEqualTo: _currentUser!.uid)
          .where('status', whereIn: ['scheduled', 'confirmed'])
          .where('startTime', isLessThan: Timestamp.fromDate(endTime))
          .get();

      for (var doc in conflictsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final existingStartTime = (data['startTime'] as Timestamp).toDate();
        final existingEndTime = (data['endTime'] as Timestamp).toDate();

        // Check if there is any overlap
        if (startTime.isBefore(existingEndTime) &&
            endTime.isAfter(existingStartTime)) {
          return true; // Conflict found
        }
      }

      return false; // No conflicts
    } catch (e) {
      print('Error checking time conflict: $e');
      // Rethrow to alert the user
      throw Exception('Unable to check for schedule conflicts: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Success!'),
        content: const Text('Appointment has been created successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('h:mm a');

    DateTime combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Schedule Appointment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Patient Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(
                                  FontAwesome.user,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Patient',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: DropdownButtonFormField<String>(
                              value: _selectedPatientId,
                              decoration: InputDecoration(
                                hintText: 'Select patient',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: _patients.map((patient) {
                                return DropdownMenuItem<String>(
                                  value: patient['id'],
                                  child: Text(patient['fullName']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPatientId = value;
                                  _selectedPatientName = _patients.firstWhere(
                                      (p) => p['id'] == value)['fullName'];
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a patient';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date & Time
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(
                                  FontAwesome.calendar,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: Icon(FontAwesome.calendar_o,
                                color: Colors.grey[600]),
                            title: const Text('Date'),
                            subtitle: Text(dateFormat.format(_selectedDate)),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey[400]),
                            onTap: _selectDate,
                          ),
                          const Divider(),
                          ListTile(
                            leading: Icon(FontAwesome.clock_o,
                                color: Colors.grey[600]),
                            title: const Text('Time'),
                            subtitle: Text(timeFormat.format(combinedDateTime)),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey[400]),
                            onTap: _selectTime,
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration (minutes)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [15, 30, 45, 60].map((duration) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _durationMinutes = duration;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _durationMinutes == duration
                                              ? Colors.blue[700]
                                              : Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$duration min',
                                          style: TextStyle(
                                            color: _durationMinutes == duration
                                                ? Colors.white
                                                : Colors.grey[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reason
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(
                                  FontAwesome.stethoscope,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reason for Visit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: TextFormField(
                              decoration: InputDecoration(
                                hintText: 'Enter reason for appointment',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a reason';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {
                                  _reason = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading ? null : _createAppointment,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Schedule Appointment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
