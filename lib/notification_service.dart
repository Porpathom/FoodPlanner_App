// lib/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'meal_notification_dialog.dart';

// เพิ่ม pragma annotation สำหรับ class
@pragma('vm:entry-point')
// เพิ่มคลาสใหม่
class NotificationEvent {
  final String type;
  final String mealType;
  final DateTime timestamp; // เพิ่ม timestamp
  final String eventId; // เพิ่ม unique event ID

  NotificationEvent(this.type, this.mealType, {DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now(),
        eventId = '${type}_${mealType}_${(timestamp ?? DateTime.now()).millisecondsSinceEpoch}';
}

// ใน class NotificationService
final StreamController<NotificationEvent> _notificationController = 
  StreamController<NotificationEvent>.broadcast();

Stream<NotificationEvent> get notificationStream => _notificationController.stream;


class NotificationService {
  bool _isTimezoneInitialized = false;
  bool _notificationsEnabled = false;
  
  // เพิ่ม Set เพื่อติดตาม completed meals วันนี้
  Set<String> _todayCompletedMeals = {};
  String? _lastCompletedDate;
  
  // เพิ่ม Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
 // เพิ่ม StreamController
  final StreamController<NotificationEvent> _notificationController = 
    StreamController<NotificationEvent>.broadcast();

  Stream<NotificationEvent> get notificationStream => _notificationController.stream;

  // Singleton pattern
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  

  // ปรับปรุงการขอสิทธิ์แจ้งเตือน - เพิ่มการขอสิทธิ์หลายแบบ
  Future<bool> checkAndRequestNotificationPermission() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        // ขอสิทธิ์หลายแบบสำหรับ Android
        Map<Permission, PermissionStatus> statuses = await [
          Permission.notification,
          Permission.scheduleExactAlarm,
          Permission.systemAlertWindow,
          Permission.ignoreBatteryOptimizations,
        ].request();

        bool hasNotificationPermission =
            statuses[Permission.notification]?.isGranted ?? false;
        bool hasAlarmPermission =
            statuses[Permission.scheduleExactAlarm]?.isGranted ?? false;
        bool hasOverlayPermission =
            statuses[Permission.systemAlertWindow]?.isGranted ?? false;

        debugPrint('Notification permission: $hasNotificationPermission');
        debugPrint('Exact alarm permission: $hasAlarmPermission');
        debugPrint('System overlay permission: $hasOverlayPermission');

        // ขอ permission จาก plugin โดยตรง
        final plugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (plugin != null) {
          final bool? requestResult =
              await plugin.requestNotificationsPermission();
          final bool? exactAlarmResult =
              await plugin.requestExactAlarmsPermission();
          debugPrint('Plugin permission request result: $requestResult');
          debugPrint('Exact alarm permission result: $exactAlarmResult');
          hasNotificationPermission =
              requestResult ?? hasNotificationPermission;
        }

        return hasNotificationPermission;
      } else if (Platform.isIOS) {
        final bool? result = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            );
        return result ?? false;
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
    }
    return false;
  }

  Future<void> init() async {
    try {
      // ตรวจสอบว่า Firebase ถูก initialize แล้วหรือยัง
      try {
        await Firebase.initializeApp();
        debugPrint('Firebase initialized in NotificationService');
      } catch (e) {
        debugPrint('Firebase already initialized: $e');
        debugPrint('Error initializing NotificationService: $e');

      }

      // Initialize AndroidAlarmManager first
      if (Platform.isAndroid) {
        await AndroidAlarmManager.initialize();
        debugPrint('AndroidAlarmManager initialized');
      }

      if (!_isTimezoneInitialized) {
        tz_data.initializeTimeZones();

        try {
          final bangkok = tz.getLocation('Asia/Bangkok');
          tz.setLocalLocation(bangkok);
          _isTimezoneInitialized = true;
          debugPrint('Timezone initialized to Asia/Bangkok');
        } catch (e) {
          debugPrint('Error setting timezone: $e');
          tz.setLocalLocation(tz.UTC);
          _isTimezoneInitialized = true;
          debugPrint('Timezone initialized to UTC');
        }
        
      }
      

      // สร้าง fullscreen alarm channel เท่านั้น
      AndroidNotificationChannel fullscreenChannel =
          const AndroidNotificationChannel(
        'fullscreen_alarm_channel',
        'Fullscreen Meal Alarms',
        description: 'Fullscreen alarm notifications for meal times',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
        ledColor: Colors.red,
        sound: RawResourceAndroidNotificationSound('alarm_sound'),
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(fullscreenChannel);
          
      // ขอสิทธิ์แจ้งเตือน - ทำหลังจาก initialize
      _notificationsEnabled = await checkAndRequestNotificationPermission();
      debugPrint('Notifications enabled: $_notificationsEnabled');

      // ถ้ายังไม่ได้สิทธิ์ ลองขออีกครั้ง
      if (!_notificationsEnabled) {
        debugPrint('Requesting permissions again...');
        await Future.delayed(Duration(milliseconds: 500));
        _notificationsEnabled = await checkAndRequestNotificationPermission();
        debugPrint('Notifications enabled after retry: $_notificationsEnabled');
      }

      // โหลดข้อมูล completed meals วันนี้
      await _loadTodayCompletedMeals();
      
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      // อย่า rethrow เพื่อให้แอปทำงานต่อได้
    }
    
  }

  // เพิ่มฟังก์ชันโหลดข้อมูล completed meals วันนี้
  Future<void> _loadTodayCompletedMeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // ถ้าเป็นวันใหม่ ให้ล้างข้อมูลเก่า
      if (_lastCompletedDate != today) {
        _todayCompletedMeals.clear();
        _lastCompletedDate = today;
      }
      
      // โหลดข้อมูลจาก SharedPreferences
      final List<String> completedMeals = prefs.getStringList('completed_meals_$today') ?? [];
      _todayCompletedMeals = completedMeals.toSet();
      
      debugPrint('Loaded today completed meals: $_todayCompletedMeals');
    } catch (e) {
      debugPrint('Error loading today completed meals: $e');
    }
  }

  // เพิ่มฟังก์ชันบันทึกข้อมูล completed meals
  Future<void> _saveTodayCompletedMeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      await prefs.setStringList('completed_meals_$today', _todayCompletedMeals.toList());
      debugPrint('Saved today completed meals: $_todayCompletedMeals');
    } catch (e) {
      debugPrint('Error saving today completed meals: $e');
    }
  }

  // เพิ่มฟังก์ชันจัดการการตอบสนองการแจ้งเตือน
