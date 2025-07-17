// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meal_selection_page.dart';
import 'package:cached_network_image/cached_network_image.dart';


class MealPlanDisplayPage extends StatefulWidget {
  final bool showAppBar;
  final Function? onBackPressed;
  final String healthCondition; // เพิ่มพารามิเตอร์นี้

  const MealPlanDisplayPage({
    super.key,
    this.showAppBar = true,
    this.onBackPressed,
    required this.healthCondition, // ให้เป็นพารามิเตอร์ที่จำเป็น
  });

  @override
  _MealPlanDisplayPageState createState() => _MealPlanDisplayPageState();
}

class _MealPlanDisplayPageState extends State<MealPlanDisplayPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ข้อมูลแผนอาหาร
  Map<String, dynamic> mealPlanData = {};
  List<Map<String, dynamic>> dailyPlans = [];
  DateTime startDate = DateTime.now();
  bool isLoading = true;
  String? currentMealPlanId;
  String currentHealthCondition = 'healthy'; // ค่าเริ่มต้นเป็นคนสุขภาพดี

  // วันในสัปดาห์ภาษาไทย
  final List<String> thaiDays = [
    'วันอาทิตย์',
    'วันจันทร์',
    'วันอังคาร',
    'วันพุธ',
    'วันพฤหัสบดี',
    'วันศุกร์',
    'วันเสาร์',
  ];

  // ประเภทมื้ออาหาร
  final List<String> mealTypes = ['มื้อเช้า', 'มื้อเที่ยง', 'มื้อเย็น'];
  final List<IconData> mealIcons = [
    Icons.wb_sunny_outlined,
    Icons.wb_sunny,
    Icons.nightlight_round
  ];
  final List<Color> mealIconColors = [
    Colors.orange,
    Colors.orange.shade700,
    Colors.indigo
  ];

// เพิ่มใน initState
  @override
  void initState() {
    super.initState();
    currentHealthCondition = widget.healthCondition;
    print("Health condition from widget: ${widget.healthCondition}");
    print(
        "Converted to database key: ${_getConditionKey(widget.healthCondition)}");

    // ตรวจสอบว่ามีเมนูอาหารอยู่ในฐานข้อมูลหรือไม่
    _checkMenuItems();

    _loadCurrentMealPlan();
  }

// เพิ่มฟังก์ชันใหม่
  Future<void> _checkMenuItems() async {
    try {
      QuerySnapshot menuCount = await _firestore.collection('foodMenus').get();

      print("จำนวนเมนูอาหารทั้งหมดในฐานข้อมูล: ${menuCount.docs.length}");

      if (menuCount.docs.isNotEmpty) {
        // แสดงตัวอย่างเมนูแรก
        DocumentSnapshot firstMenu = menuCount.docs.first;
        print("ตัวอย่างเมนูแรก: ${firstMenu.data()}");
      }
    } catch (e) {
      print("Error checking menu items: $e");
    }
  }

