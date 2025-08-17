import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.init();
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 ทดสอบการแจ้งเตือน'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ทดสอบการแจ้งเตือนและเสียง',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // ทดสอบเสียงแจ้งเตือน
                  _buildTestCard(
                    title: '🔊 ทดสอบเสียงแจ้งเตือน',
                    subtitle: 'ทดสอบเสียง alarm_sound.mp3',
                    onPressed: _testNotificationSound,
                    color: Colors.green,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ทดสอบการแจ้งเตือนอาหาร
                  _buildTestCard(
                    title: '🍽️ ทดสอบแจ้งเตือนอาหาร',
                    subtitle: 'ทดสอบการแจ้งเตือนอาหารพร้อมเสียง',
                    onPressed: _testMealNotification,
                    color: Colors.orange,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ทดสอบการแจ้งเตือนยา
                  _buildTestCard(
                    title: '💊 ทดสอบแจ้งเตือนยา',
                    subtitle: 'ทดสอบการแจ้งเตือนยาพร้อมเสียง',
                    onPressed: _testMedicationNotification,
                    color: Colors.purple,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ทดสอบการแจ้งเตือนแบบเต็มจอ
                  _buildTestCard(
                    title: '🖥️ ทดสอบแจ้งเตือนเต็มจอ',
                    subtitle: 'ทดสอบการแจ้งเตือนแบบเต็มจอ',
                    onPressed: _testFullscreenNotification,
                    color: Colors.red,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ตรวจสอบสถานะ
                  _buildTestCard(
                    title: '📊 ตรวจสอบสถานะ',
                    subtitle: 'ตรวจสอบสิทธิ์และการตั้งค่า',
                    onPressed: _checkStatus,
                    color: Colors.blue,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // ข้อมูลเพิ่มเติม
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📝 หมายเหตุ:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• ไฟล์เสียง: android/app/src/main/res/raw/alarm_sound.mp3\n'
                          '• ตรวจสอบว่าเสียงในโทรศัพท์เปิดอยู่\n'
                          '• ตรวจสอบการตั้งค่าแจ้งเตือนในแอป\n'
                          '• หากยังไม่ได้ยินเสียง ลองรีสตาร์ทแอป',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testNotificationSound() async {
    try {
      await _notificationService.testNotificationSound();
      _showSnackBar('✅ ส่งการทดสอบเสียงแจ้งเตือนแล้ว');
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _testMealNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.show(
        9997,
        '🍽️ ทดสอบแจ้งเตือนอาหาร',
        'คุณควรได้ยินเสียง alarm_sound.mp3',
        NotificationDetails(android: _notificationService.createMealNotificationDetails()),
      );
      _showSnackBar('✅ ส่งการทดสอบแจ้งเตือนอาหารแล้ว');
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _testMedicationNotification() async {
    try {
      await _notificationService.flutterLocalNotificationsPlugin.show(
        9996,
        '💊 ทดสอบแจ้งเตือนยา',
        'คุณควรได้ยินเสียง alarm_sound.mp3',
        NotificationDetails(android: _notificationService.createMedicationNotificationDetails()),
      );
      _showSnackBar('✅ ส่งการทดสอบแจ้งเตือนยาแล้ว');
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _testFullscreenNotification() async {
    try {
      await _notificationService.showTestAlarm();
      _showSnackBar('✅ ส่งการทดสอบแจ้งเตือนเต็มจอแล้ว');
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _checkStatus() async {
    try {
      await _notificationService.checkPermissionStatus();
      _showSnackBar('✅ ตรวจสอบสถานะแล้ว ดู log ใน console');
    } catch (e) {
      _showSnackBar('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: message.contains('✅') ? Colors.green : Colors.red,
      ),
    );
  }
} 