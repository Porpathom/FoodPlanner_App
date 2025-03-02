// ignore_for_file: prefer_const_constructors_in_immutables, use_key_in_widget_constructors, library_private_types_in_public_api, avoid_print, prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // เพิ่ม package สำหรับจัดรูปแบบเวลา

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

  @override
  void initState() {
    super.initState();
    breakfastTime = widget.breakfastTime;
    lunchTime = widget.lunchTime;
    dinnerTime = widget.dinnerTime;
    
    // ตั้งค่าโรคประจำตัวจากข้อมูลที่มีอยู่
    if (medicalConditions.contains(widget.medicalCondition)) {
      selectedMedicalCondition = widget.medicalCondition;
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
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print("Error parsing time: $e");
    }
    
    // กรณีแปลงไม่สำเร็จให้ใช้เวลาปัจจุบัน
    return TimeOfDay.now();
  }

  // ฟังก์ชันแสดงตัวเลือกเวลา
  Future<void> _selectTime(BuildContext context, String currentTime, Function(String) onTimeSelected) async {
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
    final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    final formattedTime = DateFormat('hh:mm a').format(dt); // เช่น "09:30 PM"
    
    // อัพเดทค่าด้วย setState เพื่อให้ UI อัพเดททันที
    setState(() {
      onTimeSelected(formattedTime);
    });
  }
}

  Future<void> _saveUserData() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      // แสดง loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );
      
      // แปลงจาก medicalCondition เป็น suitableFor
      Map<String, bool> suitableFor = medicalToSuitable[selectedMedicalCondition] ?? {
        'healthy': true,
        'diabetes': false,
        'heartDisease': false,
        'highBloodPressure': false
      };

      // บันทึกข้อมูลไปยัง Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'breakfastTime': breakfastTime,
        'lunchTime': lunchTime,
        'dinnerTime': dinnerTime,
        'suitableFor': suitableFor,
        'medicalCondition': selectedMedicalCondition, // ยังเก็บ medicalCondition ไว้เพื่อความเข้ากันได้กับโค้ดเดิม
      }, SetOptions(merge: true));

      // ปิด loading indicator
      Navigator.pop(context);

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกข้อมูลเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // ส่ง medicalCondition กลับไปยังหน้า MealPlanDisplayPage
      if (widget.onMedicalConditionUpdated != null) {
        widget.onMedicalConditionUpdated!(selectedMedicalCondition);
      }

      // กลับไปยังหน้า MealPlanDisplayPage หลังบันทึกข้อมูล
      Future.delayed(Duration(milliseconds: 1500), () {
        Navigator.pop(context);
      });
    } catch (e) {
      // ปิด loading indicator
      Navigator.pop(context);

      print("Error saving user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(
            context, 
            time, 
            onTimeSelected
          ),
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
                    Icon(Icons.edit_note, size: 56, color: Colors.blue.shade600),
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
                        onTimeSelected: (newTime) => setState(() => breakfastTime = newTime),
                      ),
                      SizedBox(height: 20),
                      
                      // มื้อเที่ยง
                      _buildTimeSelector(
                        label: "มื้อเที่ยง",
                        time: lunchTime,
                        icon: Icons.wb_sunny,
                        iconColor: Colors.orange.shade700,
                        onTimeSelected: (newTime) => setState(() => lunchTime = newTime),
                      ),
                      SizedBox(height: 20),
                      
                      // มื้อเย็น
                      _buildTimeSelector(
                        label: "มื้อเย็น",
                        time: dinnerTime,
                        icon: Icons.nightlight_round,
                        iconColor: Colors.indigo,
                        onTimeSelected: (newTime) => setState(() => dinnerTime = newTime),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // โรคประจำตัว
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
                            Icon(Icons.health_and_safety, color: Colors.red.shade600),
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
                          fontWeight: FontWeight.w500
                        )
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade50,
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
                            onChanged: (String? newValue) {
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
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}