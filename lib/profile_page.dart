import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final VoidCallback onLogout;

  const ProfilePage({
    Key? key,
    required this.userProfile,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactNumberController;
  late TextEditingController _addressController;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final _firebaseStorage = FirebaseStorage.instance;
  final _firebaseAuth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref('userprofiles');

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.userProfile['firstName'] ?? '');
    _lastNameController =
        TextEditingController(text: widget.userProfile['lastName'] ?? '');
    _emailController =
        TextEditingController(text: widget.userProfile['email'] ?? '');
    _contactNumberController =
        TextEditingController(text: widget.userProfile['contactNumber'] ?? '');
    _addressController =
        TextEditingController(text: widget.userProfile['address'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final XFile? pickedImage =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef =
          _firebaseStorage.ref().child('profile_images/${user.uid}.jpg');
      await storageRef.putFile(File(pickedImage.path));
      final imageUrl = await storageRef.getDownloadURL();
      await _dbRef.child(user.uid).update({'profileImageUrl': imageUrl});

      setState(() {
        _profileImage = File(pickedImage.path);
        widget.userProfile['profileImageUrl'] = imageUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully!')),
      );
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload profile picture.')),
      );
    }
  }

  Future<void> _viewFeedbacks() async {
      final user = _firebaseAuth.currentUser; // Get current user
      if (user == null) return; // Exit if no user is logged in

      final feedbackRef = _dbRef.child(user.uid).child('feedbacks');
      final snapshot = await feedbackRef.get();

      if (!snapshot.exists) {
        // Show dialog when no feedbacks exist
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('No Feedback'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: const Text(
                'No feedback available for your account yet.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Close the dialog
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      // Parse feedbacks into a list
      final feedbacks = (snapshot.value as Map).values.map((feedback) {
        final data = feedback as Map<dynamic, dynamic>;
        return {
          'feedback': data['feedback'] ?? 'No feedback',
          'fullName': data['fullName'] ?? 'Anonymous',
          'rating': data['rating'] ?? 0,
          'timestamp': data['timestamp'] ?? 'N/A',
        };
      }).toList();

      // Display the feedbacks in a dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Feedbacks'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: feedbacks.length,
                itemBuilder: (context, index) {
                  final feedback = feedbacks[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          feedback['rating'].toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(feedback['fullName']),
                      subtitle: Text(
                          'Feedback: ${feedback['feedback']}\nTimestamp: ${feedback['timestamp']}'),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

  void _showEditForm() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _contactNumberController,
                  decoration:
                      const InputDecoration(labelText: 'Contact Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveProfileUpdates();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfileUpdates() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final updatedProfile = {
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'email': _emailController.text,
      'contactNumber': _contactNumberController.text,
      'address': _addressController.text,
    };

    try {
      await _dbRef.child(user.uid).update(updatedProfile);

      setState(() {
        widget.userProfile.addAll(updatedProfile);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  void _viewReports() async {
  final user = _firebaseAuth.currentUser; // Get current user
  if (user == null) return; // Exit if no user is logged in

  final reportsRef = FirebaseDatabase.instance.ref('reports');
  final snapshot = await reportsRef.get();

  if (!snapshot.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No reports available.')),
    );
    return;
  }

  // Filter reports by providerId matching the current user's uid
  final reports = (snapshot.value as Map).entries.where((entry) {
    final data = entry.value as Map<dynamic, dynamic>;
    return data['providerId'] == user.uid; // Match providerId with user.uid
  }).map((filteredEntry) {
    final data = filteredEntry.value as Map<dynamic, dynamic>;
    return {
      'description': data['description'],
      'reportType': data['reportType'],
      'providerName': data['providerName'],
      'timestamp': data['timestamp'],
    };
  }).toList();

  if (reports.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No reports available for your account.')),
    );
    return;
  }

  // Display the filtered reports in a dialog
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('My Reports'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                title: Text('Type: ${report['reportType']}'),
                subtitle: Text(
                    'Provider: ${report['providerName']}\nDescription: ${report['description']}\nTimestamp: ${report['timestamp']}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}


  @override
    Widget build(BuildContext context) {
    final coordinates = widget.userProfile['coordinates'] as Map?;
    final latitude = coordinates?['latitude'] ?? 'Not provided';
    final longitude = coordinates?['longitude'] ?? 'Not provided';
    final profileImageUrl = widget.userProfile['profileImageUrl'];
    final userType = widget.userProfile['userType']; // Check userType
    final subscription = widget.userProfile['subscription'] as Map?;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blueAccent,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider<Object>
                          : profileImageUrl != null
                              ? NetworkImage(profileImageUrl)
                                  as ImageProvider<Object>
                              : const AssetImage('assets/default_profile.png'),
                      child: _profileImage == null && profileImageUrl == null
                          ? const Icon(Icons.camera_alt,
                              size: 30, color: Colors.white)
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'My Profile',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blueAccent),
              title: const Text('Name'),
              subtitle: Text(
                  '${widget.userProfile['firstName'] ?? 'N/A'} ${widget.userProfile['lastName'] ?? 'N/A'}'),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blueAccent),
              title: const Text('Email'),
              subtitle: Text('${widget.userProfile['email'] ?? 'N/A'}'),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blueAccent),
              title: const Text('Contact Number'),
              subtitle: Text('${widget.userProfile['contactNumber'] ?? 'N/A'}'),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.blueAccent),
              title: const Text('Address'),
              subtitle: Text('${widget.userProfile['address'] ?? 'N/A'}'),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blueAccent),
              title: const Text('Coordinates'),
              subtitle: Text('Latitude: $latitude\nLongitude: $longitude'),
            ),
            // Display Subscription if userType is Provider
            if (userType == 'Provider') ...[
              const Divider(),
              const Text(
                'Subscription Details',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent),
              ),
              if (subscription != null) ...[
                ListTile(
                  leading: const Icon(Icons.calendar_today,
                      color: Colors.blueAccent),
                  title: const Text('Plan'),
                  subtitle: Text('${subscription['plan'] ?? 'N/A'}'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.access_time, color: Colors.blueAccent),
                  title: const Text('Start Date'),
                  subtitle: Text('${subscription['start'] ?? 'N/A'}'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.access_time, color: Colors.blueAccent),
                  title: const Text('End Date'),
                  subtitle: Text('${subscription['end'] ?? 'N/A'}'),
                ),
              ] else ...[
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blueAccent),
                  title: Text('Subscription'),
                  subtitle: Text('Not Subscribed Yet'),
                ),
              ],
              const Divider(),

              // Row for View Feedbacks and View Reports Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _viewFeedbacks, // Call the view feedbacks function
                    icon: const Icon(
                      Icons.feedback,
                      size: 18, // Smaller icon size
                    ),
                    label: const Text(
                      'Feedbacks',
                      style: TextStyle(fontSize: 14), // Smaller font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, // Reduced horizontal padding
                        vertical: 8, // Reduced vertical padding
                      ),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36), // Minimum button size
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _viewReports, // Call the view reports function
                    icon: const Icon(
                      Icons.report,
                      size: 18, // Smaller icon size
                    ),
                    label: const Text(
                      'Reports',
                      style: TextStyle(fontSize: 14), // Smaller font size
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, // Reduced horizontal padding
                        vertical: 8, // Reduced vertical padding
                      ),
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 36), // Minimum button size
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showEditForm,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
