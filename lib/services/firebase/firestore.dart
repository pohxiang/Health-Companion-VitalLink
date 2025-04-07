import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore;

  // Collections references
  CollectionReference get doctorsCollection => _firestore.collection('doctors');
  CollectionReference get patientsCollection =>
      _firestore.collection('patients');
  CollectionReference get receptionistsCollection =>
      _firestore.collection('receptionists');
  CollectionReference get appointmentsCollection =>
      _firestore.collection('appointments');
  CollectionReference<Map<String, dynamic>> get equeueCollection =>
      _firestore.collection('equeue').withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );
  CollectionReference get messagingCollection =>
      _firestore.collection('messaging');
  CollectionReference get medicinesCollection =>
      _firestore.collection('medicines');
  CollectionReference ordersCollection(String patientDocId) {
    return _firestore
        .collection('patients')
        .doc(patientDocId)
        .collection('orders');
  }

  // DOCTOR METHODS
  Future<void> addDoctor({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String department,
    String? profilepicURL,
  }) {
    return doctorsCollection.doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'dob': Timestamp.fromDate(dob),
      'department': department,
      'profilepicURL': profilepicURL ?? '',
    });
  }

  Future<DocumentSnapshot> getDoctor(String uid) {
    return doctorsCollection.doc(uid).get();
  }

  Stream<QuerySnapshot> getDoctors() {
    return doctorsCollection.snapshots();
  }

  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await appointmentsCollection.doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Optional: Remove from queue if it was in waiting state
      final appointmentDoc =
          await appointmentsCollection.doc(appointmentId).get();
      final data = appointmentDoc.data() as Map<String, dynamic>;

      if (data['status'] == 'waiting') {
        // Remove from doctor's queue
        await doctorsCollection
            .doc(data['assignedDoctor'])
            .collection('queue')
            .where('patientId', isEqualTo: data['patientID'])
            .get()
            .then((querySnapshot) {
          for (var doc in querySnapshot.docs) {
            doc.reference.delete();
          }
        });
      }
    } catch (e) {
      print('Error cancelling appointment: $e');
      rethrow;
    }
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String status,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return appointmentsCollection.doc(appointmentId).update({
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
    });
  }

  // Update Medicines
  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    if (!data.containsKey('description')) {
      data['description'] = 'Default Description';
    }
    await medicinesCollection.doc(id).update(data);
  }

  // MEDICINES METHODS
  // Add medicine
  Future<void> addMedicine(Map<String, dynamic> data) {
    // Validate required fields
    final requiredFields = ['name', 'price', 'quantity'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        throw ArgumentError('Missing required field: $field');
      }
    }

    // Set default description if missing
    data.putIfAbsent('description', () => 'Default Description');

    return medicinesCollection.add(data);
  }

  // Delete medicine
  Future<void> deleteMedicine(String id) async {
    await medicinesCollection.doc(id).delete();
  }

  // Get all medicines
  Stream<QuerySnapshot> getMedicines() {
    return medicinesCollection.orderBy('name').snapshots();
  }

  // Search medicines by name
  Future<QuerySnapshot> searchMedicines(String name) {
    return medicinesCollection.where('name', isEqualTo: name).get();
  }

  // Get medicine by ID
  Future<DocumentSnapshot> getMedicine(String id) {
    return medicinesCollection.doc(id).get();
  }

  Future<void> updateOrderStatus({
    required String patientDocId,
    required String orderId,
    required String newStatus,
  }) {
    return _firestore
        .collection('patients')
        .doc(patientDocId)
        .collection('orders')
        .doc(orderId)
        .update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateQueueEntry({
    required String queueEntryId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Update the document with the provided data.
      await equeueCollection.doc(queueEntryId).update(data);
    } catch (e) {
      // Log the error and rethrow to be handled by the caller.
      print('Error updating queue entry: $e');
      throw Exception('Error updating queue entry: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getOrdersByPatient(
      String patientDocId) {
    return ordersCollection(patientDocId)
        .orderBy('createdAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        )
        .snapshots();
  }

  Future<void> updateDoctor({
    required String uid,
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? department,
    String? profilepicURL,
  }) {
    Map<String, dynamic> data = {};
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (dob != null) data['dob'] = Timestamp.fromDate(dob);
    if (department != null) data['department'] = department;
    if (profilepicURL != null) data['profilepicURL'] = profilepicURL;

    return doctorsCollection.doc(uid).update(data);
  }

  // PATIENT METHODS
  Future<void> addPatient({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime dob,
    String? phoneNumber,
    String? country,
    String? profilepicURL,
  }) async {
    await _firestore.collection('patients').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'dob': Timestamp.fromDate(dob),
      'phoneNumber': phoneNumber,
      'country': country,
      'profilepicURL': profilepicURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPatientWithCustomId({
    required String customId,
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required DateTime dob,
    String? phoneNumber,
    String? country,
    String? profilepicURL,
  }) async {
    await _firestore.collection('patients').doc(uid).set({
      'uid': uid, // Store the Firebase Auth UID as a field
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'dob': Timestamp.fromDate(dob),
      'phoneNumber': phoneNumber,
      'country': country,
      'profilepicURL': profilepicURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot> getPatient(String uid) {
    return patientsCollection.doc(uid).get();
  }

  Stream<QuerySnapshot> getPatients() {
    return patientsCollection.snapshots();
  }

  Future<void> updatePatient({
    required String uid,
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? profilepicURL,
  }) {
    Map<String, dynamic> data = {};
    if (firstName != null) data['firstName'] = firstName;
    if (lastName != null) data['lastName'] = lastName;
    if (dob != null) data['dob'] = Timestamp.fromDate(dob);
    if (profilepicURL != null) data['profilepicURL'] = profilepicURL;

    return patientsCollection.doc(uid).update(data);
  }

  // MEDICAL RECORD METHODS
  Future<void> addMedicalRecord({
    required String patientId,
    required DateTime date,
    required String condition,
    required String prescription,
    String? feedback,
  }) {
    return patientsCollection.doc(patientId).collection('medicalRecords').add({
      'date': Timestamp.fromDate(date),
      'condition': condition,
      'prescription': prescription,
      'feedback': feedback ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMedicalRecords(String uid) {
    return patientsCollection
        .doc(uid)
        .collection('medicalRecords')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        )
        .orderBy('date', descending: true)
        .snapshots();
  }

  // RECEPTIONIST METHODS
  Future<void> addReceptionist({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime dob,
    String? profilepicURL,
  }) {
    return receptionistsCollection.doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'dob': Timestamp.fromDate(dob),
      'profilepicURL': profilepicURL ?? '',
    });
  }

  Future<DocumentSnapshot> getReceptionist(String uid) {
    return receptionistsCollection.doc(uid).get();
  }

  Stream<QuerySnapshot> getReceptionists() {
    return receptionistsCollection.snapshots();
  }

  // APPOINTMENT METHODS
  Future<String> createAppointment({
    required String assignedDoctor,
    required DateTime startTime,
    required DateTime endTime,
    required String patientID,
    required String createdBy,
    String status = 'scheduled',
  }) async {
    DocumentReference docRef = await appointmentsCollection.add({
      'assignedDoctor': assignedDoctor,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'patientID': patientID,
      'status': status,
      'createdOn': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    return docRef.id;
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) {
    return appointmentsCollection.doc(appointmentId).update({
      'status': status,
    });
  }

  Stream<QuerySnapshot> getDoctorAppointments(String doctorId) {
    return appointmentsCollection
        .where('assignedDoctor', isEqualTo: doctorId)
        .snapshots();
  }

  Stream<QuerySnapshot> getPatientAppointments(String patientId) {
    return appointmentsCollection
        .where('patientID', isEqualTo: patientId)
        .snapshots();
  }

  // MESSAGING METHODS
  Future<String> createChatRoom(List<String> participants) async {
    // Sort participants to ensure a consistent order.
    participants.sort();

    // Check if a chat room with these participants already exists.
    QuerySnapshot querySnapshot = await messagingCollection
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Return the existing chat room ID.
      return querySnapshot.docs.first.id;
    }

    // Create a new chat room with the necessary fields.
    DocumentReference docRef = await messagingCollection.add({
      'participants': participants,
      'lastMessage': 'Start a conversation',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_${participants[0]}': 0,
      'unreadCount_${participants[1]}': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String text,
  }) {
    return messagingCollection.doc(chatRoomId).collection('chat').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      // Update the last updated timestamp for the chat room
      messagingCollection.doc(chatRoomId).update({
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return messagingCollection
        .doc(chatRoomId)
        .collection('chat')
        .orderBy('timestamp')
        .snapshots();
  }

  Stream<QuerySnapshot> getUserChatRooms(String userId) {
    return messagingCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  // Register a new user based on role
  Future<User?> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String role, // 'doctor', 'patient', or 'receptionist'
    String? department, // required for doctors
    String? profilepicURL,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Add user data to Firestore based on role
        switch (role.toLowerCase()) {
          case 'doctor':
            if (department == null) {
              throw Exception('Department is required for doctors');
            }
            await addDoctor(
              uid: user.uid,
              firstName: firstName,
              lastName: lastName,
              dob: dob,
              department: department,
              profilepicURL: profilepicURL,
            );
            break;

          case 'patient':
            await addPatient(
              uid: user.uid,
              firstName: firstName,
              lastName: lastName,
              dob: dob,
              profilepicURL: profilepicURL,
            );
            break;

          case 'receptionist':
            await addReceptionist(
              uid: user.uid,
              firstName: firstName,
              lastName: lastName,
              dob: dob,
              profilepicURL: profilepicURL,
            );
            break;

          default:
            throw Exception('Invalid role specified');
        }

        // Add user role to a users collection for easy role checking
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': role.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } catch (e) {
      rethrow; // Rethrow to handle in UI
    }
  }

  // Login user
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow; // Rethrow to handle in UI
    }
  }

  // Get current logged in user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out user
  Future<void> signOut() async {
    return _auth.signOut();
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get user profile data based on role
  Future<DocumentSnapshot?> getUserProfile(String uid) async {
    try {
      String? role = await getUserRole(uid);
      if (role == null) return null;

      switch (role) {
        case 'doctor':
          return await getDoctor(uid);
        case 'patient':
          return await getPatient(uid);
        case 'receptionist':
          return await getReceptionist(uid);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Update user email
  Future<void> updateEmail(String newEmail) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updateEmail(newEmail);
      // Update email in users collection
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
      });
    } else {
      throw Exception('No user is currently logged in');
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw Exception('No user is currently logged in');
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String uid = user.uid;
      String? role = await getUserRole(uid);

      // Delete profile data based on role
      if (role != null) {
        switch (role) {
          case 'doctor':
            await doctorsCollection.doc(uid).delete();
            break;
          case 'patient':
            await patientsCollection.doc(uid).delete();
            break;
          case 'receptionist':
            await receptionistsCollection.doc(uid).delete();
            break;
        }
      }

      // Delete user entry from users collection
      await _firestore.collection('users').doc(uid).delete();

      // Finally delete the auth user
      await user.delete();
    } else {
      throw Exception('No user is currently logged in');
    }
  }

  Future<void> addPatientOrder({
    required String patientId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) {
    return patientsCollection.doc(patientId).collection('orders').add({
      'items': items,
      'total': total,
      'status': 'Processing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get Patient Orders Stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getPatientOrders(
      String patientId) {
    return patientsCollection
        .doc(patientId)
        .collection('orders')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        )
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // SHARED MESSAGING METHODS

  // Get messages between any two users
  Stream<QuerySnapshot> getConversation(String userId1, String userId2) {
    // Create a unique conversation ID by sorting user IDs
    List<String> sortedUsers = [userId1, userId2]..sort();
    String conversationId = '${sortedUsers[0]}_${sortedUsers[1]}';

    return messagingCollection
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get all conversations for a user (patients, doctors, receptionists)
  Stream<QuerySnapshot> getUserConversations(String userId) {
    return messagingCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  // Find a user across all collections (patient, doctor, receptionist)
  Future<Map<String, dynamic>?> findUserAcrossCollections(String userId) async {
    try {
      // Check doctors collection
      DocumentSnapshot doctorDoc = await doctorsCollection.doc(userId).get();
      if (doctorDoc.exists) {
        var data = doctorDoc.data() as Map<String, dynamic>;
        return {
          ...data,
          'role': 'doctor',
          'id': userId,
        };
      }

      // Check patients collection
      DocumentSnapshot patientDoc = await patientsCollection.doc(userId).get();
      if (patientDoc.exists) {
        var data = patientDoc.data() as Map<String, dynamic>;
        return {
          ...data,
          'role': 'patient',
          'id': userId,
        };
      }

      // Check receptionists collection
      DocumentSnapshot receptionistDoc =
          await receptionistsCollection.doc(userId).get();
      if (receptionistDoc.exists) {
        var data = receptionistDoc.data() as Map<String, dynamic>;
        return {
          ...data,
          'role': 'receptionist',
          'id': userId,
        };
      }

      return null;
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  // Get all users that a specific user can message
  Future<List<Map<String, dynamic>>> getMessageableUsers(
      String currentUserId) async {
    List<Map<String, dynamic>> users = [];
    String? currentUserRole = await getUserRole(currentUserId);

    if (currentUserRole == null) return [];

    try {
      // Logic based on user role
      switch (currentUserRole) {
        case 'patient':
          // Patients can message doctors and receptionists
          QuerySnapshot doctorsQuery = await doctorsCollection.get();
          for (var doc in doctorsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'doctor',
              'displayName':
                  'Dr. ${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
            });
          }

          QuerySnapshot receptionistsQuery =
              await receptionistsCollection.get();
          for (var doc in receptionistsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'receptionist',
              'displayName':
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''} (Receptionist)',
            });
          }
          break;

        case 'doctor':
          // Doctors can message patients and receptionists
          QuerySnapshot patientsQuery = await patientsCollection.get();
          for (var doc in patientsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'patient',
              'displayName':
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
            });
          }

          QuerySnapshot receptionistsQuery =
              await receptionistsCollection.get();
          for (var doc in receptionistsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'receptionist',
              'displayName':
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''} (Receptionist)',
            });
          }
          break;

        case 'receptionist':
          // Receptionists can message doctors and patients
          QuerySnapshot doctorsQuery = await doctorsCollection.get();
          for (var doc in doctorsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'doctor',
              'displayName':
                  'Dr. ${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
            });
          }

          QuerySnapshot patientsQuery = await patientsCollection.get();
          for (var doc in patientsQuery.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            users.add({
              ...userData,
              'id': doc.id,
              'role': 'patient',
              'displayName':
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
            });
          }
          break;
      }

      return users;
    } catch (e) {
      print('Error getting messageable users: $e');
      return [];
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      await messagingCollection.doc(chatRoomId).update({
        'unreadCount_$userId': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      QuerySnapshot chatRooms = await messagingCollection
          .where('participants', arrayContains: userId)
          .get();

      int totalUnread = 0;
      for (var doc in chatRooms.docs) {
        var data = doc.data() as Map<String, dynamic>;
        totalUnread += (data['unreadCount_$userId'] ?? 0) as int;
      }

      return totalUnread;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // E-QUEUE MANAGEMENT METHODS

  // Get queue stream for clinic display or reception desk
  Stream<QuerySnapshot> getActiveQueueStream() {
    return equeueCollection
        .where('status', isEqualTo: 'waiting')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get patient's position in queue
  Future<int> getPatientQueuePosition({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      QuerySnapshot queueSnapshot = await equeueCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('status',
              whereIn: ['waiting', 'serving']) // Include both statuses
          .orderBy('timestamp', descending: false)
          .get();

      for (int i = 0; i < queueSnapshot.docs.length; i++) {
        var data = queueSnapshot.docs[i].data() as Map<String, dynamic>;
        if (data['patientId'] == patientId) {
          return i + 1; // 1-based position
        }
      }
      return 0; // Not found
    } catch (e) {
      print('Error getting queue position: $e');
      return 0;
    }
  }

  Future<void> updateQueueWaitTime(String queueId, int waitTime) async {
    try {
      await equeueCollection.doc(queueId).update({
        'waitTime': waitTime,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating wait time: $e');
    }
  }

  // Add patient to queue
  Future<String> addPatientToQueue({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    String? reason,
    String? priority = 'normal', // normal, urgent, emergency
  }) async {
    try {
      // Check if patient is already in queue
      QuerySnapshot existingQuery = await equeueCollection
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'waiting')
          .get();

      if (existingQuery.docs.isNotEmpty) {
        return existingQuery.docs.first.id; // Return existing queue entry ID
      }

      // Add new queue entry
      DocumentReference docRef = await equeueCollection.add({
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorname': doctorName,
        'reason': reason,
        'priority': priority,
        'status': 'waiting',
        'timestamp': FieldValue.serverTimestamp(),
        'waitTime': 0, // Updated periodically
        'checkInTime': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error adding patient to queue: $e');
      throw Exception('Failed to add patient to queue');
    }
  }

  // Remove patient from queue
  Future<void> removePatientFromQueue(String queueEntryId) async {
    await equeueCollection.doc(queueEntryId).delete();
  }

  // Update queue entry status
  Future<void> updateQueueEntryStatus({
    required String queueEntryId,
    required String status,
  }) async {
    try {
      final timestamp = Timestamp.now();
      final updates = <String, dynamic>{
        'status': status,
      };

      // Add appropriate timestamp based on status
      if (status == 'completed') {
        updates['completeTime'] = timestamp;
      } else if (status == 'serving') {
        updates['serveTime'] = timestamp;
      } else if (status == 'no-show') {
        updates['noShowTime'] = timestamp;
      }

      await equeueCollection.doc(queueEntryId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Get doctor's current queue
  Stream<QuerySnapshot> getDoctorQueueStream(String doctorId) {
    return equeueCollection
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: ['waiting', 'serving'])
        .orderBy('priority', descending: true) // Emergency first
        .orderBy('timestamp', descending: false) // Then by arrival time
        .snapshots();
  }

  Future<QuerySnapshot> getPatientActiveQueue(String patientId) {
    return equeueCollection
        .where('patientId', isEqualTo: patientId)
        .where('status', whereIn: ['waiting', 'serving']).get();
  }

  // Get estimated wait time for a specific doctor
  Future<int> getEstimatedWaitTimeForDoctor(String doctorId) async {
    try {
      QuerySnapshot queueSnapshot = await equeueCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'waiting')
          .get();

      // Simple calculation: 15 minutes per waiting patient
      return queueSnapshot.docs.length * 15;
    } catch (e) {
      print('Error calculating wait time: $e');
      return 0;
    }
  }

  // Call next patient for doctor
  Future<Map<String, dynamic>?> callNextPatientForDoctor(
      String doctorId) async {
    try {
      final waiting = await equeueCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('priority', descending: true) // Match index order
          .orderBy('checkInTime', descending: false)
          .limit(1)
          .get();

      if (waiting.docs.isEmpty) {
        return null;
      }

      final nextPatient = waiting.docs.first;
      // ignore: unnecessary_cast
      final nextPatientData = nextPatient.data() as Map<String, dynamic>;

      // Update status to serving
      await updateQueueEntryStatus(
        queueEntryId: nextPatient.id,
        status: 'serving',
      );

      return {
        'id': nextPatient.id,
        'patientName': nextPatientData['patientName'],
        ...nextPatientData,
      };
    } catch (e) {
      print('Error calling next patient: $e');
      rethrow;
    }
  }

  // Receptionist assign doctor to queue entry
  Future<void> assignDoctorToQueueEntry({
    required String queueEntryId,
    required String doctorId,
    String? doctorName,
  }) async {
    await equeueCollection.doc(queueEntryId).update({
      'doctorId': doctorId,
      'doctorName': doctorName,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Get queue statistics
  Future<Map<String, dynamic>> getQueueStatistics() async {
    final user = getCurrentUser();
    if (user == null) {
      return {
        'waitingCount': 0,
        'servingCount': 0,
        'completedTodayCount': 0,
        'averageWaitTimeMinutes': 0,
      };
    }

    try {
      // Get the start of today
      final startOfDay = DateTime.now().subtract(Duration(
        hours: DateTime.now().hour,
        minutes: DateTime.now().minute,
        seconds: DateTime.now().second,
        milliseconds: DateTime.now().millisecond,
      ));

      // Get statistics following the index order (doctorId, status, priority, checkInTime)
      final waitingSnapshot = await equeueCollection
          .where('doctorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'waiting')
          .get();

      final servingSnapshot = await equeueCollection
          .where('doctorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'serving')
          .get();

      final completedTodaySnapshot = await equeueCollection
          .where('doctorId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .where('checkInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Calculate average wait time
      double totalWaitMinutes = 0;
      for (var doc in completedTodaySnapshot.docs) {
        final data = doc.data();
        final checkInTime = data['checkInTime'] as Timestamp?;
        final completeTime = data['completeTime'] as Timestamp?;

        if (checkInTime != null && completeTime != null) {
          final waitDuration =
              completeTime.toDate().difference(checkInTime.toDate());
          totalWaitMinutes += waitDuration.inMinutes;
        }
      }

      double averageWaitTimeMinutes = 0;
      if (completedTodaySnapshot.docs.isNotEmpty) {
        averageWaitTimeMinutes =
            totalWaitMinutes / completedTodaySnapshot.docs.length;
      }

      return {
        'waitingCount': waitingSnapshot.docs.length,
        'servingCount': servingSnapshot.docs.length,
        'completedTodayCount': completedTodaySnapshot.docs.length,
        'averageWaitTimeMinutes': averageWaitTimeMinutes.round(),
      };
    } catch (e) {
      print('Error getting queue statistics: $e');
      return {
        'waitingCount': 0,
        'servingCount': 0,
        'completedTodayCount': 0,
        'averageWaitTimeMinutes': 0,
      };
    }
  }

  // Calculate average wait time from completed entries
  // ignore: unused_element
  int _calculateAverageWaitTime(QuerySnapshot completedSnapshot) {
    if (completedSnapshot.docs.isEmpty) return 0;

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

    return validEntries > 0 ? (totalWaitMinutes / validEntries).round() : 0;
  }

  // Add this method
  Future<void> initializeQueueCollection() async {
    try {
      // Check if collection exists by trying to get at least one document
      final snapshot = await equeueCollection.limit(1).get();

      // If empty, add a test document
      if (snapshot.docs.isEmpty) {
        await equeueCollection.add({
          'patientId': 'system',
          'patientName': 'System Initialization',
          'doctorId': 'system',
          'reason': 'Queue initialization',
          'priority': 'normal',
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
          'checkInTime': FieldValue.serverTimestamp(),
          'completedTime': FieldValue.serverTimestamp(),
          'isSystem': true
        });

        print('equeue collection initialized');
      }
    } catch (e) {
      print('Error initializing queue: $e');
    }
  }

  Future<void> createDoctorNotification({
    required String doctorId,
    required String title,
    required String message,
    String type = 'general',
    String priority = 'normal',
    bool actionable = false,
    String? actionId,
    String? actionType,
  }) async {
    await firestore.collection('notifications').add({
      'recipientId': doctorId,
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': type,
      'priority': priority,
      'actionable': actionable,
      'actionId': actionId,
      'actionType': actionType,
    });
  }

  // Check queue length and notify doctor if it exceeds threshold
  Future<void> checkQueueThreshold(String doctorId, {int threshold = 5}) async {
    try {
      print('Checking queue threshold for doctor: $doctorId');

      QuerySnapshot queueSnapshot = await equeueCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'waiting')
          .get();

      int queueLength = queueSnapshot.size;
      print('Found $queueLength patients waiting for doctor $doctorId');

      // Calculate number of emergency cases
      int emergencyCases = 0;
      for (var doc in queueSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['priority'] == 'emergency' || data['priority'] == 'urgent') {
          emergencyCases++;
        }
      }

      // Check if queue exceeds threshold or has emergency cases
      if (queueLength >= threshold || emergencyCases > 0) {
        // Prevent duplicate notifications by checking if a similar notification was sent in the last hour
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

        QuerySnapshot recentNotifications = await firestore
            .collection('notifications')
            .where('recipientId', isEqualTo: doctorId)
            .where('type', isEqualTo: 'queue')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
            .get();

        // Only send notification if no recent notifications exist
        if (recentNotifications.docs.isEmpty) {
          String title = emergencyCases > 0
              ? 'URGENT: Priority Cases in Queue'
              : 'Queue Alert';

          String message = emergencyCases > 0
              ? 'You have $emergencyCases urgent/emergency cases waiting'
              : 'You have $queueLength patients waiting in your queue';

          await createDoctorNotification(
            doctorId: doctorId,
            title: title,
            message: message,
            type: 'queue',
            priority: emergencyCases > 0 ? 'high' : 'normal',
            actionable: true,
            actionType: 'queue',
          );

          print('Queue threshold notification sent to doctor $doctorId');
        }
      }
    } catch (e) {
      print('Error checking queue threshold: $e');
    }
  }

  // Add this method to verify and fix the queue data structure
  Future<void> verifyQueueDataStructure() async {
    try {
      // Check for any inconsistent queue entries
      final snapshot = await equeueCollection.get();

      for (var doc in snapshot.docs) {
        var data = doc.data();

        // Check if the entry has required fields
        if (!data.containsKey('doctorId') || !data.containsKey('patientId')) {
          print('Found queue entry with missing fields: ${doc.id}');
          // Either fix or delete the entry
        }

        // Check if the doctorId field is properly formatted
        if (data['doctorId'] == null || data['doctorId'] is! String) {
          print('Queue entry has invalid doctorId: ${doc.id}');
          // Fix if possible
        }
      }

      print('Queue data structure verification complete');
    } catch (e) {
      print('Error verifying queue data structure: $e');
    }
  }
}
