import 'package:flutter/material.dart';
import 'package:vitallinkv2/screens/getstarted.dart';
import 'package:vitallinkv2/services/firebase/authentication.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vitallinkv2/screens/forgetpass.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitallinkv2/screens/doctor/doctorhome.dart';
import 'package:vitallinkv2/screens/patients/patienthome.dart';
import 'package:vitallinkv2/screens/receptionist/receptionisthome.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Method for handling regular email/password sign in.
  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = await Authentication().signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (user != null) {
          final firestore = FirebaseFirestore.instance;
          final email = user.email;
          final uid = user.uid;
          // Attempt to find user role based on document IDs.
          final doctorDoc =
              await firestore.collection('doctors').doc(uid).get();
          if (doctorDoc.exists) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DoctorHomePage()),
            );
            return;
          }

          final patientDoc =
              await firestore.collection('patients').doc(uid).get();
          if (patientDoc.exists) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PatientDashboard()),
            );
            return;
          }

          final receptionistDoc =
              await firestore.collection('receptionists').doc(uid).get();
          if (receptionistDoc.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signed in as Receptionist')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ReceptionistHomePage()),
            );
            return;
          }

          // Fallback: try with sanitized email.
          String sanitizedEmail = email!.replaceAll(RegExp(r'[.#$[\]]'), '_');
          final doctorDocEmail =
              await firestore.collection('doctors').doc(sanitizedEmail).get();
          if (doctorDocEmail.exists) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DoctorHomePage()),
            );
            return;
          }
          final patientDocEmail =
              await firestore.collection('patients').doc(sanitizedEmail).get();
          if (patientDocEmail.exists) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PatientDashboard()),
            );
            return;
          }
          final receptionistDocEmail = await firestore
              .collection('receptionists')
              .doc(sanitizedEmail)
              .get();
          if (receptionistDocEmail.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signed in as Receptionist')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ReceptionistHomePage()),
            );
            return;
          }

          // If no role found, show error.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile not found in any role')),
          );
          await Authentication().signOut();
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Method for handling Google sign in.
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await Authentication().signInWithGoogle();
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final email = user.email;
        final uid = user.uid;

        // Check for user role.
        final doctorDoc = await firestore.collection('doctors').doc(uid).get();
        if (doctorDoc.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DoctorHomePage()),
          );
          return;
        }

        final patientDoc =
            await firestore.collection('patients').doc(uid).get();
        if (patientDoc.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PatientDashboard()),
          );
          return;
        }

        final receptionistDoc =
            await firestore.collection('receptionists').doc(uid).get();
        if (receptionistDoc.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReceptionistHomePage()),
          );
          return;
        }

        // Fallback: check with sanitized email.
        String sanitizedEmail = email!.replaceAll(RegExp(r'[.#$[\]]'), '_');

        final doctorDocEmail =
            await firestore.collection('doctors').doc(sanitizedEmail).get();
        if (doctorDocEmail.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DoctorHomePage()),
          );
          return;
        }

        final patientDocEmail =
            await firestore.collection('patients').doc(sanitizedEmail).get();
        if (patientDocEmail.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PatientDashboard()),
          );
          return;
        }

        final receptionistDocEmail = await firestore
            .collection('receptionists')
            .doc(sanitizedEmail)
            .get();
        if (receptionistDocEmail.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReceptionistHomePage()),
          );
          return;
        }

        // If user not found in any collection.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found in any role')),
        );
        await Authentication().signOut();
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Full-screen gradient background.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage()),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Social login section (Google only)
                        Row(
                          children: const [
                            Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('or continue with'),
                            ),
                            Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: const Icon(FontAwesome.google,
                              size: 20, color: Colors.red),
                          label: Text('Google',
                              style: GoogleFonts.poppins(fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(140, 50),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ",
                                style: GoogleFonts.poppins()),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const GetStartedPage()),
                                );
                              },
                              child: Text('Sign Up',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
