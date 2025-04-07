import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:icons_flutter/icons_flutter.dart';

class DoctorPatientsPage extends StatefulWidget {
  const DoctorPatientsPage({Key? key}) : super(key: key);

  @override
  State<DoctorPatientsPage> createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String? _doctorId;
  bool _isLoading = true;
  List<DocumentSnapshot> _allPatients = [];
  List<DocumentSnapshot> _filteredPatients = [];
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _getCurrentDoctor();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentDoctor() async {
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      setState(() {
        _doctorId = user.uid;
      });
      await _fetchPatients();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filterQuery = _searchController.text;
      _filterPatients();
    });
  }

  void _filterPatients() {
    if (_filterQuery.isEmpty) {
      _filteredPatients = List.from(_allPatients);
    } else {
      _filteredPatients = _allPatients.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String fullName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
            .toLowerCase();
        return fullName.contains(_filterQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _fetchPatients() async {
    if (_doctorId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First, get all appointments for this doctor
      QuerySnapshot appointmentsSnapshot = await _firestoreService
          .appointmentsCollection
          .where('doctorId', isEqualTo: _doctorId)
          .get();

      // Extract unique patient IDs from appointments
      Set<String> patientIds = {};
      for (var doc in appointmentsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        // Check both possible field names
        String? patientId =
            data['patientId'] as String? ?? data['patientID'] as String?;
        if (patientId != null) {
          patientIds.add(patientId);
        }
      }

      // Now get patient documents for these IDs
      List<DocumentSnapshot> patients = [];

      if (patientIds.isNotEmpty) {
        for (String patientId in patientIds) {
          try {
            DocumentSnapshot patientDoc =
                await _firestoreService.patientsCollection.doc(patientId).get();

            if (patientDoc.exists) {
              patients.add(patientDoc);
            }
          } catch (e) {
            print('Error fetching patient $patientId: $e');
          }
        }
      }

      setState(() {
        _allPatients = patients;
        _filterPatients();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching patients: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Patients'),
        backgroundColor: Colors.blue[700], // Changed from black to blue
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPatients,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPatientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search patients...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _filterQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    if (_filteredPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _filterQuery.isEmpty
                  ? 'No patients found.'
                  : 'No patients match your search.',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        var patient = _filteredPatients[index].data() as Map<String, dynamic>;
        String patientID = _filteredPatients[index].id;
        return _buildPatientCard(patient, patientID);
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, String patientID) {
    String fullName =
        '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}';
    String age = '';

    if (patient['dob'] != null) {
      Timestamp dobTimestamp = patient['dob'];
      DateTime dob = dobTimestamp.toDate();
      age = '${DateTime.now().year - dob.year} years';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailPage(patientID: patientID),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                backgroundImage: patient['profilepicURL']?.isNotEmpty == true
                    ? NetworkImage(patient['profilepicURL'])
                    : null,
                child: patient['profilepicURL']?.isNotEmpty != true
                    ? Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(FontAwesome.birthday_cake,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          age.isNotEmpty ? 'Age: $age' : 'No age information',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(FontAwesome.phone,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          patient['phoneNumber']?.isNotEmpty == true
                              ? patient['phoneNumber']
                              : 'No contact information',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class PatientDetailPage extends StatefulWidget {
  final String patientID;

  const PatientDetailPage({Key? key, required this.patientID})
      : super(key: key);

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Map<String, dynamic>? _patientData;
  List<DocumentSnapshot> _patientAppointments = [];
  List<DocumentSnapshot> _medicalRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get patient information
      DocumentSnapshot patientDoc =
          await _firestoreService.getPatient(widget.patientID);

      if (patientDoc.exists) {
        Map<String, dynamic> patientData =
            patientDoc.data() as Map<String, dynamic>;

        // Get appointments
        QuerySnapshot appointmentDocs = await _firestoreService
            .appointmentsCollection
            .where('patientID', isEqualTo: widget.patientID)
            .orderBy('startTime', descending: true)
            .get();

        // Get medical records if you have them
        QuerySnapshot medicalRecordDocs =
            await _firestoreService.getMedicalRecords(widget.patientID).first;

        setState(() {
          _patientData = patientData;
          _patientAppointments = appointmentDocs.docs;
          _medicalRecords = medicalRecordDocs.docs;
          _isLoading = false;
        });
      } else {
        throw Exception('Patient not found');
      }
    } catch (e) {
      print('Error loading patient data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patient data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_patientData != null
            ? '${_patientData!['firstName']} ${_patientData!['lastName']}'
            : 'Patient Details'),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPatientInfoCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Medical Records'),
                  _buildMedicalRecordsList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Appointments'),
                  _buildAppointmentsList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {
          // Add medical record logic here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Add Medical Record (to be implemented)')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    if (_patientData == null) return const SizedBox.shrink();

    String fullName =
        '${_patientData!['firstName']} ${_patientData!['lastName']}';

    // Calculate age if we have DOB
    String age = '';
    if (_patientData!['dob'] != null) {
      Timestamp dobTimestamp = _patientData!['dob'];
      DateTime dob = dobTimestamp.toDate();
      age = '${DateTime.now().year - dob.year} years';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  _patientData!['profilepicURL']?.isNotEmpty == true
                      ? NetworkImage(_patientData!['profilepicURL'])
                      : null,
              child: _patientData!['profilepicURL']?.isNotEmpty != true
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildPatientInfoRow('Age', age.isNotEmpty ? age : 'Not specified'),
            _buildPatientInfoRow(
                'Phone', _patientData!['phoneNumber'] ?? 'Not specified'),
            _buildPatientInfoRow(
                'Email', _patientData!['email'] ?? 'Not specified'),
            _buildPatientInfoRow(
                'Country', _patientData!['country'] ?? 'Not specified'),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoRow(String label, String value) {
    // Define icons for each field
    IconData getIconForLabel() {
      switch (label) {
        case 'Age':
          return FontAwesome.birthday_cake;
        case 'Phone':
          return FontAwesome.phone;
        case 'Email':
          return FontAwesome.envelope;
        case 'Country':
          return FontAwesome.globe;
        default:
          return FontAwesome.info_circle;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(getIconForLabel(), size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    IconData getIconForSection() {
      switch (title) {
        case 'Medical Records':
          return FontAwesome.file_text_o;
        case 'Appointments':
          return FontAwesome.calendar_check_o;
        default:
          return FontAwesome.list;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(getIconForSection(), color: Colors.black),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalRecordsList() {
    if (_medicalRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No medical records found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _medicalRecords.length,
      itemBuilder: (context, index) {
        var record = _medicalRecords[index].data() as Map<String, dynamic>;
        return _buildMedicalRecordCard(record, _medicalRecords[index].id);
      },
    );
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record, String recordId) {
    Timestamp timestamp = record['createdAt'] ?? Timestamp.now();
    DateTime dateTime = timestamp.toDate();
    String formattedDate = DateFormat('MMM d, yyyy').format(dateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record #$recordId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (record['diagnosis'] != null)
              _buildMedicalRecordField('Diagnosis', record['diagnosis']),
            if (record['symptoms'] != null)
              _buildMedicalRecordField('Symptoms', record['symptoms']),
            if (record['treatment'] != null)
              _buildMedicalRecordField('Treatment', record['treatment']),
            if (record['notes'] != null)
              _buildMedicalRecordField('Notes', record['notes']),
            if (record['medications'] != null)
              _buildMedicalRecordField('Medications', record['medications']),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_patientAppointments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No appointments found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _patientAppointments.length,
      itemBuilder: (context, index) {
        var appointment =
            _patientAppointments[index].data() as Map<String, dynamic>;
        return _buildAppointmentCard(
            appointment, _patientAppointments[index].id);
      },
    );
  }

  Widget _buildAppointmentCard(
      Map<String, dynamic> appointment, String appointmentId) {
    Timestamp startTime = appointment['startTime'];
    DateTime dateTime = startTime.toDate();
    String formattedDate = DateFormat('MMM d, yyyy').format(dateTime);
    String formattedTime = DateFormat('h:mm a').format(dateTime);
    String status = appointment['status'] ?? 'Scheduled';

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = FontAwesome.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = FontAwesome.times_circle;
        break;
      case 'rescheduled':
        statusColor = Colors.orange;
        statusIcon = FontAwesome.refresh;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = FontAwesome.calendar;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FontAwesome.calendar,
                        size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(FontAwesome.clock_o, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (appointment['reason'] != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FontAwesome.comment, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${appointment['reason']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            if (appointment['notes'] != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(FontAwesome.sticky_note,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notes: ${appointment['notes']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
