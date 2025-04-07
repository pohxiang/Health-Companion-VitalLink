// appointment_request.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/screens/patients/patienthome.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';

class AppointmentRequestForm extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const AppointmentRequestForm({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<AppointmentRequestForm> createState() => _AppointmentRequestFormState();
}

class _AppointmentRequestFormState extends State<AppointmentRequestForm> {
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitAppointment() async {
    try {
      final user = _firestoreService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');
      
      if (_selectedDate == null || _selectedTime == null) {
        throw Exception('Please select date and time');
      }

      // Combine date and time
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Create 1 hour appointment slot
      final endTime = appointmentDateTime.add(const Duration(hours: 1));

      // Create appointment
      await _firestoreService.createAppointment(
        assignedDoctor: widget.doctorId,
        startTime: appointmentDateTime,
        endTime: endTime,
        patientID: user.uid,
        createdBy: user.uid,
        status: 'requested',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment requested successfully!')),
      );

      // Redirect to home page with stack clearance
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => PatientDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Appointment Request'),
      backgroundColor: Colors.blue[800], 
      foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blue[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDoctorInfo(),
              const SizedBox(height: 24),
              _buildDateTimeSelection(),
              const SizedBox(height: 24),
              _buildNotesField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.medical_services, size: 40),
            const SizedBox(width: 16),
            Text(
              'Dr. ${widget.doctorName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Preferred Date & Time:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDate(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.teal[100], // Light yellow background
                  side: BorderSide(color: Colors.grey[300]!), // Light border
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                style: TextStyle(
                  color: _selectedDate == null 
                      ? Colors.grey[600] 
                      : Colors.black87,
                )
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectTime(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.teal[100],  // Light yellow background
                  side: BorderSide(color: Colors.grey[300]!), // Light border
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _selectedTime == null
                      ? 'Select Time'
                      : _selectedTime!.format(context),
                  style: TextStyle(
                  color: _selectedTime == null 
                      ? Colors.grey[600] 
                      : Colors.black87,
                  )
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter any special requirements or notes...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _selectedDate == null || _selectedTime == null
            ? null
            : _submitAppointment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[900], // Dark blue background
          foregroundColor: Colors.white, // White text
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Submit Appointment Request',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    
  }
}