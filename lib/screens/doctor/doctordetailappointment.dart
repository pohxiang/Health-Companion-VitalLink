import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DoctorAppointmentDetailPage extends StatefulWidget {
  final String appointmentId;

  const DoctorAppointmentDetailPage({Key? key, required this.appointmentId})
      : super(key: key);

  @override
  State<DoctorAppointmentDetailPage> createState() =>
      _DoctorAppointmentDetailPageState();
}

class _DoctorAppointmentDetailPageState
    extends State<DoctorAppointmentDetailPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _appointmentData;
  Map<String, dynamic>? _patientData;
  String _errorMessage = '';
  bool _addingNotes = false;

  @override
  void initState() {
    super.initState();
    _fetchAppointmentData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointmentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get appointment data
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Appointment not found';
        });
        return;
      }

      final appointmentData = appointmentDoc.data()!;
      _appointmentData = appointmentData;

      // Get patient data if patientId exists (check both possible field names)
      String? patientId = appointmentData['patientId'] as String? ??
          appointmentData['patientID'] as String?;

      if (patientId != null) {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .get();

        if (patientDoc.exists) {
          _patientData = patientDoc.data();
        }
      }

      // Pre-fill notes if they exist
      if (appointmentData.containsKey('doctorNotes')) {
        _notesController.text = appointmentData['doctorNotes'] ?? '';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading appointment: ${e.toString()}';
      });
    }
  }

  Future<void> _updateAppointmentStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _appointmentData!['status'] = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment $status successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveNotes() async {
    if (_notesController.text.trim().isEmpty) return;

    setState(() => _addingNotes = true);

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'doctorNotes': _notesController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _appointmentData!['doctorNotes'] = _notesController.text;
        _addingNotes = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved successfully')),
      );
    } catch (e) {
      setState(() => _addingNotes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: ${e.toString()}')),
      );
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Not scheduled';
    return DateFormat('EEEE, MMM d, yyyy • h:mm a').format(timestamp.toDate());
  }

  Widget _buildPatientInfoCard() {
    if (_patientData == null) {
      return const Card(
        margin: EdgeInsets.all(8.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Patient information not available'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _patientData!['profilepicURL'] != null
                      ? NetworkImage(_patientData!['profilepicURL'])
                      : null,
                  child: _patientData!['profilepicURL'] == null
                      ? const Icon(Icons.person, size: 30, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_patientData!['firstName']} ${_patientData!['lastName']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _patientData!['email'] ?? 'No email provided',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _patientData!['phoneNumber'] ??
                            'No phone number provided',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_patientData!.containsKey('dob') &&
                _patientData!['dob'] != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.cake, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Date of Birth: ${DateFormat('MMM d, yyyy').format((_patientData!['dob'] as Timestamp).toDate())}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
            // Add medical history button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to patient medical history
                // This could be implemented in a future feature
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Medical history feature coming soon')),
                );
              },
              icon: const Icon(Icons.medical_information),
              label: const Text('View Medical History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentDetailsCard() {
    final statusColor = {
          'pending': Colors.orange,
          'confirmed': Colors.green,
          'cancelled': Colors.red,
          'completed': Colors.blue,
        }[_appointmentData!['status']] ??
        Colors.grey;

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Appointment Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _appointmentData!['status'].toString().toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _infoRow(
              Icons.calendar_today,
              'Date & Time:',
              _formatDateTime(_appointmentData!['appointmentTime']),
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.medical_services,
              'Reason:',
              _appointmentData!['reason'] ?? 'Not specified',
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.access_time,
              'Duration:',
              '${_appointmentData!['durationMinutes'] ?? 30} minutes',
            ),
            if (_appointmentData!.containsKey('createdAt') &&
                _appointmentData!['createdAt'] != null) ...[
              const SizedBox(height: 12),
              _infoRow(
                Icons.schedule,
                'Booked on:',
                DateFormat('MMM d, yyyy').format(
                    (_appointmentData!['createdAt'] as Timestamp).toDate()),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Doctor Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add your notes about this appointment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addingNotes ? null : _saveNotes,
                icon: _addingNotes
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_addingNotes ? 'Saving...' : 'Save Notes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // Only show certain buttons based on appointment status
    final String status = _appointmentData!['status'];

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                if (status == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus('confirmed'),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (status == 'pending' || status == 'confirmed') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus('cancelled'),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (status == 'confirmed') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus('completed'),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // This could navigate to a screen to start a video call
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Video call feature coming soon')),
                );
              },
              icon: const Icon(Icons.videocam),
              label: const Text('Start Video Call'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPatientInfoCard(),
                      _buildAppointmentDetailsCard(),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