Future<void> _scheduleAlarmNotification({
  required int id,
  required String title,
  required String body,
  required String time,
  required String payload,
  bool isMedication = false, // เพิ่มพารามิเตอร์สำหรับยา
}) async {
  try {
    final timeFormat = DateFormat('hh:mm a');
    final parsedTime = timeFormat.parse(time);

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzLocation = tz.local;
    final scheduledTZDateTime = tz.TZDateTime.from(scheduledDate, tzLocation);

    // เลือก notification details ตามประเภท
    final notificationDetails = isMedication 
      ? NotificationDetails(android: _createMedicationNotificationDetails())
      : NotificationDetails(android: _createMealNotificationDetails());

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id + 1000,
      title,
      body,
      scheduledTZDateTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    debugPrint('✅ ${isMedication ? "Medication" : "Meal"} alarm scheduled for $time with ID $id');
  } catch (e) {
    debugPrint('❌ Error scheduling alarm: $e');
  }
}

NotificationDetails _createAlarmNotificationDetails() {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'fullscreen_alarm_channel',
      'Fullscreen Alarm',
      channelDescription: 'Alarm notifications for meals and medications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      color: Colors.red,
      colorized: true,
      icon: 'notification_icon',
      largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
      styleInformation: BigTextStyleInformation(
        'กรุณาปัดหรือกดเพื่อปิดการแจ้งเตือน',
        htmlFormatBigText: false,
        contentTitle: '⏰ แจ้งเตือน',
        htmlFormatContentTitle: false,
      ),
      // เพิ่ม Action Buttons
      actions: [
        const AndroidNotificationAction(
          'eat_now',
          '🍽️ ทานอาหาร',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'dismiss',
          '❌ ปิด',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
  );
}

  // สร้างฟังก์ชันแยกสำหรับแจ้งเตือนยา
  AndroidNotificationDetails _createMedicationNotificationDetails() {
    return const AndroidNotificationDetails(
      'medication_channel',
      'Medication Notifications',
      channelDescription: 'แจ้งเตือนสำหรับยา',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      enableLights: true,
      color: Color(0xFF9C27B0), // สีม่วงสำหรับยา
      icon: 'notification_icon',
      actions: [
        AndroidNotificationAction(
          'eat_now',
          '💊 ทานยา',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'dismiss',
          '❌ ปิด',
          showsUserInterface: false,
          cancelNotification: true, // ปิดแจ้งเตือนนั้นทิ้ง
        ),
      ],
    );
  }

  // สร้างฟังก์ชันแยกสำหรับแจ้งเตือนอาหาร
  AndroidNotificationDetails _createMealNotificationDetails() {
    return const AndroidNotificationDetails(
      'meal_channel',
      'Meal Notifications',
      channelDescription: 'แจ้งเตือนสำหรับอาหาร',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      enableLights: true,
      color: Color(0xFF4CAF50), // สีเขียวสำหรับอาหาร
      icon: 'notification_icon',
      actions: [
        AndroidNotificationAction(
          'eat_now',
          '🍽️ ทานอาหาร',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'dismiss',
          '❌ ปิด',
          showsUserInterface: false,
          cancelNotification: true, // ปิดแจ้งเตือนนั้นทิ้ง
        ),
      ],
    );
  }


  // เพิ่มฟังก์ชันเช็คว่ามื้อไหนทานแล้วจาก notification หรือไม่
  bool wasMealCompletedByNotification(String mealType) {
    return _todayCompletedMeals.contains(mealType);
  }

  // เพิ่มฟังก์ชันล้างข้อมูลการทานของมื้อใดมื้อหนึ่ง
  Future<void> clearMealCompletion(String mealType) async {
    try {
      _todayCompletedMeals.remove(mealType);
      await _saveTodayCompletedMeals();
      debugPrint('✅ Cleared meal completion for: $mealType');
    } catch (e) {
      debugPrint('❌ Error clearing meal completion: $e');
    }
  }

  // ปรับปรุงการตั้งค่า Fullscreen Alarm ใหม่
  Future<void> scheduleFullscreenAlarm({
    required int id,
    required String title,
    required String body,
    required String time,
    bool isMedication = false, // เพิ่มพารามิเตอร์สำหรับยา
  }) async {
    try {
      final timeFormat = DateFormat('hh:mm a');
      final parsedTime = timeFormat.parse(time);

      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzLocation = tz.local;
      final scheduledTZDateTime = tz.TZDateTime.from(scheduledDate, tzLocation);

      // เลือก notification details ตามประเภท
      final notificationDetails = isMedication 
        ? NotificationDetails(android: _createMedicationNotificationDetails())
        : NotificationDetails(android: _createMealNotificationDetails());

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 1000,
        title,
        body,
        scheduledTZDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('✅ ${isMedication ? "Medication" : "Meal"} fullscreen alarm scheduled for $time');
    } catch (e) {
      debugPrint('❌ Error scheduling fullscreen alarm: $e');
    }
  }

  // แสดงการแจ้งเตือนแบบปลุกทันที (สำหรับทดสอบ)
  Future<void> showAlarmNotificationNow({
    required String title,
    required String body,
  }) async {
    try {
      await _showFullscreenAlarmNotification(
        id: 9999,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('❌ Error showing immediate alarm: $e');
    }
  }

  // แสดงการแจ้งเตือนแบบ Fullscreen Alarm
  Future<void> _showFullscreenAlarmNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final AndroidNotificationDetails fullscreenDetails = AndroidNotificationDetails(
        'fullscreen_alarm_channel',
        'Fullscreen Meal Alarms',
        channelDescription: 'Fullscreen alarm notifications for meal times',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm_sound'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        usesChronometer: false,
        chronometerCountDown: false,
        channelShowBadge: true,
        onlyAlertOnce: false,
        autoCancel: true,
        ongoing: false,
        silent: false,
        color: Colors.red,
        colorized: true,
        icon: 'notification_icon',
        largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
        ticker: '🚨 $title - $body',
        timeoutAfter: 300000,
        styleInformation: BigTextStyleInformation(
          '$body\n\n⏰ กรุณากดเพื่อปิดการแจ้งเตือน',
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: 'เตือนทานอาหาร',
          htmlFormatSummaryText: false,
        ),
      );

      final NotificationDetails fullscreenPlatformChannelSpecifics =
          NotificationDetails(android: fullscreenDetails);

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        fullscreenPlatformChannelSpecifics,
        payload: 'meal_${id % 3 + 1}',
      );

      debugPrint('✅ Fullscreen alarm notification shown with ID: $id');
    } catch (e) {
      debugPrint('❌ Error showing fullscreen alarm: $e');
    }
  }

  // ฟังก์ชันหลักสำหรับตั้งค่าการแจ้งเตือนทั้งหมด (เฉพาะปลุกเท่านั้น)
