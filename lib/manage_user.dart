import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  _ManageUserPageState createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final DatabaseReference _userRef =
      FirebaseDatabase.instance.ref('userprofiles');
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final snapshot = await _userRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      setState(() {
        _users = data.entries
            .map((entry) {
              final value = Map<String, dynamic>.from(entry.value);
              return {'key': entry.key, ...value};
            })
            .where((user) => user['userType'] == 'User') // Filter by userType
            .toList();

        _totalUsers = _users.length; // Update the total user count
      });
    }
  }

  Future<void> _updateUserStatus(String userKey, bool isDisabled) async {
    try {
      await _userRef.child(userKey).update({'disable': isDisabled});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisabled
                ? 'User has been disabled successfully.'
                : 'User has been activated successfully.',
          ),
          backgroundColor: isDisabled ? Colors.red : Colors.green,
        ),
      );

      // Refresh user list
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: const Text(
        'Manage Users',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 255, 255, 255), // White text color
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.blueAccent, // Blue background color
      iconTheme: const IconThemeData(
        color: Colors.white, // Back icon color set to white
      ),
    ),
      body: SafeArea(
        child: Column(
          children: [
            // Total Users Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.group,
                    size: 28,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Total Users: $_totalUsers',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // User List Section
            Expanded(
              child: _users.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final bool isDisabled = user['disable'] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // User Icon
                                const CircleAvatar(
                                  backgroundColor: Colors.blueAccent,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),

                                // User Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${user['firstName']} ${user['lastName']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Email: ${user['email']}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text(
                                            'Status: ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              isDisabled
                                                  ? 'Disabled'
                                                  : 'Active',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor: isDisabled
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Action Buttons
                                PopupMenuButton<String>(
                                  onSelected: (String value) {
                                    if (value == 'Disable') {
                                      _updateUserStatus(user['key'], true);
                                    } else if (value == 'Activate') {
                                      _updateUserStatus(user['key'], false);
                                    }
                                  },
                                  itemBuilder: (context) {
                                    return isDisabled
                                        ? [
                                            const PopupMenuItem(
                                              value: 'Activate',
                                              child: Text('Activate'),
                                            ),
                                          ]
                                        : [
                                            const PopupMenuItem(
                                              value: 'Disable',
                                              child: Text('Disable'),
                                            ),
                                          ];
                                  },
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
