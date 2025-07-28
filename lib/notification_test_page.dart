import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'main.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบการแจ้งเตือน'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧪 ทดสอบการแจ้งเตือนใหม่',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ฟีเจอร์ใหม่: ปุ่มกดทานอาหารในแจ้งเตือน\n- กดปุ่ม "🍽️ ทานอาหาร" เพื่อแสดง dialog\n- กดปุ่ม "⏰ เลื่อนเวลา" เพื่อเลื่อน 15 นาที\n- กดปุ่ม "❌ ปิด" เพื่อปิดแจ้งเตือน',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // ปุ่มทดสอบการแจ้งเตือน
            ElevatedButton.icon(
              onPressed: isLoading ? null : _testMealNotification,
              icon: const Icon(Icons.notifications_active),
              label: const Text('ทดสอบแจ้งเตือนมื้ออาหาร'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: isLoading ? null : _testDialogDirectly,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('ทดสอบ Dialog โดยตรง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: isLoading ? null : _testAlarmNotification,
              icon: const Icon(Icons.alarm),
              label: const Text('ทดสอบการปลุกแบบเต็มจอ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            OutlinedButton.icon(
              onPressed: isLoading ? null : _checkPermissions,
              icon: const Icon(Icons.security),
              label: const Text('ตรวจสอบสิทธิ์'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            OutlinedButton.icon(
              onPressed: isLoading ? null : _cancelAllNotifications,
              icon: const Icon(Icons.cancel),
              label: const Text('ยกเลิกการแจ้งเตือนทั้งหมด'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            if (isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testMealNotification() async {
    setState(() {
      isLoading = true;
    });

    try {
      // ทดสอบแจ้งเตือนมื้อเช้า
      await _notificationService.showAlarmNotificationNow(
        title: '⏰ เตือนมื้อเช้า',
        body: 'ถึงเวลาทานมื้อเช้าแล้ว! กดปุ่มด้านล่างเพื่อทานอาหาร',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ส่งแจ้งเตือนมื้อเช้าแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testDialogDirectly() async {
    setState(() {
      isLoading = true;
    });

    try {
      // แสดง dialog โดยตรง
      await _notificationService.showMealDialog(
        mealId: 1,
        mealName: 'มื้อเช้า',
        mealTime: '08:00 AM',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ แสดง Dialog แล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testAlarmNotification() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _notificationService.showTestAlarm();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ส่งการปลุกแบบเต็มจอแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _notificationService.checkPermissionStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ตรวจสอบสิทธิ์แล้ว ดูผลลัพธ์ใน Console'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cancelAllNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _notificationService.cancelAllNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ยกเลิกการแจ้งเตือนทั้งหมดแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
} 