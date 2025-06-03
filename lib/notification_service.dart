// lib/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {

  bool _isTimezoneInitialized = false;

  // Singleton pattern
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // เพิ่มการเช็คว่าแอปได้รับอนุญาตแจ้งเตือนหรือไม่
  bool _notificationsEnabled = false;
  Future<bool> checkAndRequestNotificationPermission() async {
  if (Platform.isAndroid) {
    // สำหรับ Android 13+ ต้องขอสิทธิ์แยกต่างหาก
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // ตรวจสอบว่าเป็น Android 13+ หรือไม่
      final bool? areNotificationsEnabled = await androidPlugin.areNotificationsEnabled();
      if (areNotificationsEnabled == false) {
        // แสดง dialog ขอสิทธิ์
        return false;
      }
    }
    return true;
  } else if (Platform.isIOS) {
    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result ?? false;
  }
  return true;
}

Future<void> init() async {
  try {
    if (!_isTimezoneInitialized) {
      // Initialize timezone database
      tz_data.initializeTimeZones();
      
      // Set default timezone (Asia/Bangkok)
      try {
        final bangkok = tz.getLocation('Asia/Bangkok');
        tz.setLocalLocation(bangkok);
        _isTimezoneInitialized = true;
        debugPrint('Timezone initialized to Asia/Bangkok');
      } catch (e) {
        debugPrint('Error setting timezone: $e');
        // Fallback to UTC
        tz.setLocalLocation(tz.UTC);
        _isTimezoneInitialized = true;
        debugPrint('Timezone initialized to UTC');
      }
    }
  } catch (e) {
    debugPrint('Error initializing timezone: $e');
    _isTimezoneInitialized = false;
    rethrow; // เพิ่มบรรทัดนี้เพื่อให้เห็นข้อผิดพลาดชัดเจนขึ้น
  }

    // สร้าง notification channel สำหรับ Android อย่างละเอียด
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'meal_notification_channel',                  // id
      'Meal Notifications',                         // name
      description: 'Notifications for meal times',  // description
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      ledColor: Colors.blue,
    );

    // สร้าง channel ก่อนใช้งาน (จำเป็นสำหรับ Android 8.0 ขึ้นไป)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ตั้งค่า notification icon - เปลี่ยนไปใช้ icon ที่มีอยู่จริงในแอป
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notification_icon');

    // ตั้งค่า iOS หากแอปสนับสนุน iOS - Updated for newer versions
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      // FIX: Remove onDidReceiveLocalNotification parameter as it's no longer supported
    );

    // รวมการตั้งค่าทั้งหมด
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // เริ่มต้น plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        // จัดการเมื่อผู้ใช้แตะที่การแจ้งเตือน
        debugPrint('Notification clicked: ${notificationResponse.payload}');
      },
    );

    // ขอสิทธิ์แจ้งเตือน และเก็บผลลัพธ์
    _notificationsEnabled = await _requestNotificationPermissions();
    
    // บันทึกสถานะการอนุญาตแจ้งเตือนใน SharedPreferences
    _saveNotificationPermissionStatus(_notificationsEnabled);
    
    debugPrint('Notifications enabled: $_notificationsEnabled');
  }

  // บันทึกสถานะการอนุญาตแจ้งเตือน
  Future<void> _saveNotificationPermissionStatus(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', isEnabled);
    } catch (e) {
      debugPrint('Error saving notification permission status: $e');
    }
  }
  
  // อ่านสถานะการอนุญาตแจ้งเตือน
  Future<bool> getNotificationPermissionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? false;
    } catch (e) {
      debugPrint('Error getting notification permission status: $e');
      return false;
    }
  }

  // ขอสิทธิ์แจ้งเตือนแยกเป็นฟังก์ชัน - ปรับปรุงให้รองรับ Android 13+
  Future<bool> _requestNotificationPermissions() async {
    bool permissionGranted = false;
    
    // สำหรับ Android
    if (Platform.isAndroid) {
      // ตรวจสอบว่าสามารถขอสิทธิ์แจ้งเตือนได้หรือไม่ (Android 13+)
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      // For Android 13+ (API Level 33+), we need to check and request notification permission
      if (androidImplementation != null) {
        try {
          // Check if we're on Android 13+ where requestPermission is needed
          // For older versions we'll assume permissions are granted through manifest
          const int androidTiramisuSdkInt = 33; // Android 13 SDK int value
          // Use areNotificationsEnabled to check current permission status (available in recent versions)
          permissionGranted = await androidImplementation.areNotificationsEnabled() ?? false;
          debugPrint('Android notification permission check: $permissionGranted');
        } catch (e) {
          debugPrint('Error checking Android notification permission: $e');
          // Assume granted if we can't check (for compatibility with older devices)
          permissionGranted = true;
        }
      }
    } 
    // สำหรับ iOS
    else if (Platform.isIOS) {
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      permissionGranted = result ?? false;
      debugPrint('iOS notification permission granted: $permissionGranted');
    }
    
    return permissionGranted;
  }

  // กำหนดการแจ้งเตือนสำหรับมื้ออาหาร - ปรับปรุงประสิทธิภาพ
