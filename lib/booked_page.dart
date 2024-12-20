import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({Key? key, required this.userId}) : super(key: key);

  @override
  _BookedPageState createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  Future<List<Map<String, dynamic>>> _fetchBookedJobs() async {
    final DatabaseReference userBookingsRef = FirebaseDatabase.instance
        .ref('userprofiles/${widget.userId}/book_jobs');

    try {
      final snapshot = await userBookingsRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Extract job data and include 'jobId' from the key
        List<Map<String, dynamic>> jobsList = [];
        data.forEach((key, value) {
          if (value is Map) {
            final jobData = Map<String, dynamic>.from(value);
            jobData['jobId'] = key; // Add jobId explicitly
            jobsList.add(jobData);
          }
        });
        return jobsList;
      }
    } catch (e) {
      print('Error fetching booked jobs: $e');
    }

    return [];
  }

  Future<void> _markJobAsCompleted(String jobId, String providerId,
      List<Map<String, dynamic>> jobs, int index) async {
    try {
      // Get the logged-in user ID
      final String? loggedInUserId = FirebaseAuth.instance.currentUser?.uid;
      if (loggedInUserId == null) {
        print("No user logged in.");
        return;
      }

      if (jobId.isEmpty || providerId.isEmpty) {
        print("Invalid job ID or provider ID.");
        return;
      }

      // Reference to the job node (book_jobs) under the user
      final DatabaseReference userJobRef = FirebaseDatabase.instance
          .ref('userprofiles/${widget.userId}/book_jobs/$jobId');

      // Reference to the job inside bookedUsers under providerId
      final DatabaseReference bookedUserJobRef = FirebaseDatabase.instance
          .ref('userprofiles/$providerId/bookedUsers/${widget.userId}/status');

      // Update the status in both paths
      await Future.wait([
        userJobRef.update({'status': 'Completed'}), // User's booked job
        bookedUserJobRef.set('Completed'), // Provider's bookedUsers status
      ]);

      // Update the local state to reflect the change
      setState(() {
        jobs[index]['status'] = 'Completed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job marked as completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      print('Status updated successfully for user and provider.');
    } catch (e) {
      print('Error marking job as completed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark job as completed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFeedbackDialog(BuildContext context, String providerId) {
    final TextEditingController feedbackController = TextEditingController();
    int rating = 0;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                rating = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: feedbackController,
                        decoration: const InputDecoration(
                          labelText: 'Enter your feedback',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final feedback = feedbackController.text.trim();
                              if (feedback.isEmpty || rating == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please provide feedback and select a rating.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              await _submitFeedback(
                                  providerId, feedback, rating);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Feedback submitted successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitFeedback(
      String providerId, String feedback, int rating) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in.');

      final userRef = FirebaseDatabase.instance.ref('userprofiles/$userId');
      final snapshot = await userRef.get();

      if (!snapshot.exists) throw Exception('User profile not found.');

      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final firstName = userData['firstName'] ?? 'Unknown';
      final lastName = userData['lastName'] ?? 'User';
      final fullName = '$firstName $lastName'.trim();

      final feedbackData = {
        'feedback': feedback,
        'rating': rating,
        'fullName': fullName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final feedbackRef = FirebaseDatabase.instance
          .ref('userprofiles/$providerId/feedbacks')
          .push();
      await feedbackRef.set(feedbackData);
    } catch (e) {
      print('Error submitting feedback: $e');
      throw Exception('Failed to submit feedback. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchBookedJobs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load booked jobs.'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No booked jobs available.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          } else {
            final bookedJobs = snapshot.data!;
            return ListView.builder(
              itemCount: bookedJobs.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final job = bookedJobs[index];
                final jobStatus = job['status'] ?? 'Pending';
                final statusColor = jobStatus == 'Completed'
                    ? Colors.green
                    : jobStatus == 'Ongoing'
                        ? Colors.orange
                        : Colors.redAccent;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
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
                                job['jobTitle'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                jobStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.description,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job['about'] ?? 'No Description Available',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Scheduled: ${_formatDate(job['selected_schedule'])}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final jobId =
                                      job['jobId'] ?? ''; // Get the jobId
                                  final providerId = job['providerId'] ?? '';
                                  await _markJobAsCompleted(
                                      jobId, providerId, bookedJobs, index);
                                },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Mark Completed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: (jobStatus == 'Ongoing' ||
                                        jobStatus == 'Completed')
                                    ? () {
                                        _showFeedbackDialog(
                                            context, job['providerId'] ?? '');
                                      }
                                    : null,
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Review & Feedback'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (jobStatus == 'Ongoing' ||
                                          jobStatus == 'Completed')
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
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
          }
        },
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';

    try {
      final DateTime parsedDate = DateTime.parse(date);
      final String year = parsedDate.year.toString();
      final String month = parsedDate.month.toString().padLeft(2, '0');
      final String day = parsedDate.day.toString().padLeft(2, '0');

      return '$year-$month-$day';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }
}
