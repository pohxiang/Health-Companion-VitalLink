import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/screens/patients/requestappointment.dart';

class SpecialistSelectionScreen extends StatefulWidget {
  const SpecialistSelectionScreen({super.key});

  @override
  State<SpecialistSelectionScreen> createState() => _SpecialistSelectionScreenState();
}

  class _SpecialistSelectionScreenState extends State<SpecialistSelectionScreen> {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    List<String> _specialists = [];
    final TextEditingController _searchController = TextEditingController();
    String _searchQuery = '';

    @override
    void initState() {
      super.initState();
      _fetchSpecialties();
      _searchController.addListener(_onSearchChanged);
    }

    void _onSearchChanged() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }

    Future<void> _fetchSpecialties() async {
      final QuerySnapshot snapshot = await _firestore
          .collection('doctors')
          .get();

      final specialties = snapshot.docs
          .map((doc) => doc['department'] as String)
          .toSet()
          .toList();

      setState(() => _specialists = specialties);
    }

    List<String> get _filteredSpecialists {
      if (_searchQuery.isEmpty) return _specialists;
      return _specialists.where((spec) => 
        spec.toLowerCase().contains(_searchQuery)
      ).toList();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Specialist Type'),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.blue[50],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search specialist types...',
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
                itemCount: _filteredSpecialists.length,
                itemBuilder: (context, index) {
                  final specialty = _filteredSpecialists[index];
                  return Card(
                    child: ListTile(
                      title: Text(specialty),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorSelectionScreen(
                            specialty: specialty,
                          ),
                        ),
                      ),
                    ),
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
      _searchController.removeListener(_onSearchChanged);
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
    final TextEditingController _searchController = TextEditingController();
    String _searchQuery = '';

    @override
    void initState() {
      super.initState();
      _searchController.addListener(_onSearchChanged);
    }

    void _onSearchChanged() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    }

    List<QueryDocumentSnapshot> _filterDoctors(List<QueryDocumentSnapshot> doctors) {
      if (_searchQuery.isEmpty) return doctors;
      return doctors.where((doc) {
        final firstName = doc['firstName']?.toString().toLowerCase() ?? '';
        final lastName = doc['lastName']?.toString().toLowerCase() ?? '';
        final fullName = '$firstName $lastName';
        return fullName.contains(_searchQuery);
      }).toList();
    }

    @override
    void dispose() {
      _searchController.removeListener(_onSearchChanged);
      _searchController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Available ${widget.specialty} Doctors'),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.blue[50],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search doctors by name...',
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
                stream: FirebaseFirestore.instance
                    .collection('doctors')
                    .where('department', isEqualTo: widget.specialty)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final doctors = _filterDoctors(snapshot.data!.docs);

                  if (doctors.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No doctors available in this specialty'
                            : 'No doctors found matching "$_searchQuery"',
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return DoctorCard(
                        firstName: doctor['firstName'],
                        lastName: doctor['lastName'],
                        department: doctor['department'],
                        onTap: () => _showDoctorDetails(context, doctor),
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
  } 

  void _showDoctorDetails(BuildContext context, DocumentSnapshot doctor) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dr. ${doctor['firstName']} ${doctor['lastName']}',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Specialty: ${doctor['department']}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _bookAppointment(context, doctor),
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  void _bookAppointment(BuildContext context, DocumentSnapshot doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentRequestForm(
          doctorId: doctor.id,
          doctorName: '${doctor['firstName']} ${doctor['lastName']}',
      ),
      ),
    );
  }


class DoctorCard extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String department;
  final VoidCallback onTap;

  const DoctorCard({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.department,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.medical_services),
        ),
        title: Text('Dr. $firstName $lastName'),
        subtitle: Text(department),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}