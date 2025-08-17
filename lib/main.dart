import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // --- NEW: Import Firestore ---
import 'package:google_fonts/google_fonts.dart';
import 'package:playgroup_pals/screens/auth_wrapper.dart';
import 'package:playgroup_pals/firebase_options.dart';

// The main function is the entry point of every Flutter app.
void main() async {
  // Ensures that Flutter is ready before we run the app.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use the default options from the generated firebase_options.dart file.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // --- NEW: Disable Firestore persistence to fix sync issue ---
  // This forces the app to always get the latest data from the server.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  // Runs the main app widget.
  runApp(const PlaygroupPalsApp());
}

// This is the root widget of your application.
class PlaygroupPalsApp extends StatelessWidget {
  const PlaygroupPalsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A84FF);
    const secondaryColor = Color(0xFFFF9F0A);
    const backgroundColor = Color(0xFFF2F2F7);
    const surfaceColor = Colors.white;
    const primaryTextColor = Color(0xFF1D1D1F);
    const secondaryTextColor = Color(0xFF8A8A8E);

    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
      bodyColor: primaryTextColor,
      displayColor: primaryTextColor,
    );

    return MaterialApp(
      title: 'Playgroup Pals',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
          error: Colors.redAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: primaryTextColor,
          onError: Colors.white,
        ),

        textTheme: textTheme,

        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: primaryTextColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),

        cardTheme: CardThemeData(
          elevation: 0.5,
          color: surfaceColor,
          shadowColor: Colors.black.withAlpha(13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: secondaryTextColor.withAlpha(178)),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            side: BorderSide(color: primaryColor.withAlpha(77)),
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1.0,
          highlightElevation: 2.0,
        ),

        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      
      home: const AuthWrapper(),
    );
  }
}
