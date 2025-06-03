// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_user_data_page.dart'; // สำหรับกรอกข้อมูล
import 'meal_plan_display_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; // A

class MenuPlanPage extends StatefulWidget {
  @override
  _MenuPlanPageState createState() => _MenuPlanPageState();
}

class _MenuPlanPageState extends State<MenuPlanPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ตัวแปรเก็บข้อมูลผู้ใช้
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool hasData = false; // เพิ่มตัวแปรเช็คว่ามีข้อมูลหรือไม่
  bool _showMealPlanDisplay = false; // เพิ่มตัวแปรควบคุมการแสดงผล

  @override
  void initState() {
    super.initState();
    // Initialize date formatting with Thai locale
    initializeDateFormatting('th_TH', null).then((_) {
      // After locale is initialized, proceed with normal initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_auth.currentUser == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MenuPlanPage()),
          );
        }
      });

      _loadUserData();
      _loadShowMealPlanDisplay();
    });
  }

Future<void> _loadShowMealPlanDisplay() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (mounted) {
    setState(() {
      _showMealPlanDisplay = hasData && (prefs.getBool('showMealPlanDisplay') ?? false);
    });
  }
}

// บันทึกสถานะไปที่ SharedPreferences
  Future<void> _saveShowMealPlanDisplay(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMealPlanDisplay', value);
  }

  Future<void> _loadUserData() async {
    if (!mounted) return; // ตรวจสอบก่อนว่ายัง mounted อยู่หรือไม่

    setState(() {
      isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print("🔥 Loaded data: $data");

          bool dataComplete = data.containsKey('breakfastTime') &&
              data['breakfastTime'] != null &&
              data['breakfastTime'].toString().isNotEmpty &&
              data.containsKey('lunchTime') &&
              data['lunchTime'] != null &&
              data['lunchTime'].toString().isNotEmpty &&
              data.containsKey('dinnerTime') &&
              data['dinnerTime'] != null &&
              data['dinnerTime'].toString().isNotEmpty;

          if (mounted) {
            // ตรวจสอบอีกครั้งก่อนเรียก setState
            setState(() {
              userData = data;
              hasData = dataComplete;
              isLoading = false;
            });
          }

          await _loadShowMealPlanDisplay();
          print(
              "✅ User data loaded successfully: $userData, hasData: $hasData");
        } else {
          if (mounted) {
            setState(() {
              userData = null;
              hasData = false;
              isLoading = false;
              _showMealPlanDisplay = false;
            });
          }
          print("⚠️ User data not found.");
        }
      } else {
        if (mounted) {
          setState(() {
            userData = null;
            hasData = false;
            isLoading = false;
            _showMealPlanDisplay = false;
          });
        }
        print("⚠️ User not logged in.");
      }
    } catch (e) {
      print("❌ Error loading user data: $e");
      if (mounted) {
        setState(() {
          hasData = false;
          isLoading = false;
          _showMealPlanDisplay = false;
        });
      }
    }
  }