// อัปเดตเมนูอาหาร
// แก้ไขฟังก์ชัน _updateMealMenu
  Future<void> _updateMealMenu(
      int dayIndex, String mealType, Map<String, dynamic> newMenu) async {
    try {
      if (currentMealPlanId == null) {
        throw Exception('ไม่พบ ID ของแผนอาหาร');
      }

      // สร้างข้อมูลเมนูสำหรับการอัปเดต - เพิ่ม imageUrl และ instructions
      Map<String, dynamic> mealData = {
        'menuId': newMenu['id'],
        'name': newMenu['name'],
        'description': newMenu['description'] ?? '',
        'nutritionalInfo': newMenu['nutritionalInfo'] ?? {},
        'ingredients': newMenu['ingredients'] ?? [],
        'imageUrl': newMenu['imageUrl'] ?? '', // เพิ่มฟิลด์ imageUrl
        'instructions': newMenu['instructions'] ?? [] // เพิ่มฟิลด์ instructions
      };

      // อัปเดตในข้อมูลท้องถิ่นก่อน
      if (mounted) {
        setState(() {
          dailyPlans[dayIndex]['meals'][mealType] = mealData;
        });
      }

      // ดึงข้อมูลแผนอาหารปัจจุบันจาก Firestore ก่อน
      DocumentSnapshot docSnapshot =
          await _firestore.collection('mealPlans').doc(currentMealPlanId).get();
      if (!docSnapshot.exists) {
        throw Exception('ไม่พบแผนอาหาร');
      }

      // แก้ไขเฉพาะส่วนที่ต้องการ
      Map<String, dynamic> currentData =
          docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> updatedDailyPlans = List.from(currentData['dailyPlans']);
      updatedDailyPlans[dayIndex]['meals'][mealType] = mealData;

      // อัปเดตแผนอาหารทั้งหมด
      await _firestore
          .collection('mealPlans')
          .doc(currentMealPlanId)
          .update({'dailyPlans': updatedDailyPlans});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เปลี่ยนเมนู${_getMealTypeName(mealType)}สำเร็จ'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error updating meal menu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเปลี่ยนเมนู'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // โหลดแผนอาหารปัจจุบัน
  Future<void> _loadCurrentMealPlan() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print("Current user ID: ${user.uid}");

        // ดึงแผนอาหารที่เป็นปัจจุบันของผู้ใช้
        QuerySnapshot activePlanSnapshot = await _firestore
            .collection('mealPlans')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (activePlanSnapshot.docs.isNotEmpty) {
          print("Found active meal plan");
          DocumentSnapshot planDoc = activePlanSnapshot.docs[0];
          _loadPlanData(planDoc.id, planDoc.data() as Map<String, dynamic>);
        } else {
          print(
              "No active meal plan found, checking if we can create a new plan");

          // สร้างแผนว่างชั่วคราว
          _initializeEmptyMealPlan();

          // ตรวจสอบว่ามีเมนูเพียงพอสำหรับสร้างแผนอาหารหรือไม่
          bool canCreatePlan = await _checkIfEnoughMenuItems();

          if (canCreatePlan) {
            // มีเมนูเพียงพอ สร้างแผนอาหารใหม่
            await _generateNewMealPlan();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'สร้างแผนอาหารใหม่สำหรับผู้${currentHealthCondition == 'healthy' ? 'ไม่มีโรคประจำตัว' : 'มีสภาวะ $currentHealthCondition'}'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            // ไม่มีเมนูเพียงพอ แสดงกล่องข้อความ
            if (mounted) {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ไม่สามารถสร้างแผนอาหารได้'),
                  content: Text(
                      'ไม่มีเมนูอาหารที่เหมาะสมสำหรับผู้มีสภาวะ $currentHealthCondition เพียงพอสำหรับสร้างแผนอาหาร 7 วัน\n\nต้องมีเมนูอย่างน้อย 7 เมนูสำหรับแต่ละมื้อ'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // ปิดกล่องข้อความ

                        // กลับไปหน้าข้อมูลการรับประทานอาหาร
                        if (widget.onBackPressed != null) {
                          widget.onBackPressed!();
                        } else {
                          Navigator.pop(context); // กลับไปหน้าก่อนหน้า
                        }
                      },
                      child: const Text('เข้าใจแล้ว'),
                    ),
                  ],
                ),
              );
            }
          }
        }
      } else {
        print("No user is currently logged in");
        _promptToGeneratePlan();
      }
    } catch (e) {
      print("Error loading meal plan: $e");
      _promptToGeneratePlan();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

// ตรวจสอบว่ามีเมนูเพียงพอสำหรับสร้างแผนอาหารหรือไม่
// แก้ไขฟังก์ชัน _checkIfEnoughMenuItems
  Future<bool> _checkIfEnoughMenuItems() async {
    try {
      String conditionKey = _getConditionKey(currentHealthCondition);
      print("ค้นหาเมนูด้วยคีย์: $conditionKey");

      // ดึงเมนูอาหารสำหรับผู้ป่วยเบาหวาน
      QuerySnapshot breakfastMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'breakfast')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      QuerySnapshot lunchMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'lunch')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      QuerySnapshot dinnerMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'dinner')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      int breakfastCount = breakfastMenusQuery.docs.length;
      int lunchCount = lunchMenusQuery.docs.length;
      int dinnerCount = dinnerMenusQuery.docs.length;

      print("จำนวนเมนูอาหารสำหรับผู้มีสภาวะ $currentHealthCondition:");
      print("มื้อเช้า: $breakfastCount เมนู");
      print("มื้อเที่ยง: $lunchCount เมนู");
      print("มื้อเย็น: $dinnerCount เมนู");

      // ต้องมีอย่างน้อย 7 เมนูสำหรับแต่ละมื้อ
      return breakfastCount >= 7 && lunchCount >= 7 && dinnerCount >= 7;
    } catch (e) {
      print("Error checking menu items: $e");
      return false;
    }
  }

