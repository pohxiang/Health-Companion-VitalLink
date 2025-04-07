import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:vitallinkv2/screens/doctor/doctordetailappointment.dart';

class DoctorAppointmentsPage extends StatefulWidget {
  const DoctorAppointmentsPage({Key? key}) : super(key: key);

  @override
  State<DoctorAppointmentsPage> createState() => _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _doctorId;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentDoctor();
  }

  Future<void> _getCurrentDoctor() async {
    final user = _firestoreService.getCurrentUser();
    if (user != null) {
      setState(() {
        _doctorId = user.email!.replaceAll(RegExp(r'[.#$[\]]'), '_');
      });
      await _fetchAppointments();
    }
  }

  Future<void> _fetchAppointments() async {
    if (_doctorId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await _firestoreService.appointmentsCollection
          .where('assignedDoctor', isEqualTo: _doctorId)
          .get();

      Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID to map

        if (data['startTime'] == null) continue; // Skip if no startTime

        Timestamp timestamp = data['startTime'] as Timestamp;
        DateTime dateTime = timestamp.toDate();
        DateTime day = DateTime(dateTime.year, dateTime.month, dateTime.day);

        if (events[day] != null) {
          events[day]!.add(data);
        } else {
          events[day] = [data];
        }
      }

      setState(() {
        _events = events;
        _selectedEvents = _getEventsForDay(_selectedDay);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAppointments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const SizedBox(height: 8),
                _buildAppointmentCount(),
                const Divider(height: 1),
                Expanded(child: _buildEventsList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          // Navigate to create appointment page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Create Appointment (to be implemented)')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
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
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
        ),
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildAppointmentCount() {
    String formattedDate = DateFormat('MMMM d, yyyy').format(_selectedDay);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            formattedDate,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedEvents.length == 1
                  ? '1 Appointment'
                  : '${_selectedEvents.length} Appointments',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (_selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No appointments for this day',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Sort appointments by time
    _selectedEvents.sort((a, b) {
      Timestamp aTime = a['startTime'];
      Timestamp bTime = b['startTime'];
      return aTime.compareTo(bTime);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        var appointment = _selectedEvents[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    Timestamp timestamp = appointment['startTime'];
    DateTime dateTime = timestamp.toDate();
    String formattedTime = DateFormat('h:mm a').format(dateTime);

    String endTimeStr = '';
    if (appointment['endTime'] != null) {
      Timestamp endTimestamp = appointment['endTime'];
      DateTime endDateTime = endTimestamp.toDate();
      endTimeStr = ' - ${DateFormat('h:mm a').format(endDateTime)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      formattedTime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['patientName'] ?? 'Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedTime + endTimeStr,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['reason'] ?? 'Consultation',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(appointment['status']),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _updateAppointmentStatus(appointment['id'], 'cancelled');
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorAppointmentDetailPage(
                          appointmentId: appointment['id'],
                        ),
                      ),
                    );
                  },
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color chipColor;
    String statusText = status?.toString().toUpperCase() ?? 'SCHEDULED';

    switch (status?.toLowerCase()) {
      case 'confirmed':
        chipColor = Colors.green;
        break;
      case 'pending':
        chipColor = Colors.orange;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        break;
      case 'completed':
        chipColor = Colors.blue;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _updateAppointmentStatus(
      String appointmentId, String status) async {
    try {
      await _firestoreService.updateAppointmentStatus(
        appointmentId: appointmentId,
        status: status,
      );
      // Refresh appointments after update
      _fetchAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: $e')),
      );
    }
  }
}

// Placeholder for AppointmentDetailPage
class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailPage({Key? key, required this.appointmentId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.blue,
      ),
      body: Center(child: Text('Appointment ID: $appointmentId')),
    );
  }
}
