// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/services/firebase/firestore.dart';
import 'package:vitallinkv2/services/firebase/authentication.dart';

class AddOtherRoles extends StatefulWidget {
  const AddOtherRoles({Key? key}) : super(key: key);

  @override
  State<AddOtherRoles> createState() => _AddOtherRolesState();
}

class _AddOtherRolesState extends State<AddOtherRoles> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();

  // Form fields
  String _selectedRole = 'doctor';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  DateTime? _selectedDate;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _departmentController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select a date of birth';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_selectedRole == 'doctor' && _departmentController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Department is required for doctors';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get sanitized email to use as document ID
      String docId = _emailController.text.replaceAll(RegExp(r'[.#$[\]]'), '_');

      // Create user in Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text, password: _passwordController.text);

      final User? user = userCredential.user;

      if (user != null) {
        // Add user data based on role
        if (_selectedRole == 'doctor') {
          await addDoctorWithCustomId(
            customId: docId,
            uid: user.uid,
            email: _emailController.text,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            dob: _selectedDate!,
            department: _departmentController.text,
            phoneNumber: _phoneNumberController.text,
            profilepicURL: null,
          );
        } else if (_selectedRole == 'receptionist') {
          // Add receptionist to Firestore
          await _firestore.collection('receptionists').doc(docId).set({
            'uid': user.uid,
            'email': _emailController.text,
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'dob': Timestamp.fromDate(_selectedDate!),
            'phoneNumber': _phoneNumberController.text,
            'profilepicURL': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Add user role to users collection
        await _firestore.collection('users').doc(docId).set({
          'uid': user.uid,
          'email': _emailController.text,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Clear the form
        _formKey.currentState!.reset();
        _selectedDate = null;
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _departmentController.clear();
        _phoneNumberController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${_selectedRole.capitalize()} successfully registered!')),
        );
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
          errorMessage = 'An error occurred: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${_selectedRole.capitalize()}'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role selection
              Text(
                'Select Role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedRole,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
                      items: <String>['doctor', 'receptionist']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value.capitalize()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Personal Information
              Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),

              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Date of Birth
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _selectedDate == null
                          ? ''
                          : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Phone Number
              TextFormField(
                controller: _phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),

              // Department (Only for doctors)
              if (_selectedRole == 'doctor')
                Column(
                  children: [
                    TextFormField(
                      controller: _departmentController,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_selectedRole == 'doctor' &&
                            (value == null || value.isEmpty)) {
                          return 'Please enter department';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                  ],
                ),

              // Account Information
              Text(
                'Account Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.red[100],
                  width: double.infinity,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              SizedBox(height: 12),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Register ${_selectedRole.capitalize()}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