Future<void> scheduleAllMealNotifications({
  required String breakfastTime,
  required String lunchTime,
  required String dinnerTime,
  required Map<String, dynamic> medicationData,
}) async {
  try {
    await cancelAllNotifications();

    final now = DateTime.now();
    final timeFormat = DateFormat('hh:mm a');

    // สร้าง list ของมื้ออาหาร
    final meals = [
      {'id': 1, 'time': breakfastTime, 'name': 'มื้อเช้า'},
      {'id': 2, 'time': lunchTime, 'name': 'มื้อเที่ยง'},
      {'id': 3, 'time': dinnerTime, 'name': 'มื้อเย็น'},
    ];

    for (var meal in meals) {
      if (meal['time'] != null && (meal['time'] as String).isNotEmpty) {
        final mealDateTime = timeFormat.parse(meal['time'] as String);
        final mealToday = DateTime(now.year, now.month, now.day, mealDateTime.hour, mealDateTime.minute);
        if (mealToday.isAfter(now)) {
          // นัดหมายแจ้งเตือนเฉพาะมื้อนี้ แล้วหยุด
          await _scheduleMealWithMedication(
            mealId: meal['id'] as int,
            mealTime: meal['time'] as String,
            mealName: meal['name'] as String,
            medicationData: medicationData,
          );
          break; // นัดหมายแค่มื้อแรกที่ยังไม่ถึง
        }
      }
    }
  } catch (e) {
    debugPrint('❌ Error scheduling all meal notifications: $e');
  }
}

