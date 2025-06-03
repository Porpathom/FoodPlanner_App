// ignore_for_file: prefer_const_constructors_in_immutables, use_key_in_widget_constructors, library_private_types_in_public_api, avoid_print, prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // เพิ่ม package สำหรับจัดรูปแบบเวลา
import 'notification_service.dart';

class EditUserDataPage extends StatefulWidget {
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;
  final String medicalCondition;
  final Function(String)? onMedicalConditionUpdated; // เพิ่ม callback function

  EditUserDataPage({
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.medicalCondition,
    this.onMedicalConditionUpdated, // เพิ่ม callback function
  });

  @override
  _EditUserDataPageState createState() => _EditUserDataPageState();
}

class _EditUserDataPageState extends State<EditUserDataPage> {
  late String breakfastTime;
  late String lunchTime;
  late String dinnerTime;
  String selectedMedicalCondition = 'ไม่มีโรคประจำตัว';

  // สำหรับตัวเลือกโรคประจำตัว
  final List<String> medicalConditions = [
    'ไม่มีโรคประจำตัว',
    'โรคเบาหวาน',
    'โรคหัวใจ',
    'โรคความดันโลหิตสูง',
  ];

  // Map สำหรับแปลงค่าระหว่าง medicalCondition และ suitableFor
  final Map<String, Map<String, bool>> medicalToSuitable = {
    'ไม่มีโรคประจำตัว': {
      'healthy': true,
      'diabetes': false,
      'heartDisease': false,
      'highBloodPressure': false
    },
    'โรคเบาหวาน': {
      'healthy': false,
      'diabetes': true,
      'heartDisease': false,
      'highBloodPressure': false
    },
    'โรคหัวใจ': {
      'healthy': false,
      'diabetes': false,
      'heartDisease': true,
      'highBloodPressure': false
    },
    'โรคความดันโลหิตสูง': {
      'healthy': false,
      'diabetes': false,
      'heartDisease': false,
      'highBloodPressure': true
    },
  };

  bool isMedicalConditionSelected = false;
  DateTime? mealPlanEndDate;
  bool isMealPlanActive = false;

  @override
  void initState() {
    super.initState();
    breakfastTime = widget.breakfastTime;
    lunchTime = widget.lunchTime;
    dinnerTime = widget.dinnerTime;

    // ตั้งค่าโรคประจำตัวเริ่มต้น
    if (medicalConditions.contains(widget.medicalCondition)) {
      selectedMedicalCondition = widget.medicalCondition;
    } else {
      selectedMedicalCondition = 'ไม่มีโรคประจำตัว';
    }

    // ตรวจสอบแผนอาหารปัจจุบัน
    _checkCurrentMealPlan();
    _initializeNotificationService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().init();
    });
  }