Future<void> scheduleMealNotification({
  required int id,
  required String title,
  required String body,
  required String time,
  required bool daily,
}) async {
  try {
    // 1. ตรวจสอบและ initialize timezone
    if (!_isTimezoneInitialized) {
      await init();
      if (!_isTimezoneInitialized) {
        throw Exception('Failed to initialize timezone');
      }
    }

    // 2. ตรวจสอบสิทธิ์การแจ้งเตือน
    final hasPermission = await checkAndRequestNotificationPermission();
    if (!hasPermission) {
      debugPrint('Notification permission not granted');
      return;
    }

    // 3. แปลงเวลาและตั้งค่า timezone
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

    // 4. ปรับเวลาหากผ่านไปแล้ว
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 5. แปลงเป็น TZDateTime
    final tzLocation = tz.local;
    final scheduledTZDateTime = tz.TZDateTime.from(scheduledDate, tzLocation);

    // 6. Debug log
    debugPrint('''
Scheduling notification:
- Current local time: $now
- Scheduled time: $time
- Parsed time: $parsedTime
- Scheduled date: $scheduledDate
- TZDateTime: $scheduledTZDateTime
- Timezone: ${tzLocation.name}
''');

    // 7. กำหนดการแจ้งเตือน
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZDateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_notification_channel',
          'Meal Notifications',
          channelDescription: 'Notifications for meal times',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          icon: 'notification_icon',
          channelShowBadge: true,
          showWhen: true,
          autoCancel: true,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      payload: 'meal_$id',
    );

    // 8. บันทึกการตั้งค่า
    await _saveScheduledNotification(id, title, body, time, daily);
    
    debugPrint('Notification scheduled successfully for $time');
    debugPrint('Current TZ time: ${tz.TZDateTime.now(tzLocation)}');

  } catch (e) {
    debugPrint('Error in scheduleMealNotification: $e');
    rethrow;
  }
}

  // บันทึกข้อมูลการแจ้งเตือนที่ตั้งเวลาไว้ใน SharedPreferences
  Future<void> _saveScheduledNotification(
    int id, String title, String body, String time, bool daily) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_${id}_time', time);
      await prefs.setString('notification_${id}_title', title);
      await prefs.setString('notification_${id}_body', body);
      await prefs.setBool('notification_${id}_daily', daily);
      await prefs.setBool('notification_${id}_active', true);
    } catch (e) {
      debugPrint('Error saving scheduled notification: $e');
    }
  }

  // ฟังก์ชันสำหรับโหลดและตั้งค่าการแจ้งเตือนทั้งหมดใหม่ (เรียกใช้หลังจากรีสตาร์ทแอป)
  Future<void> reloadScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // ตรวจสอบการแจ้งเตือนทั้ง 3 มื้อ
      for (int id = 1; id <= 3; id++) {
        bool isActive = prefs.getBool('notification_${id}_active') ?? false;
        
        if (isActive) {
          String? title = prefs.getString('notification_${id}_title');
          String? body = prefs.getString('notification_${id}_body');
          String? time = prefs.getString('notification_${id}_time');
          bool daily = prefs.getBool('notification_${id}_daily') ?? true;
          
          if (title != null && body != null && time != null) {
            await scheduleMealNotification(
              id: id,
              title: title,
              body: body,
              time: time,
              daily: daily,
            );
            debugPrint('Reloaded notification #$id for $time');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reloading scheduled notifications: $e');
    }
  }

  // ทดสอบการแจ้งเตือนทันที (สำหรับตรวจสอบว่าการแจ้งเตือนทำงานได้)
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'meal_notification_channel',
      'Meal Notifications',
      channelDescription: 'Notifications for meal times',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'notification_icon',
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await flutterLocalNotificationsPlugin.show(
      0,
      'ทดสอบการแจ้งเตือน',
      'หากคุณเห็นข้อความนี้ แสดงว่าการแจ้งเตือนทำงานได้แล้ว',
      platformChannelSpecifics,
      payload: 'test_notification',
    );
  }

  // ยกเลิกการแจ้งเตือนตาม ID
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    
    // ลบข้อมูลการแจ้งเตือนจาก SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_${id}_active', false);
    } catch (e) {
      debugPrint('Error removing notification data: $e');
    }
  }

  // ยกเลิกการแจ้งเตือนทั้งหมด
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    
    // ลบข้อมูลการแจ้งเตือนทั้งหมดจาก SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int id = 1; id <= 3; id++) {
        await prefs.setBool('notification_${id}_active', false);
      }
    } catch (e) {
      debugPrint('Error removing all notification data: $e');
    }
  }

  // กำหนดการแจ้งเตือนทั้งหมดสำหรับมื้ออาหาร
  Future<void> scheduleAllMealNotifications({
    required String breakfastTime,
    required String lunchTime,
    required String dinnerTime,
  }) async {
    // ยกเลิกการแจ้งเตือนเดิมก่อน
    await cancelNotification(1); // breakfast
    await cancelNotification(2); // lunch
    await cancelNotification(3); // dinner

    // ตั้งการแจ้งเตือนใหม่
    if (breakfastTime.isNotEmpty) {
      await scheduleMealNotification(
        id: 1,
        title: 'เตือนมื้อเช้า',
        body: 'ถึงเวลาทานอาหารเช้าแล้ว เราได้เตรียมรายการอาหารไว้ให้คุณแล้ว',
        time: breakfastTime,
        daily: true,
      );
    }

    if (lunchTime.isNotEmpty) {
      await scheduleMealNotification(
        id: 2,
        title: 'เตือนมื้อกลางวัน',
        body: 'ถึงเวลาทานอาหารกลางวันแล้ว เราได้เตรียมรายการอาหารไว้ให้คุณแล้ว',
        time: lunchTime,
        daily: true,
      );
    }

    if (dinnerTime.isNotEmpty) {
      await scheduleMealNotification(
        id: 3,
        title: 'เตือนมื้อเย็น',
        body: 'ถึงเวลาทานอาหารเย็นแล้ว เราได้เตรียมรายการอาหารไว้ให้คุณแล้ว',
        time: dinnerTime,
        daily: true,
      );
    }
  }
}