// ฟังก์ชันแจ้งเตือนยาหลังอาหารหลังจากผู้ใช้กดทานอาหารแล้ว
Future<void> scheduleAfterMealMedicationNotification({
  required int mealId,
  required int afterMinutes,
  required String mealName,
}) async {
  try {
    final now = DateTime.now();
    final afterTime = now.add(Duration(minutes: afterMinutes));
    final timeFormat = DateFormat('hh:mm a');
    final afterTimeStr = timeFormat.format(afterTime);

    // ตั้งแจ้งเตือนหลัก
    await _scheduleAlarmNotification(
      id: mealId * 100 + 99, // ใช้ ID เฉพาะสำหรับยาหลังอาหาร
      title: '💊 ยาหลังอาหาร - $mealName',
      body: 'ถึงเวลาทานยาหลัง$mealName $afterMinutes นาทีแล้ว!',
      time: afterTimeStr,
      payload: 'medication_after_$mealId',
      isMedication: true, // ระบุว่าเป็นยา
    );

    // เริ่มแจ้งเตือนซ้ำทันที
    await scheduleRepeatingMealNotification(
      id: mealId * 100 + 9999, // ใช้ ID เฉพาะสำหรับยาหลังอาหารซ้ำ
      title: '💊 ยาหลังอาหาร - $mealName',
      body: 'ถึงเวลาทานยาหลัง$mealName $afterMinutes นาทีแล้ว!',
      payload: 'medication_after_$mealId',
      isMedication: true, // ระบุว่าเป็นยา
    );

    debugPrint('💊 Scheduled after-meal medication notification for $mealName');
  } catch (e) {
    debugPrint('❌ Error scheduling after-meal medication: $e');
  }
}