Future<void> _navigateToEditPage() async {
  if (!mounted) return;

  print("📌 Navigating to EditUserDataPage...");
  
  try {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditUserDataPage(
          breakfastTime: userData?['breakfastTime'] ?? '',
          lunchTime: userData?['lunchTime'] ?? '',
          dinnerTime: userData?['dinnerTime'] ?? '',
          medicalCondition: userData?['medicalCondition'] ?? 'ไม่มีโรคประจำตัว',
        ),
      ),
    );

    if (!mounted) return;
    
    // โหลดข้อมูลใหม่หลังจากกลับมาจากหน้าแก้ไข
    await _loadUserData();
    
    if (mounted) {
      setState(() {
        _showMealPlanDisplay = false;
      });
    }
    await _saveShowMealPlanDisplay(false);
  } catch (e) {
    print("❌ Error navigating to EditUserDataPage: $e");
  }
}
  // ฟังก์ชันสลับไปยังหน้าวางแผนเมนูอาหาร
  void _showMealPlanner() {
    // ตรวจสอบว่ามีข้อมูลครบถ้วนก่อนจะแสดงหน้าวางแผนเมนู
    if (hasData) {
      setState(() {
        _showMealPlanDisplay = true;
      });
      _saveShowMealPlanDisplay(true);
    } else {
      // แสดงข้อความแจ้งเตือนให้กรอกข้อมูลก่อน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลเวลาทานอาหารก่อนวางแผนเมนู'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ฟังก์ชันกลับจากหน้าวางแผนเมนูอาหาร
  void _goBackFromMealPlanner() {
    setState(() {
      _showMealPlanDisplay = false;
    });
    _saveShowMealPlanDisplay(false);
  }

  @override
  void dispose() {
    // ยกเลิกการทำงานใดๆ ที่อาจเรียก setState() หลังจาก dispose
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // เนื้อหาของหน้า
                  Expanded(
                    child: _showContent(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _showContent() {
    // ถ้าสถานะเป็นแสดงหน้าวางแผนเมนู ให้แสดง MealPlanDisplayPage
    if (_showMealPlanDisplay) {
      return MealPlanDisplayPage(
        showAppBar: false, // ไม่ต้องแสดง AppBar เพราะเราจัดการเองแล้ว
        onBackPressed: _goBackFromMealPlanner,
        healthCondition: userData?['medicalCondition'] ??
            'ไม่มีโรคประจำตัว', // เพิ่มบรรทัดนี้
      );
    }

    // ถ้าไม่มีข้อมูล หรือข้อมูลไม่ครบ
    if (!hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // เพิ่มไอคอนด้านบน
              Icon(
                Icons.restaurant_menu,
                size: 70,
                color: Colors.blue.shade300,
              ),
              const SizedBox(height: 24),

              // กรอบแสดง "ยังไม่มีข้อมูล" ปรับให้ดูดีขึ้น
              Container(
                width: 300,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "ยังไม่มีข้อมูล",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "กรุณาเพิ่มข้อมูลเวลาทานอาหารของคุณ",
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ปุ่ม "เพิ่มข้อมูล" ปรับให้ดูดีขึ้น
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed:
                      _navigateToEditPage, // เปลี่ยนเป็นใช้ _navigateToEditPage
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade600,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text("เพิ่มข้อมูล",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // กรณีมีข้อมูลผู้ใช้ครบถ้วนแล้ว - แสดงในรูปแบบตาราง
    String breakfastTime = userData!['breakfastTime'] ?? 'ไม่มีข้อมูล';
    String lunchTime = userData!['lunchTime'] ?? 'ไม่มีข้อมูล';
    String dinnerTime = userData!['dinnerTime'] ?? 'ไม่มีข้อมูล';
    String medicalCondition = userData!['medicalCondition'] ?? 'ไม่มีข้อมูล';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            // ไอคอนหนังสือและชื่อ
            Icon(Icons.menu_book, size: 56, color: Colors.blue.shade600),
            const SizedBox(height: 16),
            Text(
              "ข้อมูลการรับประทานอาหาร",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 32),

            // ตารางมื้ออาหาร
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // หัวตาราง
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsets.all(14.0),
                              child: Text(
                                "มื้ออาหาร",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsets.all(14.0),
                              child: Text(
                                "เวลา",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // แถวข้อมูล
                    // มื้อเช้า
                    _buildMealRow(
                      icon: Icons.wb_sunny_outlined,
                      iconColor: Colors.orange,
                      mealName: "มื้อเช้า",
                      mealTime: breakfastTime,
                    ),
                    // เส้นคั่น
                    Divider(
                        height: 1, thickness: 1, color: Colors.grey.shade200),
                    // มื้อเที่ยง
                    _buildMealRow(
                      icon: Icons.wb_sunny,
                      iconColor: Colors.orange.shade700,
                      mealName: "มื้อเที่ยง",
                      mealTime: lunchTime,
                    ),
                    // เส้นคั่น
                    Divider(
                        height: 1, thickness: 1, color: Colors.grey.shade200),
                    // มื้อเย็น
                    _buildMealRow(
                      icon: Icons.nightlight_round,
                      iconColor: Colors.indigo,
                      mealName: "มื้อเย็น",
                      mealTime: dinnerTime,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ตารางโรคประจำตัว
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // หัวตาราง
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Text(
                        "โรคประจำตัว",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // ข้อมูลโรคประจำตัว
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.health_and_safety,
                              color: Colors.red, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            medicalCondition,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ปุ่มด้านล่าง
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _navigateToEditPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade600,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("แก้ไขข้อมูล",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _showMealPlanner, // แทนที่ด้วยการเปลี่ยนสถานะใน State
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade600,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("วางแผนเมนูอาหาร",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // เพิ่ม padding ด้านล่าง
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // สร้าง widget แถวข้อมูลมื้ออาหาร เพื่อลดโค้ดซ้ำซ้อน
  Widget _buildMealRow({
    required IconData icon,
    required Color iconColor,
    required String mealName,
    required String mealTime,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 10),
                  Text(mealName, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                mealTime,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
