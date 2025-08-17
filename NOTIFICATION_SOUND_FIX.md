# 🔧 แก้ไขปัญหาการแจ้งเตือนไม่เป็นเสียง

## ปัญหาที่พบ
การแจ้งเตือนในแอปไม่ได้ใช้ไฟล์เสียง `alarm_sound.mp3` ที่กำหนดไว้ แต่เป็นเสียงปกติของระบบแทน

## สาเหตุที่เป็นไปได้

### 1. การตั้งค่า Notification Channel ไม่ถูกต้อง
- ต้องสร้าง notification channel ที่มี `sound: RawResourceAndroidNotificationSound('alarm_sound')`
- ต้องตั้งค่า `playSound: true`

### 2. ไฟล์เสียงไม่ถูกต้อง
- ไฟล์เสียงต้องอยู่ใน `android/app/src/main/res/raw/alarm_sound.mp3`
- ชื่อไฟล์ต้องตรงกับที่ระบุในโค้ด (ไม่ต้องมีนามสกุล)

### 3. การตั้งค่าใน Android
- ตรวจสอบว่าเสียงในโทรศัพท์เปิดอยู่
- ตรวจสอบการตั้งค่าแจ้งเตือนในแอป
- ตรวจสอบว่าไม่ใช่โหมดเงียบ

## วิธีแก้ไขที่ทำแล้ว

### 1. ปรับปรุง Notification Channels
```dart
AndroidNotificationChannel mealChannel = const AndroidNotificationChannel(
  'meal_channel',
  'Meal Notifications',
  description: 'แจ้งเตือนสำหรับอาหาร',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('alarm_sound'),
  // ... อื่นๆ
);
```

### 2. ปรับปรุง Notification Details
```dart
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
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    // ... อื่นๆ
  );
}
```

### 3. เพิ่มฟังก์ชันทดสอบ
```dart
Future<void> testNotificationSound() async {
  try {
    await flutterLocalNotificationsPlugin.show(
      9998,
      '🔊 ทดสอบเสียงแจ้งเตือนอาหาร',
      'คุณควรได้ยินเสียง alarm_sound.mp3',
      NotificationDetails(android: _createMealNotificationDetails()),
    );
  } catch (e) {
    debugPrint('❌ Error testing notification sound: $e');
  }
}
```

## วิธีทดสอบ

### 1. ใช้หน้าทดสอบในแอป
1. เปิดแอป
2. กดปุ่ม "🧪 ทดสอบการแจ้งเตือน" ในหน้าแรก
3. กดปุ่ม "🔊 ทดสอบเสียงแจ้งเตือน"
4. ตรวจสอบว่าได้ยินเสียง `alarm_sound.mp3`

### 2. ตรวจสอบไฟล์เสียง
```bash
# ตรวจสอบว่าไฟล์เสียงมีอยู่
ls -la android/app/src/main/res/raw/alarm_sound.mp3
```

### 3. ตรวจสอบ Log
```bash
# ดู log ใน console
flutter logs
```

## การแก้ไขเพิ่มเติม

### หากยังไม่ได้ยินเสียง:

1. **รีสตาร์ทแอป**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **ตรวจสอบการตั้งค่าในโทรศัพท์**
   - ไปที่ Settings > Apps > FoodPlanner > Notifications
   - ตรวจสอบว่า "Sound" เปิดอยู่

3. **ตรวจสอบโหมดเงียบ**
   - ตรวจสอบว่าโทรศัพท์ไม่ได้อยู่ในโหมดเงียบ
   - ตรวจสอบว่าเสียงระบบเปิดอยู่

4. **ทดสอบไฟล์เสียง**
   - เปิดไฟล์ `alarm_sound.mp3` ในโทรศัพท์เพื่อตรวจสอบว่าไฟล์ไม่เสีย

5. **เปลี่ยนชื่อไฟล์เสียง**
   - ลองเปลี่ยนชื่อไฟล์เป็น `notification_sound.mp3`
   - อัปเดตโค้ดให้ตรงกัน

## โครงสร้างไฟล์ที่ถูกต้อง

```
android/app/src/main/res/
├── raw/
│   └── alarm_sound.mp3  # ไฟล์เสียงแจ้งเตือน
├── drawable/
│   └── notification_icon.png  # ไอคอนแจ้งเตือน
└── values/
    └── styles.xml
```

## การ Debug

### เพิ่ม Debug Log
```dart
debugPrint('🔊 Playing notification sound: alarm_sound.mp3');
```

### ตรวจสอบ Notification Channel
```dart
final channels = await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.getNotificationChannels();
debugPrint('📋 Available channels: $channels');
```

## หมายเหตุสำคัญ

- ไฟล์เสียงต้องอยู่ในโฟลเดอร์ `raw/` เท่านั้น
- ชื่อไฟล์ต้องตรงกับที่ระบุในโค้ด (ไม่ต้องมีนามสกุล)
- ต้องสร้าง notification channel ก่อนใช้งาน
- การทดสอบควรทำบนอุปกรณ์จริง ไม่ใช่ emulator 