// ปรับ _scheduleMealWithMedication: ไม่ต้อง schedule แจ้งเตือนยาหลังอาหารทันที
Future<void> _scheduleMealWithMedication({
  required int mealId,
  required String mealTime,
  required String mealName,
  required Map<String, dynamic> medicationData,
}) async {
  try {
    // ตรวจสอบว่ามียาที่ต้องทานก่อนอาหารหรือไม่
    if (medicationData['hasMedication'] == true && 
        medicationData['beforeMeal'] == true && 
        medicationData['beforeMinutes'] > 0) {
      
      // แจ้งเตือนยาก่อนอาหารแบบซ้ำๆ
      final timeFormat = DateFormat('hh:mm a');
      final parsedTime = timeFormat.parse(mealTime);
      final beforeTime = parsedTime.subtract(Duration(minutes: medicationData['beforeMinutes']));
      final beforeTimeStr = timeFormat.format(beforeTime);
      
      await _scheduleAlarmNotification(
        id: mealId * 10 + 1, // ใช้ ID เฉพาะสำหรับยาก่อนอาหาร
        title: '💊 ยาก่อนอาหาร - $mealName',
        body: 'ถึงเวลาทานยาก่อน$mealName ${medicationData['beforeMinutes']} นาทีแล้ว!',
        time: beforeTimeStr,
        payload: 'medication_before_$mealId',
        isMedication: true, // ระบุว่าเป็นยา
      );
      
      // เริ่มแจ้งเตือนยาก่อนอาหารแบบซ้ำๆ
      await scheduleRepeatingMealNotification(
        id: mealId * 10 + 10000, // ใช้ ID เฉพาะสำหรับยาก่อนอาหารซ้ำ
        title: '💊 ยาก่อนอาหาร - $mealName',
        body: 'ถึงเวลาทานยาก่อน$mealName ${medicationData['beforeMinutes']} นาทีแล้ว!',
        payload: 'medication_before_$mealId',
        isMedication: true, // ระบุว่าเป็นยา
      );
      
      debugPrint('💊 Scheduled before-meal medication notification for $mealName');
      
    } else {
      // ไม่มียาก่อนอาหาร ตั้งแจ้งเตือนอาหารทันที
      await _scheduleMealNotification(mealId, mealTime, mealName);
    }
  } catch (e) {
    debugPrint('❌ Error scheduling meal with medication: $e');
  }
}

// เพิ่มฟังก์ชันใหม่สำหรับตั้งแจ้งเตือนอาหาร
  Future<void> _scheduleMealNotification(int mealId, String mealTime, String mealName) async {
    // ตั้งเวลามื้ออาหารหลัก
    await _scheduleAlarmNotification(
      id: mealId,
      title: '🍽️ อาหาร - $mealName',
      body: 'ถึงเวลาทาน$mealNameแล้ว! กรุณาทานอาหาร',
      time: mealTime,
      payload: 'meal_$mealId',
      isMedication: false, // ระบุว่าเป็นอาหาร
    );
    
    // เริ่มแจ้งเตือนซ้ำทันที (ไม่ต้องรอกดที่แจ้งเตือน)
    await scheduleRepeatingMealNotification(
      id: mealId + 10000, // ใช้ ID เฉพาะสำหรับอาหารซ้ำ
      title: '🍽️ อาหาร - $mealName',
      body: 'ถึงเวลาทาน$mealNameแล้ว! กรุณาทานอาหาร',
      payload: 'meal_$mealId',
      isMedication: false, // ระบุว่าเป็นอาหาร
    );
    
    debugPrint('🍽️ Scheduled meal notification for $mealName');
  }

