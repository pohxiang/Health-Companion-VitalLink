import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Add this import

class Authentication {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirestoreService _firestoreService;

  Authentication()
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance,
        _firestoreService = FirestoreService();

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password provided.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      // Rethrow as a FirebaseAuthException with the updated message
      throw FirebaseAuthException(code: e.code, message: errorMessage);
    } catch (e) {
      // Catch any other errors.
      rethrow; // or throw Exception('Some other error: ${e.toString()}');
    }
  }

  // Register a new patient
  Future<User?> registerPatient(String email, String password, String firstName,
      String lastName, DateTime dob,
      {String? phoneNumber, String? country}) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? user = userCredential.user;
      if (user != null) {
        // Get sanitized email to use as document ID (remove invalid characters)
        String docId = email.replaceAll(RegExp(r'[.#$[\]]'), '_');

        // Create a new patient document in Firestore using email as ID
        await _firestoreService.addPatientWithCustomId(
          customId: docId,
          uid: user.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          dob: dob,
          phoneNumber: phoneNumber,
          country: country,
          profilepicURL: null, // You can add profile pic URL later
        );

        // Add user role to users collection, also using email as document ID
        await _firestore.collection('users').doc(docId).set({
          'uid': user.uid, // Store the Firebase Auth UID as a field
          'email': email,
          'role': 'patient',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return user;
      } else {
        throw Exception('User registration failed');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      throw FirebaseAuthException(code: e.code, message: errorMessage);
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

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      throw FirebaseAuthException(code: e.code, message: errorMessage);
    }
  }

  // Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
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
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage =
              'This operation requires recent authentication. Please log in again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      throw FirebaseAuthException(code: e.code, message: errorMessage);
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      } else {
        throw Exception('No user is currently logged in');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage =
              'This operation requires recent authentication. Please log in again.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'An unknown error occurred. Please try again.';
      }
      throw FirebaseAuthException(code: e.code, message: errorMessage);
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String uid = user.uid;
      String? role = await getUserRole(uid);

      try {
        // Delete profile data based on role
        if (role != null) {
          switch (role) {
            case 'doctor':
              await _firestore.collection('doctors').doc(uid).delete();
              break;
            case 'patient':
              await _firestore.collection('patients').doc(uid).delete();
              break;
            case 'receptionist':
              await _firestore.collection('receptionists').doc(uid).delete();
              break;
          }
        }

        // Delete user entry from users collection
        await _firestore.collection('users').doc(uid).delete();

        // Finally delete the auth user
        await user.delete();
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'requires-recent-login') {
          errorMessage =
              'This operation requires recent authentication. Please log in again.';
        } else {
          errorMessage =
              'An error occurred while deleting your account. Please try again.';
        }
        throw FirebaseAuthException(code: e.code, message: errorMessage);
      }
    } else {
      throw Exception('No user is currently logged in');
    }
  }

  // Add this method for Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      // Begin interactive sign in process
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();

      // If user cancels the sign-in flow
      if (gUser == null) {
        return null;
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Create a new credential for the user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // Finally, sign in
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in any role collection
        bool userExists = await _checkUserExists(user.uid, user.email!);

        // If user doesn't exist in our database yet, create a basic profile
        // but don't navigate them to any role-specific screen yet
        if (!userExists) {
          // Extract name parts from Google account
          String displayName = user.displayName ?? '';
          List<String> nameParts = displayName.split(' ');
          // ignore: unused_local_variable
          String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
          // ignore: unused_local_variable
          String lastName = nameParts.length > 1 ? nameParts.last : '';

          // Save to users collection with basic info
          String docId = user.email!.replaceAll(RegExp(r'[.#$[\]]'), '_');
          await _firestore.collection('users').doc(docId).set({
            'uid': user.uid,
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'loginMethod': 'google',
            'profileComplete':
                false, // Flag indicating profile needs completion
          });
        }
      }

      return user;
    } catch (e) {
      print("Google sign in error: $e");
      rethrow;
    }
  }

  // Helper method to check if user exists in any of our role-specific collections
  Future<bool> _checkUserExists(String uid, String email) async {
    String sanitizedEmail = email.replaceAll(RegExp(r'[.#$[\]]'), '_');

    // Check by UID
    final doctorDoc = await _firestore.collection('doctors').doc(uid).get();
    if (doctorDoc.exists) return true;

    final patientDoc = await _firestore.collection('patients').doc(uid).get();
    if (patientDoc.exists) return true;

    final receptionistDoc =
        await _firestore.collection('receptionists').doc(uid).get();
    if (receptionistDoc.exists) return true;

    // Check by sanitized email
    final doctorByEmail =
        await _firestore.collection('doctors').doc(sanitizedEmail).get();
    if (doctorByEmail.exists) return true;

    final patientByEmail =
        await _firestore.collection('patients').doc(sanitizedEmail).get();
    if (patientByEmail.exists) return true;

    final receptionistByEmail =
        await _firestore.collection('receptionists').doc(sanitizedEmail).get();
    if (receptionistByEmail.exists) return true;

    return false;
  }
}

Future<void> addDoctorWithCustomId({
  required String customId, // Sanitized email used as document ID
  required String uid, // Firebase Auth UID
  required String email,
  required String firstName,
  required String lastName,
  required DateTime dob,
  required String department,
  String? phoneNumber,
  String? profilepicURL,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  await firestore.collection('doctors').doc(customId).set({
    'uid': uid,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'dob': Timestamp.fromDate(dob),
    'department': department,
    'phoneNumber': phoneNumber,
    'profilepicURL': profilepicURL,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
