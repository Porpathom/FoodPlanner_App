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

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id + 1000,
      title,
      body,
      scheduledTZDateTime,
      _createAlarmNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    debugPrint('✅ Alarm scheduled for $time with ID $id');
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
    ),
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

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 1000,
        title,
        body,
        scheduledTZDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
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
            when: null,
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
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal_$id',
      );

      debugPrint('✅ Fullscreen Alarm scheduled for $time with ID $id');
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
          await scheduleRepeatingMealNotification(
            id: (meal['id'] as int) + 10000,
            title: '⏰ เตือน${meal['name']}',
            body: 'ถึงเวลาทาน${meal['name']}แล้ว!',
            payload: 'meal_${meal['id']}',
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
  final now = DateTime.now();
  final scheduledTime = now.add(Duration(minutes: afterMinutes));
  final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

  debugPrint('🔔 [DEBUG] Schedule after-meal med: mealId= [1m$mealId [0m, afterMinutes= [1m$afterMinutes [0m, mealName= [1m$mealName [0m, scheduledTime= [1m$scheduledTime [0m');

  await flutterLocalNotificationsPlugin.zonedSchedule(
    mealId * 100 + 99, // ใช้ id เฉพาะสำหรับแจ้งเตือนยาหลังอาหาร
    '💊 ทานยาหลัง$mealName',
    'ถึงเวลาทานยาหลัง$mealName $afterMinutes นาที',
    tzTime,
    _createAlarmNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: null,
    payload: 'medication_after_$mealId',
  );
}

// ปรับ _scheduleMealWithMedication: ไม่ต้อง schedule แจ้งเตือนยาหลังอาหารทันที
Future<void> _scheduleMealWithMedication({
  required int mealId,
  required String mealTime,
  required String mealName,
  required Map<String, dynamic> medicationData,
}) async {
  try {
    // ตั้งเวลามื้ออาหารหลัก
    await _scheduleAlarmNotification(
      id: mealId,
      title: '⏰ เตือน$mealName',
      body: 'ถึงเวลาทาน$mealNameแล้ว!',
      time: mealTime,
      payload: 'meal_$mealId',
    );
    // *** ไม่ต้อง scheduleRepeatingMealNotification ที่นี่ ***
    // จะไป schedule เฉพาะเมื่อ notification แรกถูก trigger (ดูฟังก์ชัน handleNotificationFired ด้านล่าง)

    // ตรวจสอบว่ามียาที่ต้องทานหรือไม่
    if (medicationData['hasMedication'] == true) {
      final timeFormat = DateFormat('hh:mm a');
      final parsedTime = timeFormat.parse(mealTime);

      // แจ้งเตือนก่อนอาหาร (ถ้ามี)
      if (medicationData['beforeMeal'] == true && medicationData['beforeMinutes'] > 0) {
        final beforeTime = parsedTime.subtract(Duration(minutes: medicationData['beforeMinutes']));
        final beforeTimeStr = timeFormat.format(beforeTime);
        
        await _scheduleAlarmNotification(
          id: mealId * 10 + 1, // ใช้ ID ที่ต่างกัน
          title: '💊 ทานยาก่อน$mealName',
          body: 'ถึงเวลาทานยาก่อน$mealName ${medicationData['beforeMinutes']} นาที',
          time: beforeTimeStr,
          payload: 'medication_before_$mealId',
        );
      }
      // *** ไม่ต้อง schedule แจ้งเตือนยาหลังอาหารที่นี่ ***
    }
  } catch (e) {
    debugPrint('❌ Error scheduling meal with medication: $e');
  }
}

// ฟังก์ชันนี้ควรถูกเรียกเมื่อ notification แรกของมื้อนั้นถูก trigger (เช่นใน onDidReceiveNotificationResponse หรือ background handler)
Future<void> handleNotificationFired({
  required int mealId,
  required String mealType,
  required String mealName,
}) async {
  // ถ้ายังไม่กดกินข้าว ให้เริ่มแจ้งเตือนซ้ำทุก 1 นาที เฉพาะมื้อนั้น
  if (!await isMealCompleted(mealType)) {
    await scheduleRepeatingMealNotification(
      id: mealId + 10000, // ใช้ id เฉพาะของมื้อนั้น
      title: '⏰ เตือน$mealName',
      body: 'ถึงเวลาทาน$mealNameแล้ว!',
      payload: 'meal_$mealId',
    );
    debugPrint('🔁 Start repeating notification for $mealName');
  }
}

// ฟังก์ชันนี้ควรถูกเรียกเมื่อผู้ใช้กดกินข้าวในแอป (เพื่อหยุดแจ้งเตือนซ้ำของมื้อนั้น)
Future<void> cancelRepeatingMealNotification(int mealId) async {
  try {
    await flutterLocalNotificationsPlugin.cancel(mealId + 10000);
    debugPrint('🛑 Cancelled repeating notification for mealId $mealId');
  } catch (e) {
    debugPrint('❌ Error cancelling repeating notification: $e');
  }
}

Future<void> scheduleRepeatingMealNotification({
  required int id,
  required String title,
  required String body,
  required String payload,
  DateTime? startTime, // เพิ่ม parameter สำหรับ burst schedule
}) async {
  try {
    if (startTime != null) {
      // ถ้าใส่ startTime ให้รอจนถึงเวลานั้นก่อนค่อยเริ่ม burst
      final now = DateTime.now();
      final delay = startTime.difference(now);
      if (delay.isNegative) {
        // ถ้าเลยเวลาแล้ว ให้เริ่ม burst ทันที
        await _startBurstNotification(id, title, body, payload);
      } else {
        Future.delayed(delay, () async {
          await _startBurstNotification(id, title, body, payload);
        });
      }
    } else {
      // เริ่ม burst ทันที
      await _startBurstNotification(id, title, body, payload);
    }
    debugPrint('✅ Repeating notification scheduled for $title');
  } catch (e) {
    debugPrint('❌ Error scheduling repeating notification: $e');
  }
}

Future<void> _startBurstNotification(int id, String title, String body, String payload) async {
  await flutterLocalNotificationsPlugin.periodicallyShow(
    id,
    title,
    body,
    RepeatInterval.everyMinute,
    _createAlarmNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: payload,
  );
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
}