// ฟังก์ชันนี้ไม่ใช้แล้ว เพราะแจ้งเตือนซ้ำเริ่มทันทีตั้งแต่ตอนตั้งเวลา
// Future<void> handleNotificationFired({
//   required int mealId,
//   required String mealType,
//   required String mealName,
// }) async {
//   // ถ้ายังไม่กดกินข้าว ให้เริ่มแจ้งเตือนซ้ำทุก 1 นาที เฉพาะมื้อนั้น
//   if (!await isMealCompleted(mealType)) {
//     await scheduleRepeatingMealNotification(
//       id: mealId + 10000, // ใช้ id เฉพาะของมื้อนั้น
//       title: '⏰ เตือน$mealName',
//       body: 'ถึงเวลาทาน$mealNameแล้ว!',
//       payload: 'meal_$mealId',
//     );
//     debugPrint('🔁 Start repeating notification for $mealName');
//   }
// }

// ฟังก์ชันนี้ควรถูกเรียกเมื่อผู้ใช้กดกินข้าวในแอป (เพื่อหยุดแจ้งเตือนซ้ำของมื้อนั้น)
Future<void> cancelRepeatingMealNotification(int mealId) async {
  try {
    // ยกเลิกแจ้งเตือนซ้ำของมื้ออาหาร
    await flutterLocalNotificationsPlugin.cancel(mealId + 10000);
    // ยกเลิกแจ้งเตือนซ้ำของยาก่อนอาหาร
    await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 10000);
    debugPrint('🛑 Cancelled repeating notifications for mealId $mealId');
  } catch (e) {
    debugPrint('❌ Error cancelling repeating notification: $e');
  }
}

  // ปรับปรุงฟังก์ชัน scheduleRepeatingMealNotification
  Future<void> scheduleRepeatingMealNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool isMedication = false, // เพิ่มพารามิเตอร์สำหรับยา
  }) async {
    try {
      // เลือก notification details ตามประเภท
      final notificationDetails = isMedication 
        ? _createMedicationNotificationDetails()
        : _createMealNotificationDetails();
      
      await flutterLocalNotificationsPlugin.periodicallyShow(
        id,
        title,
        body,
        RepeatInterval.everyMinute,
        NotificationDetails(android: notificationDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      
      debugPrint('🔄 Started repeating ${isMedication ? "medication" : "meal"} notification: $title');
    } catch (e) {
      debugPrint('❌ Error starting repeating notification: $e');
    }
  }

Future<void> _startBurstNotification(int id, String title, String body, String payload) async {
  // ใช้ periodicallyShow เพื่อแจ้งเตือนซ้ำทุก 1 นาทีทันที
  await flutterLocalNotificationsPlugin.periodicallyShow(
    id,
    title,
    body,
    RepeatInterval.everyMinute,
    _createAlarmNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: payload,
  );
  debugPrint('🔄 Burst notification started for $title - will repeat every minute');
}


  // ทดสอบการแจ้งเตือนแบบปลุกทันที
  Future<void> showTestAlarm() async {
    try {
      await showAlarmNotificationNow(
        title: '🧪 ทดสอบการปลุก',
        body: 'หากคุณเห็นข้อความนี้แบบเต็มจอ แสดงว่าการปลุกทำงานได้แล้ว! ✅',
      );
      debugPrint('✅ Test alarm sent');
    } catch (e) {
      debugPrint('❌ Error sending test alarm: $e');
    }
  }

  // เพิ่มฟังก์ชันแสดง dialog ทันทีสำหรับมื้ออาหาร
  Future<void> showMealDialog({
    required int mealId,
    required String mealName,
    required String mealTime,
  }) async {
    try {
      // ตรวจสอบว่าแอปเปิดอยู่หรือไม่
      if (MyApp.navigatorKey.currentContext != null) {
        showDialog(
          context: MyApp.navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => MealNotificationDialog(
            mealId: mealId,
            mealName: mealName,
            mealTime: mealTime,
          ),
        );
        debugPrint('✅ Meal dialog shown for $mealName');
      } else {
        debugPrint('❌ App context not available');
      }
    } catch (e) {
      debugPrint('❌ Error showing meal dialog: $e');
    }
  }


  // ยกเลิกการแจ้งเตือนทั้งหมด
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('✅ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  // ตรวจสอบการแจ้งเตือนที่รอดำเนินการ
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // ฟังก์ชันตรวจสอบสถานะ permission
  Future<void> checkPermissionStatus() async {
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      final overlayStatus = await Permission.systemAlertWindow.status;

      debugPrint('🔍 Permission Status:');
      debugPrint('  - Notification: $notificationStatus');
      debugPrint('  - Exact Alarm: $alarmStatus');
      debugPrint('  - Battery Optimization: $batteryStatus');
      debugPrint('  - System Overlay: $overlayStatus');
      debugPrint('  - Notifications Enabled: $_notificationsEnabled');

      final pendingNotifications = await getPendingNotifications();
      debugPrint('  - Pending Notifications: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        debugPrint('    ID: ${notification.id}, Title: ${notification.title}');
      }
    }
  }

  // ฟังก์ชันเช็คสถานะการทานอาหาร
  Future<bool> isMealCompleted(String mealType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return prefs.getBool('${mealType}_completed_$today') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking meal status: $e');
      return false;
    }
  }

  // ฟังก์ชันรีเซ็ตสถานะการทานอาหารรายวัน
  Future<void> resetDailyMealStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      await prefs.remove('breakfast_completed_$today');
      await prefs.remove('lunch_completed_$today');
      await prefs.remove('dinner_completed_$today');
      
      debugPrint('✅ Daily meal status reset');
    } catch (e) {
      debugPrint('❌ Error resetting meal status: $e');
    }
  }

  // ยกเลิก burst/repeating notifications สำหรับมื้อที่ระบุ (mealId)
  Future<void> cancelBurstMealNotifications(int mealId) async {
    try {
      // ยกเลิก repeating notification ที่ใช้ id เฉพาะของมื้อนั้น (ตามที่ใช้ใน scheduleRepeatingMealNotification)
      await flutterLocalNotificationsPlugin.cancel(mealId + 10000);
      debugPrint('🛑 Cancelled burst/repeating notifications for mealId $mealId');
    } catch (e) {
      debugPrint('❌ Error cancelling burst/repeating notifications: $e');
    }
  }

  // เพิ่มฟังก์ชันอัปเดตสถานะการทานอาหารในฐานข้อมูล
  Future<void> updateMealCompletionInDatabase(int mealId, bool isCompleted) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      // แปลง mealId เป็น mealType
      String mealType = mealId == 1 ? 'breakfast' : mealId == 2 ? 'lunch' : 'dinner';
      
      // หาวันปัจจุบัน
      DateTime today = DateTime.now();
      
      // ดึงแผนอาหารปัจจุบัน
      QuerySnapshot mealPlanQuery = await _firestore
          .collection('mealPlans')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (mealPlanQuery.docs.isEmpty) {
        debugPrint('❌ No active meal plan found');
        return;
      }

      DocumentSnapshot mealPlanDoc = mealPlanQuery.docs.first;
      String mealPlanId = mealPlanDoc.id;
      Map<String, dynamic> mealPlanData = mealPlanDoc.data() as Map<String, dynamic>;

      // หาวันที่ตรงกับวันปัจจุบันในแผนอาหาร
      List<dynamic> dailyPlans = mealPlanData['dailyPlans'];
      int dayIndex = -1;
      
      for (int i = 0; i < dailyPlans.length; i++) {
        DateTime planDate = (dailyPlans[i]['date'] as Timestamp).toDate();
        if (DateUtils.isSameDay(planDate, today)) {
          dayIndex = i;
          break;
        }
      }

      if (dayIndex == -1) {
        debugPrint('❌ Today not found in meal plan');
        return;
      }

      // อัปเดตสถานะการทานอาหาร
      List<dynamic> updatedDailyPlans = List.from(dailyPlans);
      updatedDailyPlans[dayIndex]['completed'][mealType] = isCompleted;

      // บันทึกลงฐานข้อมูล
      await _firestore
          .collection('mealPlans')
          .doc(mealPlanId)
          .update({'dailyPlans': updatedDailyPlans});

      debugPrint('✅ Updated meal completion: $mealType = $isCompleted');

      // อัปเดตสถานะใน SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      await prefs.setBool('${mealType}_completed_$todayStr', isCompleted);

      // ถ้าทานแล้ว ให้หยุดแจ้งเตือนซ้ำ
      if (isCompleted) {
        await cancelBurstMealNotifications(mealId);
        
        // ตรวจสอบว่าต้องแจ้งเตือนยาหลังอาหารหรือไม่
        try {
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
          final medicationData = userDoc.data() != null ? (userDoc.data() as Map<String, dynamic>)['medicationData'] : null;
          if (medicationData != null &&
              medicationData['afterMeal'] == true &&
              medicationData['afterMinutes'] != null &&
              medicationData['afterMinutes'] > 0) {
            String mealName = mealId == 1 ? 'มื้อเช้า' : mealId == 2 ? 'มื้อเที่ยง' : 'มื้อเย็น';
            await scheduleAfterMealMedicationNotification(
              mealId: mealId,
              afterMinutes: medicationData['afterMinutes'],
              mealName: mealName,
            );
          }
        } catch (e) {
          debugPrint('Error scheduling after meal medication: $e');
        }
      }

    } catch (e) {
      debugPrint('❌ Error updating meal completion in database: $e');
    }
  }

  // เพิ่มฟังก์ชันสำหรับจัดการการตอบสนองจากแจ้งเตือนยาก่อนอาหาร
  Future<void> handleBeforeMealMedicationResponse(int mealId, String mealName) async {
    try {
      // หยุดแจ้งเตือนยาก่อนอาหารทั้งหมด
      await cancelAllMedicationNotifications(mealId);
      
      // เริ่มแจ้งเตือนอาหารทันที
      final now = DateTime.now();
      final mealTime = DateFormat('hh:mm a').format(now);
      
      await _scheduleMealNotification(mealId, mealTime, mealName);
      
      debugPrint('✅ Started meal notification after before-meal medication for $mealName');
    } catch (e) {
      debugPrint('❌ Error handling before-meal medication response: $e');
    }
  }

  // เพิ่มฟังก์ชันสำหรับจัดการการตอบสนองจากแจ้งเตือนยาหลังอาหาร
  Future<void> handleAfterMealMedicationResponse(int mealId, String mealName) async {
    try {
      // หยุดแจ้งเตือนยาหลังอาหารทั้งหมด
      await cancelAllMedicationNotifications(mealId);
      
      debugPrint('✅ Stopped after-meal medication notification for $mealName');
    } catch (e) {
      debugPrint('❌ Error handling after-meal medication response: $e');
    }
  }

  // เพิ่มฟังก์ชันสำหรับยกเลิกแจ้งเตือนยาทั้งหมด
  Future<void> cancelAllMedicationNotifications(int mealId) async {
    try {
      // ยกเลิกแจ้งเตือนยาก่อนอาหาร
      await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 1);
      await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 10000);
      await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 1000);
      await flutterLocalNotificationsPlugin.cancel(mealId * 10);
      await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 2);
      await flutterLocalNotificationsPlugin.cancel(mealId * 10 + 3);
      
      // ยกเลิกแจ้งเตือนยาหลังอาหาร
      await flutterLocalNotificationsPlugin.cancel(mealId * 100 + 99);
      await flutterLocalNotificationsPlugin.cancel(mealId * 100 + 9999);
      await flutterLocalNotificationsPlugin.cancel(mealId * 100 + 1000);
      await flutterLocalNotificationsPlugin.cancel(mealId * 100);
      await flutterLocalNotificationsPlugin.cancel(mealId * 100 + 98);
      await flutterLocalNotificationsPlugin.cancel(mealId * 100 + 97);
      
      debugPrint('🛑 Cancelled all medication notifications for mealId $mealId');
    } catch (e) {
      debugPrint('❌ Error cancelling all medication notifications: $e');
    }
  }
}