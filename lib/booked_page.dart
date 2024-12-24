import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


class BookedPage extends StatefulWidget {
  final String userId;

  const BookedPage({Key? key, required this.userId}) : super(key: key);

  @override
  _BookedPageState createState() => _BookedPageState();
}

class _BookedPageState extends State<BookedPage> {
  late DatabaseReference _userBookingsRef;
  late DatabaseReference _completedJobsRef;
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  StreamSubscription<DatabaseEvent>? _completedJobsSubscription;

  List<Map<String, dynamic>> _bookJobsList = [];
  List<Map<String, dynamic>> _completedJobsList = [];
  List<Map<String, dynamic>> _bookedJobs = []; // Combined list of all jobs
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // References for real-time updates
    _userBookingsRef =
        FirebaseDatabase.instance.ref('userprofiles/${widget.userId}/book_jobs');
    _completedJobsRef =
        FirebaseDatabase.instance.ref('userprofiles/${widget.userId}/job_completed');

    _listenForChanges(); // Start listening to changes in the database
  }

  /// Listen for changes in `book_jobs` and `job_completed`
  void _listenForChanges() {
    // Listen for changes in `book_jobs`
    _bookingsSubscription = _userBookingsRef.onValue.listen((event) {
      final List<Map<String, dynamic>> jobsList = [];

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final jobData = Map<String, dynamic>.from(value);
            jobData['jobId'] = key; // Add jobId explicitly
            jobData['isCompleted'] = false; // Mark as not completed
            jobsList.add(jobData);
          }
        });
      }

      setState(() {
        _bookJobsList = jobsList;
        _updateBookedJobs(); // Merge booked and completed jobs
      });
    });

    // Listen for changes in `job_completed`
    _completedJobsSubscription = _completedJobsRef.onValue.listen((event) {
      final List<Map<String, dynamic>> jobsList = [];

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final jobData = Map<String, dynamic>.from(value);
            jobData['jobId'] = key; // Add jobId explicitly
            jobData['isCompleted'] = true; // Mark as completed
            jobsList.add(jobData);
          }
        });
      }

      setState(() {
        _completedJobsList = jobsList;
        _updateBookedJobs(); // Merge booked and completed jobs
      });
    });
  }

  /// Merge `book_jobs` and `job_completed` into `_bookedJobs`
  void _updateBookedJobs() {
    _bookedJobs = [..._bookJobsList, ..._completedJobsList];
    _isLoading = false; // Mark loading as done
  }

  @override
  void dispose() {
    // Cancel the subscriptions to avoid memory leaks
    _bookingsSubscription?.cancel();
    _completedJobsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _markJobAsCompleted(
      String jobId, String providerId, List<Map<String, dynamic>> jobs, int index) async {
    try {
      final String? loggedInUserId = FirebaseAuth.instance.currentUser?.uid;
      if (loggedInUserId == null) {
        print("No user logged in.");
        return;
      }

      if (jobId.isEmpty || providerId.isEmpty) {
        print("Invalid job ID or provider ID.");
        return;
      }

      final DatabaseReference userJobRef =
          FirebaseDatabase.instance.ref('userprofiles/${widget.userId}/book_jobs/$jobId');
      final DatabaseReference bookedUserJobRef =
          FirebaseDatabase.instance.ref('userprofiles/$providerId/bookedUsers/$jobId');
      final DatabaseReference userCompletedJobRef =
          FirebaseDatabase.instance.ref('userprofiles/${widget.userId}/job_completed/$jobId');
      final DatabaseReference providerCompletedJobRef =
          FirebaseDatabase.instance.ref('userprofiles/$providerId/job_completed/$jobId');

      final Map<String, dynamic> jobDetails = jobs[index];
      final completedJobData = {
        ...jobDetails,
        'status': 'Completed',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await Future.wait([
        userCompletedJobRef.set(completedJobData),
        providerCompletedJobRef.set(completedJobData),
        userJobRef.remove(),
        bookedUserJobRef.remove(),
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job marked as completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookedJobs.isEmpty
              ? const Center(
                  child: Text(
                    'No booked jobs available.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _bookedJobs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final job = _bookedJobs[index];
                    final jobStatus = job['isCompleted'] == true
                        ? 'Completed'
                        : (job['status'] ?? 'Pending');
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
                                const Icon(Icons.schedule, size: 18, color: Colors.blue),
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
                                if (jobStatus == 'Ongoing')
                                  Flexible(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final jobId = job['jobId'] ?? '';
                                        final providerId = job['providerId'] ?? '';
                                        await _markJobAsCompleted(
                                            jobId, providerId, _bookedJobs, index);
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
                                    onPressed: job['isCompleted']
                                        ? () {
                                            _showFeedbackDialog(
                                                context, job['providerId'] ?? '');
                                          }
                                        : null,
                                    icon: const Icon(Icons.rate_review),
                                    label: const Text('Review & Feedback'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: job['isCompleted']
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
                  }),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';

    try {
      final DateTime parsedDate = DateTime.parse(date);
      final String year = parsedDate.year.toString();
      final String month = parsedDate.month.toString().padLeft(2, '0');
      final String day = parsedDate.day.toString().padLeft(2, '0');
      
      // Format hours and minutes for 12-hour clock
      final int hour = parsedDate.hour % 12 == 0 ? 12 : parsedDate.hour % 12;
      final String minute = parsedDate.minute.toString().padLeft(2, '0');
      final String period = parsedDate.hour >= 12 ? 'PM' : 'AM';

      // Return formatted string with date and time
      return '$year-$month-$day $hour:$minute $period'; // e.g., 2024-12-24 03:30 PM
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }
}
