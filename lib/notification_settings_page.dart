import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool notificationsEnabled = true;
  bool breakfastNotificationEnabled = true;
  bool lunchNotificationEnabled = true;
  bool dinnerNotificationEnabled = true;
  
  late String breakfastTime = '';
  late String lunchTime = '';
  late String dinnerTime = '';
  
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }
  
  Future<void> _loadUserSettings() async {
    setState(() {
      isLoading = true;
    });
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // โหลดข้อมูลจาก Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            breakfastTime = userData['breakfastTime'] ?? '';
            lunchTime = userData['lunchTime'] ?? '';
            dinnerTime = userData['dinnerTime'] ?? '';
            
            // โหลดการตั้งค่าแจ้งเตือน (หากมี)
            notificationsEnabled = userData['notificationsEnabled'] ?? true;
            breakfastNotificationEnabled = userData['breakfastNotificationEnabled'] ?? true;
            lunchNotificationEnabled = userData['lunchNotificationEnabled'] ?? true;
            dinnerNotificationEnabled = userData['dinnerNotificationEnabled'] ?? true;
          });
        }
      } catch (e) {
        print("Error loading user settings: $e");
      }
    }
    
    setState(() {
      isLoading = false;
    });
  }
  
  Future<void> _saveNotificationSettings() async {
  setState(() {
    isLoading = true;
  });
  
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      // บันทึกการตั้งค่าแจ้งเตือนพร้อมเวลาไปยัง Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'notificationsEnabled': notificationsEnabled,
        'breakfastNotificationEnabled': breakfastNotificationEnabled,
        'lunchNotificationEnabled': lunchNotificationEnabled,
        'dinnerNotificationEnabled': dinnerNotificationEnabled,
        'breakfastTime': breakfastTime,
        'lunchTime': lunchTime,
        'dinnerTime': dinnerTime,
      }, SetOptions(merge: true));
      
      // อัพเดทการแจ้งเตือน
      _updateNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการตั้งค่าการแจ้งเตือนเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error saving notification settings: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกการตั้งค่า'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  setState(() {
    isLoading = false;
  });
}
  
Future<void> _updateNotifications() async {
  // ตรวจสอบสิทธิ์การแจ้งเตือนก่อนดำเนินการ
  final notificationService = NotificationService();
  
  // เรียก init() ก่อนเพื่อให้แน่ใจว่า timezone ถูก initialize
  await notificationService.init();
  
  final hasPermission = await notificationService.checkAndRequestNotificationPermission();
  
  if (!hasPermission) {
    // แสดง dialog แจ้งผู้ใช้เมื่อไม่มีสิทธิ์
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ต้องการสิทธิ์การแจ้งเตือน'),
          content: const Text('แอปต้องการสิทธิ์ในการแสดงการแจ้งเตือน กรุณาเปิดสิทธิ์ในตั้งค่าการแจ้งเตือนของอุปกรณ์'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // เปิดหน้าตั้งค่าการแจ้งเตือนของอุปกรณ์
                notificationService.flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<
                        AndroidFlutterLocalNotificationsPlugin>()
                    ;
              },
              child: const Text('ไปที่ตั้งค่า'),
            ),
          ],
        ),
      );
    }
    return;
  }

  // ยกเลิกการแจ้งเตือนทั้งหมดก่อน
  await notificationService.cancelAllNotifications();
  
  // ถ้าการแจ้งเตือนไม่เปิดใช้งาน ไม่ต้องตั้งค่าใหม่
  if (!notificationsEnabled) return;
  

  // แจ้งผู้ใช้เมื่อตั้งค่าสำเร็จ
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ตั้งค่าการแจ้งเตือนเรียบร้อยแล้ว'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การตั้งค่าการแจ้งเตือน'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'เปิดใช้งานการแจ้งเตือนทั้งหมด',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          value: notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              notificationsEnabled = value;
                            });
                          },
                          secondary: const Icon(
                            Icons.notifications,
                            color: Colors.blue,
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                          child: Text(
                            'ตั้งค่าการแจ้งเตือนแต่ละมื้อ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('การแจ้งเตือนมื้อเช้า'),
                          subtitle: Text(breakfastTime.isEmpty ? 'ยังไม่ได้ตั้งเวลา' : breakfastTime),
                          value: breakfastNotificationEnabled && notificationsEnabled,
                          onChanged: notificationsEnabled
                            ? (value) {
                                setState(() {
                                  breakfastNotificationEnabled = value;
                                });
                              }
                            : null,
                          secondary: const Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.orange,
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('การแจ้งเตือนมื้อกลางวัน'),
                          subtitle: Text(lunchTime.isEmpty ? 'ยังไม่ได้ตั้งเวลา' : lunchTime),
                          value: lunchNotificationEnabled && notificationsEnabled,
                          onChanged: notificationsEnabled
                            ? (value) {
                                setState(() {
                                  lunchNotificationEnabled = value;
                                });
                              }
                            : null,
                          secondary: Icon(
                            Icons.wb_sunny,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('การแจ้งเตือนมื้อเย็น'),
                          subtitle: Text(dinnerTime.isEmpty ? 'ยังไม่ได้ตั้งเวลา' : dinnerTime),
                          value: dinnerNotificationEnabled && notificationsEnabled,
                          onChanged: notificationsEnabled
                            ? (value) {
                                setState(() {
                                  dinnerNotificationEnabled = value;
                                });
                              }
                            : null,
                          secondary: const Icon(
                            Icons.nightlight_round,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('บันทึกการตั้งค่า'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _saveNotificationSettings,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}