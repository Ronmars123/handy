import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:handycrew/manage_provider.dart';
import 'package:handycrew/view-report.dart';

import 'login.dart';
import 'manage_user.dart';

class AdminHomePage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AdminHomePage({super.key});

  void _logout(BuildContext context) async {
    await _auth.signOut(); // Sign out from Firebase Auth
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Align(
          alignment: Alignment.centerLeft, // Align title to the left
          child: Text(
            'Admin Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Color.fromARGB(255, 255, 255, 255), // Black text color for the title
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 132, 209), // White app bar background
        elevation: 0, // Remove shadow for a clean look
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 255, 255, 255)), // Black logout icon
            tooltip: 'Logout',
            onPressed: () => _logout(context), // Logout functionality
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Welcome Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 100,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome, Admin!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage users, providers, and oversee all operations of the application.',
                      textAlign: TextAlign.left, // Align text to the left
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.group, color: Colors.white),
                        ),
                        title: const Text(
                          'Manage Users',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'View, edit, or delete user accounts.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ManageUserPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.greenAccent,
                          child: Icon(Icons.business, color: Colors.white),
                        ),
                        title: const Text(
                          'Manage Providers',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Approve, block, or manage service providers.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.greenAccent),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ManageProvidersPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Icon(Icons.report, color: Colors.white),
                        ),
                        title: const Text(
                          'View All Reports',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Review complaints and reports.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.redAccent),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ViewReportsPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