// เพิ่มฟังก์ชันใหม่เพื่อแปลงค่า healthCondition เป็นคีย์ที่ใช้ในฐานข้อมูล
  String _getConditionKey(String condition) {
    // แปลงจากข้อความภาษาไทยหรือคำอธิบายเป็นคีย์ในฐานข้อมูล
    switch (condition.toLowerCase()) {
      case 'ไม่มีโรคประจำตัว':
      case 'ไม่มี':
      case 'healthy':
        return 'healthy';
      case 'เบาหวาน':
      case 'โรคเบาหวาน':
      case 'diabetes':
        return 'diabetes';
      case 'ความดันโลหิตสูง':
      case 'โรคความดันโลหิตสูง': // เพิ่มเคสนี้
      case 'high blood pressure':
      case 'highbloodpressure':
        return 'highBloodPressure';
      case 'โรคหัวใจ':
      case 'heart disease':
      case 'heartdisease':
        return 'heartDisease';
      default:
        print("ไม่พบคีย์ที่ตรงกับสภาวะ '$condition' ใช้ 'healthy' แทน");
        return 'healthy';
    }
  }

  // แสดงกล่องข้อความแนะนำให้สร้างแผนอาหารใหม่
  void _promptToGeneratePlan() {
    // แสดงข้อความกล่องแจ้งเตือนเมื่อไม่พบแผนอาหาร
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ไม่พบแผนอาหาร'),
            content: const Text(
                'ไม่พบแผนอาหารที่ใช้งานอยู่ ต้องการสร้างแผนอาหารใหม่หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _generateNewMealPlan();
                },
                child: const Text('สร้างแผนอาหารใหม่'),
              ),
            ],
          ),
        );
      });
    }

    // เริ่มต้นด้วยแผนอาหารว่างไว้ก่อน
    _initializeEmptyMealPlan();
  }

  // โหลดข้อมูลแผนอาหาร
  void _loadPlanData(String planId, Map<String, dynamic> planData) {
    try {
      print("📌 กำลังโหลดแผนอาหาร... ID: $planId");

      // บันทึก ID ของแผนอาหารปัจจุบัน
      currentMealPlanId = planId;

      // เก็บข้อมูลแผนอาหารทั้งหมด
      mealPlanData = planData;

      // ดึงข้อมูลสภาวะสุขภาพ
      currentHealthCondition = planData['healthCondition'] ?? 'healthy';

      // ดึงวันที่เริ่มต้น
      if (planData.containsKey('startDate')) {
        Timestamp startTimestamp = planData['startDate'] as Timestamp;
        startDate = startTimestamp.toDate();
        print("📆 วันที่เริ่มต้น: $startDate");
      }

      // ดึงข้อมูลแผนรายวัน
      if (planData.containsKey('dailyPlans')) {
        List<dynamic> rawDailyPlans = planData['dailyPlans'] as List<dynamic>;
        dailyPlans =
            rawDailyPlans.map((plan) => plan as Map<String, dynamic>).toList();
        print("🍽 จำนวนวันในแผนอาหาร: ${dailyPlans.length}");
      } else {
        print("⚠️ ไม่พบข้อมูล dailyPlans ในแผนอาหาร");
        dailyPlans = [];
      }
    } catch (e) {
      print("❌ เกิดข้อผิดพลาดใน _loadPlanData: $e");
      _initializeEmptyMealPlan();
    }
  }

  // สร้างแผนอาหารว่างในกรณีที่ยังไม่มีข้อมูล
  void _initializeEmptyMealPlan() {
    dailyPlans = [];
    for (var i = 0; i < 7; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      String dayName = thaiDays[currentDate.weekday % 7];

      dailyPlans.add({
        'date': Timestamp.fromDate(currentDate),
        'dayName': dayName,
        'meals': {
          'breakfast': {
            'name': 'ยังไม่ได้กำหนด',
          },
          'lunch': {
            'name': 'ยังไม่ได้กำหนด',
          },
          'dinner': {
            'name': 'ยังไม่ได้กำหนด',
          }
        },
        'completed': {'breakfast': false, 'lunch': false, 'dinner': false}
      });
    }
  }

  // สร้างแผนอาหารใหม่
  Future<void> _generateNewMealPlan() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กำลังตรวจสอบเมนูอาหาร...'),
            duration: Duration(seconds: 2),
          ),
        );

        // ดึงเมนูอาหารสำหรับผู้ป่วยเบาหวาน
        QuerySnapshot breakfastMenusQuery = await _firestore
            .collection('foodMenus')
            .where('mealType', isEqualTo: 'breakfast')
            .where('suitableFor.diabetes', isEqualTo: true)
            .get();

        QuerySnapshot lunchMenusQuery = await _firestore
            .collection('foodMenus')
            .where('mealType', isEqualTo: 'lunch')
            .where('suitableFor.diabetes', isEqualTo: true)
            .get();

        QuerySnapshot dinnerMenusQuery = await _firestore
            .collection('foodMenus')
            .where('mealType', isEqualTo: 'dinner')
            .where('suitableFor.diabetes', isEqualTo: true)
            .get();

        // แปลงเป็นรายการเมนูอาหาร
        List<Map<String, dynamic>> breakfastMenus = breakfastMenusQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();

        List<Map<String, dynamic>> lunchMenus = lunchMenusQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();

        List<Map<String, dynamic>> dinnerMenus = dinnerMenusQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();

        // ตรวจสอบว่ามีเมนูเพียงพอหรือไม่
        if (breakfastMenus.length < 7 ||
            lunchMenus.length < 7 ||
            dinnerMenus.length < 7) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'ไม่มีเมนูเพียงพอสำหรับผู้มีสภาวะ $currentHealthCondition กรุณาเพิ่มเมนูอาหารก่อน'),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        // สร้างแผนอาหารใหม่
        await _createMealPlanInFirestore(user.uid, currentHealthCondition);

        // โหลดแผนอาหารที่สร้างใหม่
        await _loadCurrentMealPlan();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สร้างแผนอาหารใหม่สำเร็จ'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error generating meal plan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการสร้างแผนอาหาร: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // จำลองการสร้างแผนอาหารใน Firestore (ในการใช้งานจริงควรเรียกผ่าน Cloud Functions)
  Future<void> _createMealPlanInFirestore(
      String userId, String healthCondition) async {
    try {
      // แปลงค่า healthCondition เป็นคีย์ที่ใช้จริงในฐานข้อมูล
      String conditionKey = _getConditionKey(healthCondition);
      print(
          "Creating meal plan with condition: $healthCondition (key: $conditionKey)");

      // ตรวจสอบอีกครั้งว่ามีเมนูเพียงพอหรือไม่
      bool hasEnoughMenus = await _checkIfEnoughMenuItems();
      if (!hasEnoughMenus) {
        throw Exception(
            'ไม่มีเมนูเพียงพอสำหรับสร้างแผนอาหาร 7 วัน กรุณาเพิ่มเมนูอาหาร');
      }

      // ดึงเมนูอาหารตามสภาวะสุขภาพ
      QuerySnapshot breakfastMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'breakfast')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      QuerySnapshot lunchMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'lunch')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      QuerySnapshot dinnerMenusQuery = await _firestore
          .collection('foodMenus')
          .where('mealType', isEqualTo: 'dinner')
          .where('suitableFor.$conditionKey', isEqualTo: true)
          .get();

      // ถ้าไม่พบเมนูเพียงพอ ลองใช้เมนูสำหรับ healthy แทน
      if (breakfastMenusQuery.docs.length < 7 ||
          lunchMenusQuery.docs.length < 7 ||
          dinnerMenusQuery.docs.length < 7) {
        if (conditionKey != "healthy") {
          conditionKey = "healthy";
          print("ใช้เมนูสำหรับผู้มีสุขภาพดีแทน");

          breakfastMenusQuery = await _firestore
              .collection('foodMenus')
              .where('mealType', isEqualTo: 'breakfast')
              .where('suitableFor.healthy', isEqualTo: true)
              .get();

          lunchMenusQuery = await _firestore
              .collection('foodMenus')
              .where('mealType', isEqualTo: 'lunch')
              .where('suitableFor.healthy', isEqualTo: true)
              .get();

          dinnerMenusQuery = await _firestore
              .collection('foodMenus')
              .where('mealType', isEqualTo: 'dinner')
              .where('suitableFor.healthy', isEqualTo: true)
              .get();
        }
      }

      // แปลงเป็นรายการเมนูอาหาร
      List<Map<String, dynamic>> breakfastMenus = breakfastMenusQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      List<Map<String, dynamic>> lunchMenus = lunchMenusQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      List<Map<String, dynamic>> dinnerMenus = dinnerMenusQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      // สลับลำดับเมนูแบบสุ่ม
      breakfastMenus.shuffle();
      lunchMenus.shuffle();
      dinnerMenus.shuffle();

      // สร้างวันที่เริ่มต้นและสิ้นสุด
      DateTime newStartDate = DateTime.now();
      DateTime endDate = newStartDate.add(const Duration(days: 6));

      // สร้างแผนอาหารรายวัน
      List<Map<String, dynamic>> newDailyPlans = [];

      for (var i = 0; i < 7; i++) {
        DateTime planDate = newStartDate.add(Duration(days: i));
        int dayOfWeek = planDate.weekday % 7;

        newDailyPlans.add({
          'date': Timestamp.fromDate(planDate),
          'dayName': thaiDays[dayOfWeek],
          'meals': {
            'breakfast': {
              'menuId': breakfastMenus[i]['id'],
              'name': breakfastMenus[i]['name'],
              'description': breakfastMenus[i]['description'] ?? '',
              'nutritionalInfo': breakfastMenus[i]['nutritionalInfo'] ?? {},
              'ingredients': breakfastMenus[i]['ingredients'] ?? [],
              'imageUrl':
                  breakfastMenus[i]['imageUrl'] ?? '', // เพิ่มฟิลด์ imageUrl
              'instructions': breakfastMenus[i]['instructions'] ??
                  [] // เพิ่มฟิลด์ instructions
            },
            'lunch': {
              'menuId': lunchMenus[i]['id'],
              'name': lunchMenus[i]['name'],
              'description': lunchMenus[i]['description'] ?? '',
              'nutritionalInfo': lunchMenus[i]['nutritionalInfo'] ?? {},
              'ingredients': lunchMenus[i]['ingredients'] ?? [],
              'imageUrl':
                  lunchMenus[i]['imageUrl'] ?? '', // เพิ่มฟิลด์ imageUrl
              'instructions':
                  lunchMenus[i]['instructions'] ?? [] // เพิ่มฟิลด์ instructions
            },
            'dinner': {
              'menuId': dinnerMenus[i]['id'],
              'name': dinnerMenus[i]['name'],
              'description': dinnerMenus[i]['description'] ?? '',
              'nutritionalInfo': dinnerMenus[i]['nutritionalInfo'] ?? {},
              'ingredients': dinnerMenus[i]['ingredients'] ?? [],
              'imageUrl':
                  dinnerMenus[i]['imageUrl'] ?? '', // เพิ่มฟิลด์ imageUrl
              'instructions': dinnerMenus[i]['instructions'] ??
                  [] // เพิ่มฟิลด์ instructions
            }
          },
          'completed': {'breakfast': false, 'lunch': false, 'dinner': false}
        });
      }

      // สร้างเอกสารแผนอาหารใหม่
      Map<String, dynamic> newMealPlan = {
        'userId': userId,
        'startDate': Timestamp.fromDate(newStartDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
        'healthCondition': healthCondition,
        'description':
            'แผนอาหารสำหรับผู้ที่${healthCondition == 'healthy' ? 'ไม่มีโรคประจำตัว' : 'มีสภาวะ $healthCondition'}',
        'dailyPlans': newDailyPlans,
        'isActive': true
      };

      // บันทึกแผนอาหารใน Firestore
      DocumentReference newPlanRef =
          await _firestore.collection('mealPlans').add(newMealPlan);
      print("สร้างแผนอาหารใหม่สำเร็จ ID: ${newPlanRef.id}");
    } catch (e) {
      print("เกิดข้อผิดพลาดในการสร้างแผนอาหาร: $e");
      rethrow;
    }
  }

  // อัปเดตสถานะการทานอาหาร
  // อัปเดตสถานะการทานอาหาร
  Future<void> _updateMealCompletion(
      int dayIndex, String mealType, bool isCompleted) async {
    try {
      if (currentMealPlanId == null) {
        throw Exception('ไม่พบ ID ของแผนอาหาร');
      }

      // อัปเดตในข้อมูลท้องถิ่นก่อน
      if (mounted) {
        setState(() {
          dailyPlans[dayIndex]['completed'][mealType] = isCompleted;
        });
      }

      // ดึงข้อมูลแผนอาหารปัจจุบันจาก Firestore ก่อน
      DocumentSnapshot docSnapshot =
          await _firestore.collection('mealPlans').doc(currentMealPlanId).get();
      if (!docSnapshot.exists) {
        throw Exception('ไม่พบแผนอาหาร');
      }

      // แก้ไขเฉพาะส่วนที่ต้องการ
      Map<String, dynamic> currentData =
          docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> updatedDailyPlans = List.from(currentData['dailyPlans']);
      updatedDailyPlans[dayIndex]['completed'][mealType] = isCompleted;

      // อัปเดตแผนอาหารทั้งหมด
      await _firestore
          .collection('mealPlans')
          .doc(currentMealPlanId)
          .update({'dailyPlans': updatedDailyPlans});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCompleted
              ? 'บันทึกการทาน${_getMealTypeName(mealType)}สำเร็จ'
              : 'ยกเลิกการทาน${_getMealTypeName(mealType)}สำเร็จ'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error updating meal completion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'เกิดข้อผิดพลาดในการบันทึกสถานะการทานอาหาร: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // กู้คืนสถานะเดิมในกรณีที่เกิดข้อผิดพลาด
      if (mounted) {
        setState(() {
          dailyPlans[dayIndex]['completed'][mealType] = !isCompleted;
        });
      }
    }
  }

  // แปลงชื่อมื้อเป็นภาษาไทย
  String _getMealTypeName(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'มื้อเช้า';
      case 'lunch':
        return 'มื้อเที่ยง';
      case 'dinner':
        return 'มื้อเย็น';
      default:
        return 'อาหาร';
    }
  }

  // แสดงเนื้อหาแผนอาหาร
  Widget _BuildMealPlanContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateHeader(),
          const SizedBox(height: 16),
          // ปุ่มสร้างแผนอาหารใหม่
          ElevatedButton.icon(
            onPressed: _generateNewMealPlan,
            icon: const Icon(Icons.refresh),
            label: const Text('สร้างแผนอาหารใหม่'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // ใช้ for loop สร้าง widget สำหรับแต่ละวัน
          for (int i = 0; i < dailyPlans.length; i++) _buildDaySection(i),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    DateTime endDate = startDate.add(const Duration(days: 6));
    String startDateText = DateFormat('d MMMM yyyy', 'th_TH').format(startDate);
    String endDateText = DateFormat('d MMMM yyyy', 'th_TH').format(endDate);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'แผนอาหาร 7 วัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$startDateText - $endDateText',
              style: const TextStyle(fontSize: 16),
            ),
            if (currentHealthCondition != 'healthy')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'สำหรับผู้มีสภาวะ $currentHealthCondition',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // สร้าง Widget แสดงแผนอาหารรายวัน
  Widget _buildDaySection(int dayIndex) {
    Map<String, dynamic> dayPlan = dailyPlans[dayIndex];
    DateTime planDate = (dayPlan['date'] as Timestamp).toDate();
    String dayName = dayPlan['dayName'];
    String formattedDate = DateFormat('d MMMM yyyy', 'th_TH').format(planDate);

    // เช็คว่าวันนี้เป็นวันปัจจุบันหรือไม่
    bool isToday = DateUtils.isSameDay(planDate, DateTime.now());

    // เริ่มต้นให้วันปัจจุบันขยาย
    bool isExpanded = isToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: isToday
          ? BoxDecoration(
              border: Border.all(color: Colors.blue.shade300, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(
              horizontal: 16), // ปรับ padding ของหัวข้อ
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none, // เอาเส้นขอบของ ExpansionTile ออก
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none, // เอาเส้นขอบเมื่อปิดออก
          ),
          title: Text(
            '$dayName ${isToday ? "(วันนี้)" : ""}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isToday ? Colors.blue.shade700 : null,
            ),
          ),
          subtitle: Text(formattedDate),
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Rest of your code remains the same
                  _buildMealRow(
                    dayIndex: dayIndex,
                    icon: Icons.wb_sunny_outlined,
                    iconColor: Colors.orange,
                    mealType: 'breakfast',
                    mealName: 'มื้อเช้า',
                    mealContent: dayPlan['meals']['breakfast']['name'],
                    isCompleted: dayPlan['completed']['breakfast'] ?? false,
                  ),
                  const Divider(),
                  _buildMealRow(
                    dayIndex: dayIndex,
                    icon: Icons.wb_sunny,
                    iconColor: Colors.orange.shade700,
                    mealType: 'lunch',
                    mealName: 'มื้อเที่ยง',
                    mealContent: dayPlan['meals']['lunch']['name'],
                    isCompleted: dayPlan['completed']['lunch'] ?? false,
                  ),
                  const Divider(),
                  _buildMealRow(
                    dayIndex: dayIndex,
                    icon: Icons.nightlight_round,
                    iconColor: Colors.indigo,
                    mealType: 'dinner',
                    mealName: 'มื้อเย็น',
                    mealContent: dayPlan['meals']['dinner']['name'],
                    isCompleted: dayPlan['completed']['dinner'] ?? false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // สร้าง Widget แสดงข้อมูลมื้ออาหาร
Widget _buildMealRow({
  required int dayIndex,
  required IconData icon,
  required Color iconColor,
  required String mealType,
  required String mealName,
  required String mealContent,
  required bool isCompleted,
}) {
  // ดึงข้อมูลเมนูเพิ่มเติม
  Map<String, dynamic> mealData = dailyPlans[dayIndex]['meals'][mealType];
  String imageUrl = mealData['imageUrl'] ?? '';

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        // ไอคอนมื้ออาหาร - ย้ายไปด้านขวาแล้ว
        // ชื่อมื้อและเมนู
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mealContent,
                style: TextStyle(
                  color: mealContent == 'ยังไม่ได้กำหนด'
                      ? Colors.grey
                      : isCompleted
                          ? Colors.green
                          : Colors.black87,
                  fontWeight: isCompleted ? FontWeight.bold : null,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),

        // รูปภาพเมนู (ถ้ามี)
// ในส่วน _buildMealRow
if (imageUrl.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 40,
          height: 40,
          color: Colors.grey.shade200,
        ),
        errorWidget: (context, url, error) => Container(
          width: 40,
          height: 40,
          color: Colors.grey.shade200,
          child: Icon(Icons.fastfood, size: 20),
        ),
      ),
    ),
  ),

        // ไอคอนมื้ออาหาร (ย้ายมาอยู่ด้านขวา)
        Container(
          width: 32, // ปรับขนาดให้เล็กลง
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18), // ปรับขนาดไอคอน
        ),
        const SizedBox(width: 8),

        // ปุ่มเช็คว่าทานแล้วหรือยัง
        SizedBox(
          width: 32, // กำหนดขนาดให้เท่ากับไอคอนมื้ออาหาร
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero, // ลบ padding เพื่อให้ไอคอนเต็มขนาด
            icon: Icon(
              isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              size: 24, // ปรับขนาดไอคอน
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              _updateMealCompletion(dayIndex, mealType, !isCompleted);
            },
          ),
        ),

        // ปุ่มดูรายละเอียด
        SizedBox(
          width: 32, // กำหนดขนาดให้เท่ากับไอคอนมื้ออาหาร
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero, // ลบ padding เพื่อให้ไอคอนเต็มขนาด
            icon: const Icon(Icons.info_outline, size: 18),
            color: Colors.blue,
            onPressed: () {
              _showMealDetails(dayIndex, mealType);
            },
          ),
        ),
      ],
    ),
  );
}

  // นำทางไปหน้าเลือกเมนูอาหาร
  void _navigateToMealSelection(int dayIndex, String mealType) async {
    Map<String, dynamic> dayPlan = dailyPlans[dayIndex];
    String? currentMealId = dayPlan['meals'][mealType]?['menuId'];

    final selectedMenu = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSelectionPage(
          healthCondition:
              currentHealthCondition, // เปลี่ยนจาก healthCondition เป็น currentHealthCondition
          mealType: mealType,
          currentMealId: currentMealId ?? '',
          mealPlanId: currentMealPlanId ??
              '', // เปลี่ยนจาก mealPlanId เป็น currentMealPlanId
          dayIndex: dayIndex,
        ),
      ),
    );

    if (selectedMenu != null) {
      _updateMealMenu(dayIndex, mealType, selectedMenu);
    }
  }

  // แสดงรายละเอียดของเมนูอาหาร
  void _showMealDetails(int dayIndex, String mealType) {
    Map<String, dynamic> meal = dailyPlans[dayIndex]['meals'][mealType];
    String mealName = meal['name'] ?? 'ไม่มีข้อมูล';
    String description = meal['description'] ?? 'ไม่มีคำอธิบาย';
    List<dynamic> ingredients = meal['ingredients'] ?? [];
    String imageUrl = meal['imageUrl'] ?? '';
    List<dynamic> instructions = meal['instructions'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      mealName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // มื้ออาหาร
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getMealTypeName(mealType),
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),

if (imageUrl.isNotEmpty) ...[
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: CachedNetworkImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: double.infinity,
        height: 180,
        color: Colors.grey.shade200,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        width: double.infinity,
        height: 180,
        color: Colors.grey.shade200,
        child: Center(
          child: Text('ไม่สามารถโหลดรูปภาพได้'),
        ),
      ),
    ),
  ),
  const SizedBox(height: 16),
],

              // คำอธิบาย
              const Text(
                'คำอธิบาย',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 20),

              // ส่วนประกอบ
              if (ingredients.isNotEmpty) ...[
                const Text(
                  'ส่วนประกอบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...ingredients.map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.fiber_manual_record,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ingredient is String
                                ? ingredient
                                : ingredient['name'] ?? 'ไม่ระบุ',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // ขั้นตอนการทำอาหาร (เพิ่มใหม่)
              if (instructions.isNotEmpty) ...[
                const Text(
                  'วิธีทำ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(instructions.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            instructions[index],
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              // คุณค่าทางอาหาร
              if (meal['nutritionalInfo'] != null &&
                  (meal['nutritionalInfo'] as Map).isNotEmpty) ...[
                const Text(
                  'คุณค่าทางอาหาร',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNutritionalInfo(meal['nutritionalInfo']),
              ],

              const SizedBox(height: 12),

              // ปุ่มเปลี่ยนเมนู
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // ปิด modal ปัจจุบัน
                    _navigateToMealSelection(dayIndex, mealType);
                  },
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('เปลี่ยนเมนู'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ปุ่มทานอาหารเสร็จแล้ว
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    bool currentStatus =
                        dailyPlans[dayIndex]['completed'][mealType] ?? false;
                    _updateMealCompletion(dayIndex, mealType, !currentStatus);
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    dailyPlans[dayIndex]['completed'][mealType] ?? false
                        ? Icons.close
                        : Icons.check,
                  ),
                  label: Text(
                    dailyPlans[dayIndex]['completed'][mealType] ?? false
                        ? 'ยกเลิกการทานอาหาร'
                        : 'ทานอาหารเสร็จแล้ว',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor:
                        dailyPlans[dayIndex]['completed'][mealType] ?? false
                            ? Colors.red.shade400
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้าง Widget แสดงข้อมูลคุณค่าทางอาหาร
  Widget _buildNutritionalInfo(Map<String, dynamic> nutritionalInfo) {
    final List<MapEntry<String, dynamic>> entries =
        nutritionalInfo.entries.toList();

    return Column(
      children: [
        for (int i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                // คอลัมน์ซ้าย
                Expanded(
                  child: _buildNutrientItem(entries[i].key, entries[i].value),
                ),
                // คอลัมน์ขวา (ถ้ามี)
                if (i + 1 < entries.length)
                  Expanded(
                    child: _buildNutrientItem(
                        entries[i + 1].key, entries[i + 1].value),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // สร้าง Widget สำหรับแสดงข้อมูลสารอาหารแต่ละรายการ
  Widget _buildNutrientItem(String name, dynamic value) {
    // แปลงชื่อสารอาหารเป็นภาษาไทย
    String thaiName = _translateNutrientName(name);

    // แปลงค่าให้อยู่ในรูปแบบที่เหมาะสม
    String formattedValue = value is num
        ? value.toString()
        : value is String
            ? value
            : 'ไม่ระบุ';

    // เพิ่มหน่วยวัดตามชนิดของสารอาหาร
    String unit = _getNutrientUnit(name);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.green.shade200,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$thaiName: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: '$formattedValue $unit',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // แปลงชื่อสารอาหารเป็นภาษาไทย
  String _translateNutrientName(String name) {
    switch (name.toLowerCase()) {
      case 'calories':
        return 'แคลอรี่';
      case 'protein':
        return 'โปรตีน';
      case 'carbs':
        return 'คาร์โบไฮเดรต';
      case 'fat':
        return 'ไขมัน';
      case 'sugar':
        return 'น้ำตาล';
      case 'fiber':
        return 'ใยอาหาร';
      case 'sodium':
        return 'โซเดียม';
      case 'cholesterol':
        return 'คอเลสเตอรอล';
      default:
        // คืนค่าชื่อเดิมถ้าไม่รู้จัก
        return name;
    }
  }

  // กำหนดหน่วยวัดตามชนิดของสารอาหาร
  String _getNutrientUnit(String name) {
    switch (name.toLowerCase()) {
      case 'calories':
        return 'kcal';
      case 'protein':
      case 'carbs':
      case 'fat':
      case 'sugar':
      case 'fiber':
        return 'g';
      case 'sodium':
        return 'mg';
      case 'cholesterol':
        return 'mg';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('แผนอาหารของคุณ'),
              leading: widget.onBackPressed != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (widget.onBackPressed != null) {
                          widget.onBackPressed!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadCurrentMealPlan,
                  tooltip: 'รีเฟรชข้อมูล',
                ),
              ],
            )
          : null,
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังโหลดแผนอาหาร...')
                ],
              ),
            )
          : _BuildMealPlanContent(),
    );
  }
}
