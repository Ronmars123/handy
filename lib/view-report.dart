import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewReportsPage extends StatelessWidget {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  ViewReportsPage({super.key});

  /// Fetches all reports from Firebase.
  Future<List<Map<String, dynamic>>> _fetchReports() async {
    try {
      final snapshot = await _dbRef.child('reports').get();
      if (snapshot.exists) {
        final reports = (snapshot.value as Map)
            .values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return reports;
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
    return [];
  }

  /// Fetches user details (first and last name) based on the user ID.
  Future<Map<String, String>> _fetchUserDetails(String userId) async {
    try {
      final snapshot = await _dbRef.child('userprofiles/$userId').get();
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          'firstName': userData['firstName'] ?? 'Unknown',
          'lastName': userData['lastName'] ?? 'User',
        };
      }
    } catch (e) {
      print('Error fetching user details for $userId: $e');
    }
    return {'firstName': 'Unknown', 'lastName': 'User'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'View All Reports',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'No reports available.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Group reports by category (Scam, Harassment, Hate Speech, Uncategorized)
          final Map<String, List<Map<String, dynamic>>> categorizedReports = {};
          for (var report in reports) {
            final category = report['reportType'] ?? 'Uncategorized';
            if (!categorizedReports.containsKey(category)) {
              categorizedReports[category] = [];
            }
            categorizedReports[category]!.add(report);
          }

          return ListView(
            children: categorizedReports.entries.map((entry) {
              final category = entry.key;
              final categoryReports = entry.value;

              return ExpansionTile(
                title: Row(
                  children: [
                    Icon(
                      _getIconForCategory(category), // Use helper function to determine icon
                      color: _getIconColorForCategory(category), // Icon color
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                children: categoryReports.map((report) {
                  final reportedBy = report['reportedBy'] ?? 'Unknown';

                  return FutureBuilder<Map<String, String>>(
                    future: _fetchUserDetails(reportedBy),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final userDetails = userSnapshot.data ?? {
                        'firstName': 'Unknown',
                        'lastName': 'User',
                      };

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Provider: ${report['providerName'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reported By: ${userDetails['firstName']} ${userDetails['lastName']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Description: ${report['description'] ?? 'No description provided.'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Timestamp: ${report['timestamp'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Handle report resolution (e.g., mark as resolved)
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Resolve'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // Handle report dismissal (e.g., ignore)
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    icon: const Icon(Icons.delete),
                                    label: const Text(
                                      'Dismiss',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  /// Helper function to get the icon for a category
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Scam':
        return Icons.warning;
      case 'Harassment':
        return Icons.report_problem;
      case 'Hate Speech':
        return Icons.speaker_notes_off;
      default:
        return Icons.info;
    }
  }

  /// Helper function to get the color for a category's icon
  Color _getIconColorForCategory(String category) {
    switch (category) {
      case 'Scam':
        return Colors.redAccent;
      case 'Harassment':
        return Colors.orangeAccent;
      case 'Hate Speech':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }
}