// เพิ่มเมธอดตรวจสอบแผนอาหาร
  Future<void> _checkCurrentMealPlan() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot activePlanSnapshot = await FirebaseFirestore.instance
            .collection('mealPlans')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (activePlanSnapshot.docs.isNotEmpty) {
          var planData =
              activePlanSnapshot.docs[0].data() as Map<String, dynamic>;
          Timestamp? endTimestamp = planData['endDate'] as Timestamp?;

          if (endTimestamp != null) {
            setState(() {
              mealPlanEndDate = endTimestamp.toDate();
              isMealPlanActive = DateTime.now().isBefore(mealPlanEndDate!);

              // ตรวจสอบว่าเคยเลือกโรคประจำตัวหรือไม่
              isMedicalConditionSelected = widget.medicalCondition.isNotEmpty &&
                  widget.medicalCondition != 'ไม่มีโรคประจำตัว' &&
                  isMealPlanActive;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking meal plan: $e");
    }
  }

  Future<void> _initializeNotificationService() async {
    try {
      await NotificationService().init();
    } catch (e) {
      print("Error initializing notification service: $e");
      // You can show a warning to the user if needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not initialize notifications. Some features may not work.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // แปลงเวลาจากสตริงให้เป็น TimeOfDay
  TimeOfDay _parseTimeString(String timeString) {
    try {
      // ตรวจสอบว่าเป็นรูปแบบ "HH:MM" หรือ "HH:MM AM/PM"
      if (timeString.contains("AM") || timeString.contains("PM")) {
        // รูปแบบ "HH:MM AM/PM"
        DateFormat format = DateFormat("hh:mm a");
        DateTime dateTime = format.parse(timeString);
        return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      } else if (timeString.contains(":")) {
        // รูปแบบ "HH:MM"
        List<String> parts = timeString.split(":");
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print("Error parsing time: $e");
    }

    // กรณีแปลงไม่สำเร็จให้ใช้เวลาปัจจุบัน
    return TimeOfDay.now();
  }

  // เพิ่มฟังก์ชันทดสอบการแจ้งเตือนใน EditUserDataPage

  Future<void> _testNotification() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Testing Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('You should receive a notification soon'),
          ],
        ),
      ),
    );

    try {
      await NotificationService().showTestNotification();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test notification sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send test notification: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ฟังก์ชันแสดงตัวเลือกเวลา
  Future<void> _selectTime(BuildContext context, String currentTime,
      Function(String) onTimeSelected) async {
    // แปลงค่าเวลาปัจจุบันให้เป็น TimeOfDay
    TimeOfDay initialTime = currentTime.isNotEmpty
        ? _parseTimeString(currentTime)
        : TimeOfDay.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          // บังคับให้ใช้รูปแบบ 12 ชั่วโมง (AM/PM)
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      // แปลงเวลาให้เป็นรูปแบบ "hh:mm a" (12-hour format with AM/PM)
      final now = DateTime.now();
      final dt =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formattedTime = DateFormat('hh:mm a').format(dt); // เช่น "09:30 PM"

      // อัพเดทค่าด้วย setState เพื่อให้ UI อัพเดททันที
      setState(() {
        onTimeSelected(formattedTime);
      });
    }
  }

 Future<void> _saveUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // แปลง medical condition เป็น suitableFor
      Map<String, bool> suitableFor =
          medicalToSuitable[selectedMedicalCondition] ??
              {
                'healthy': true,
                'diabetes': false,
                'heartDisease': false,
                'highBloodPressure': false
              };

      // บันทึกข้อมูลทั้งหมด
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'breakfastTime': breakfastTime,
        'lunchTime': lunchTime,
        'dinnerTime': dinnerTime,
        'suitableFor': suitableFor,
        'medicalCondition': selectedMedicalCondition,
      }, SetOptions(merge: true));

      // ตั้งเวลาแจ้งเตือนใหม่
      await NotificationService().scheduleAllMealNotifications(
        breakfastTime: breakfastTime,
        lunchTime: lunchTime,
        dinnerTime: dinnerTime,
      );

      // เรียก callback เพื่ออัปเดต UI
      if (widget.onMedicalConditionUpdated != null) {
        widget.onMedicalConditionUpdated!(selectedMedicalCondition);
      }

      Navigator.pop(context); // ปิด loading
      Navigator.pop(context); // กลับหน้าเดิม
    } catch (e) {
      Navigator.pop(context); // ปิด loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // สร้าง widget สำหรับ time selector เพื่อลดโค้ดซ้ำซ้อน
  Widget _buildTimeSelector({
    required String label,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Function(String) onTimeSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(context, time, onTimeSelected),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.isEmpty ? "เลือกเวลา" : time,
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.access_time, color: Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("แก้ไขข้อมูลผู้ใช้"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ไอคอนและหัวข้อด้านบน
              Center(
                child: Column(
                  children: [
                    Icon(Icons.edit_note,
                        size: 56, color: Colors.blue.shade600),
                    SizedBox(height: 8),
                    Text(
                      "แก้ไขข้อมูลการรับประทานอาหาร",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // เวลาอาหาร - ส่วนนี้เป็น Card เดียวกัน
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อ
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Text(
                              "กำหนดเวลารับประทานอาหาร",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // มื้อเช้า
                      _buildTimeSelector(
                        label: "มื้อเช้า",
                        time: breakfastTime,
                        icon: Icons.wb_sunny_outlined,
                        iconColor: Colors.orange,
                        onTimeSelected: (newTime) =>
                            setState(() => breakfastTime = newTime),
                      ),
                      SizedBox(height: 20),

                      // มื้อเที่ยง
                      _buildTimeSelector(
                        label: "มื้อเที่ยง",
                        time: lunchTime,
                        icon: Icons.wb_sunny,
                        iconColor: Colors.orange.shade700,
                        onTimeSelected: (newTime) =>
                            setState(() => lunchTime = newTime),
                      ),
                      SizedBox(height: 20),

                      // มื้อเย็น
                      _buildTimeSelector(
                        label: "มื้อเย็น",
                        time: dinnerTime,
                        icon: Icons.nightlight_round,
                        iconColor: Colors.indigo,
                        onTimeSelected: (newTime) =>
                            setState(() => dinnerTime = newTime),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // ในส่วนของ Card ที่แสดงข้อมูลสุขภาพ
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อ (เดิม)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.health_and_safety,
                                color: Colors.red.shade600),
                            SizedBox(width: 8),
                            Text(
                              "ข้อมูลสุขภาพ",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // โรคประจำตัว
                      Text(
                        "โรคประจำตัว",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),

                      // เพิ่มข้อความแจ้งเตือนหากมีแผนอาหารที่ยังไม่สิ้นสุด
                      if (isMedicalConditionSelected && isMealPlanActive)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "⚠️ ไม่สามารถแก้ไขโรคประจำตัวได้ขณะที่มีแผนอาหารที่ใช้งานอยู่",
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              if (mealPlanEndDate != null)
                                Text(
                                  "สามารถแก้ไขได้หลังจากวันที่ ${DateFormat('d MMMM yyyy', 'th_TH').format(mealPlanEndDate!)}",
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // DropdownButton
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                          color:
                              (isMedicalConditionSelected && isMealPlanActive)
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade50,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMedicalCondition,
                            isExpanded: true,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            borderRadius: BorderRadius.circular(10),
                            items: medicalConditions.map((String condition) {
                              return DropdownMenuItem<String>(
                                value: condition,
                                child: Text(condition),
                              );
                            }).toList(),
                            onChanged:
                                (isMedicalConditionSelected && isMealPlanActive)
                                    ? null
                                    : (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            selectedMedicalCondition = newValue;
                                          });
                                        }
                                      },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),

              // ปุ่มบันทึก
              Center(
                child: Container(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: _saveUserData,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "บันทึกข้อมูล",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),
              Center(
                child: Container(
                  width: 200,
                  child: OutlinedButton.icon(
                    onPressed: _testNotification,
                    icon:
                        Icon(Icons.notifications_active, color: Colors.orange),
                    label: Text(
                      "ทดสอบการแจ้งเตือน",
                      style: TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.orange.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
