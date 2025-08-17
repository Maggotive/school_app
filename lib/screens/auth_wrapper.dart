import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:playgroup_pals/screens/auth_screen.dart';
import 'package:playgroup_pals/screens/dashboard_screen.dart';

// This widget's only job is to check if the user is logged in or not.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // It listens to changes in the user's login state from Firebase.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While it's checking, show a loading spinner.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If the user is logged in (snapshot has data), show the main app dashboard.
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        // If the user is not logged in, show the login/signup screen.
        return const AuthScreen();
      },
    );
  }
}
