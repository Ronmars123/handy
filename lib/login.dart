import 'user_homepage.dart';
import 'provider_homepage.dart';
import 'package:flutter/material.dart';
import 'package:handycrew/edit_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_homepage.dart'; // Import AdminHomePage
import 'package:firebase_database/firebase_database.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  // Boolean to toggle password visibility
  bool _showPassword = false; 
  DateTime? lastResendTime;

 Future<void> _login() async {
  // Validate email and password fields
  if (_emailController.text.trim().isEmpty ||
      _passwordController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your email and password.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Log in the user
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    // Get the current user after login
    final user = userCredential.user;

    if (user == null) {
      throw Exception('Failed to retrieve the user.');
    }

    // Check if email is verified
    if (!user.emailVerified) {
      // Email is not verified, show the verification dialog
      _showEmailVerificationDialog(user);
      return;
    }

    // If email is verified, fetch user details from Realtime Database
    final userUid = user.uid;

    DatabaseReference userRef =
        FirebaseDatabase.instance.ref('userprofiles/$userUid');
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      final userType = data?['userType'] ?? 'Unknown';
      final isDisabled = data?['disable'] ?? false;
      final isProfileSetup = data?['profile_setup'] ?? false;

      if (isDisabled) {
        // User is banned
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been banned.'),
            backgroundColor: Colors.red,
          ),
        );

        await _auth.signOut(); // Log out the banned user
        return;
      }

      // Check if profile_setup is false and navigate to EditProfilePage
      if (!isProfileSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfilePage(user: user),
          ),
        );
        return; // Exit the function to avoid navigating to other pages
      }

      // Navigate based on userType
      switch (userType) {
        case 'User':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserHomePage()),
          );
          break;
        case 'Provider':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProviderHomePage()),
          );
          break;
        case 'Admin':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminHomePage()),
          );
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported user type: $userType')),
          );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data not found in the database.')),
      );
    }
  } on FirebaseAuthException catch (e) {
    // Handle specific login errors
    if (e.code == 'user-not-found') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user found for this email address.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (e.code == 'wrong-password') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (e.code == 'invalid-email') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The email address is invalid.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // General error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Login failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}



void _resendVerificationEmail(User user) async {
  final now = DateTime.now();

  // Check if the user is requesting too soon
  if (lastResendTime != null &&
      now.difference(lastResendTime!).inSeconds < 60) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please wait before requesting another verification email.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  try {
    await user.sendEmailVerification();
    lastResendTime = now; // Update last resend time
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A new verification email has been sent. Please check your inbox.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to send verification email. Please try again later. Error: ${e.toString()}',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showEmailVerificationDialog(User user) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      title: const Row(
        children: [
          Icon(Icons.email_outlined, color: Colors.blueAccent, size: 28),
          SizedBox(width: 8),
          Text(
            'Email Not Verified',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your email address is not verified. Please check your inbox and verify your email to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                'Check your inbox',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center, // Center actions
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Align buttons horizontally
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await user.sendEmailVerification(); // Send verification email
                  Navigator.pop(context); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A new verification email has been sent. Please check your inbox.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to send verification email. Please try again later.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Resend Email',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12), // Smaller space between buttons
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14, // Smaller font size
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Unified white container for logo and login form
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          // Enlarged logo inside the card
                          Image.asset(
                            'img/logosss.png',
                            height: 160, // Increased height
                            width: 160, // Increased width
                          ),
                          const SizedBox(
                              height: 24), // Spacing between logo and inputs
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword, // Toggle password visibility
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword; // Toggle the visibility
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 80, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color.fromARGB(
                                        255, 10, 161, 255), // Blue button color
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white), // White text
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      'Don’t have an account? Register',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
