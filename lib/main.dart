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

  } catch (e) {
    debugPrint('Service initialization error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Planner',
      theme: _buildAppTheme(context),
      navigatorKey: navigatorKey,
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
      // Enhanced AppBar with modern design
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 8,
        shadowColor: Colors.black26,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _determineInitialPage() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null ? DashboardPage() : HomePage();
    } catch (e) {
      debugPrint('Error determining initial page: $e');
      return HomePage(); // Fallback to HomePage on error
    }
  }
}

// Custom AppBar Widget with Logo
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogo;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF66BB6A), // Light green
            Color(0xFF4CAF50), // Primary green
            Color(0xFF388E3C), // Dark green
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: leading,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLogo) ...[
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 12),
                child: Image.asset(
                  'assets/images/notification_icon.png', // คุณจะต้องคัดลอกไฟล์ไปยัง assets/images/
                  width: 32,
                  height: 32,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icon ถ้าโหลดรูปไม่ได้
                    return const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 32,
                    );
                  },
                ),
              ),
            ],
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: actions,
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// วิธีใช้งาน CustomAppBar ในหน้าต่างๆ
// Example usage in your pages:
/*
Scaffold(
  appBar: const CustomAppBar(
    title: 'Food Planner',
    showLogo: true,
  ),
  body: YourPageContent(),
)
*/