import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:handycrew/provider_homepage.dart';
import 'package:handycrew/register.dart';
import 'User_homepage.dart';
import 'edit_profile.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), // Start with the AuthWrapper widget
      routes: {
        '/register': (context) => RegisterPage(),
        '/edit_profile': (context) => EditProfilePage(),
        '/user_homepage': (context) => UserHomePage(),
        '/provider_homepage': (context) => ProviderHomePage(),
      },
    );
  }
}

/// A widget to determine the initial screen based on user authentication
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Check the current user from Firebase Auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If no user is logged in, show the LoginPage
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          // User is logged in
          final user = snapshot.data!;
          // Route to the appropriate homepage based on user type
          if (user.displayName == 'Provider') {
            return const ProviderHomePage();
          } else {
            return  UserHomePage();
          }
        } else {
          // User is logged out
          return LoginPage();
        }
      },
    );
  }
}
