import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 1. Initialize Firebase
    await _initializeFirebase();

    // 2. Initialize Services
    await _initializeAppServices();

    // 3. Initialize Date Formatting
    await initializeDateFormatting('th_TH', null);

    // 4. Initialize Alarm Manager
    await AndroidAlarmManager.initialize();
  } catch (e) {
    debugPrint('Application initialization error: $e');
  }

  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // ส่งต่อ error ถ้า Firebase เป็นส่วนสำคัญของแอป
    rethrow;
  }
}

Future<void> _initializeAppServices() async {
  try {
    // Initialize Notification Service
    final notificationService = NotificationService();
    await notificationService.init();
    debugPrint('Notification service initialized');

    // Request Notification Permissions
    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestNotificationPermission();
    debugPrint('Notification permission granted: $hasPermission');

    // Reload Scheduled Notifications only if permission is granted
    if (hasPermission) {
      await notificationService.reloadScheduledNotifications();
      debugPrint('Scheduled notifications reloaded');
    }
  } catch (e) {
    debugPrint('Service initialization error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Planner',
      theme: _buildAppTheme(context),
      home: _determineInitialPage(),
    );
  }

  ThemeData _buildAppTheme(BuildContext context) {
    return ThemeData(
      primaryColor: const Color.fromARGB(255, 77, 89, 78),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4CAF50),
        secondary: Color(0xFFFF9800),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        Theme.of(context).textTheme,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 188, 249, 190),
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  Widget _determineInitialPage() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null ?  DashboardPage() :  HomePage();
    } catch (e) {
      debugPrint('Error determining initial page: $e');
      return  HomePage(); // Fallback to HomePage on error
    }
  }
}