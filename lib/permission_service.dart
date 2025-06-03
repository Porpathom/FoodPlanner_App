import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestNotificationPermission() async {
    // ขอสิทธิ์การแจ้งเตือน
    PermissionStatus status = await Permission.notification.request();
    
    if (status.isGranted) {
      print('Notification permission granted');
      return true;
    } else if (status.isDenied) {
      print('Notification permission denied');
      return false;
    } else if (status.isPermanentlyDenied) {
      print('Notification permission permanently denied, open settings');
      // แนะนำให้ผู้ใช้เปิดการตั้งค่า
      openAppSettings();
      return false;
    }
    
    return false;
  }
}