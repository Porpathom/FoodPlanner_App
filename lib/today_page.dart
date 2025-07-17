// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meal_selection_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';
import 'dart:async'; // สำหรับ StreamSubscription
import 'package:cached_network_image/cached_network_image.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? healthConditionImage;

  bool isLoading = true;
  Map<String, dynamic>? todayMealPlan;
  String healthCondition = "healthy";
  String? currentMealPlanId;
  int? todayDayIndex;

  StreamSubscription<NotificationEvent>? _notificationSubscription;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  // เพิ่มตัวแปรเพื่อป้องกันการอัปเดต state หลายครั้งพร้อมกัน
  bool _isUpdating = false;

  // เพิ่มตัวแปรเพื่อติดตาม notification events ที่ได้รับแล้ว
  Set<String> _processedNotificationEvents = {};

// ใน _TodayPageState
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH', null).then((_) {
      _loadTodayMealPlan();
    });
    _loadHealthConditionImage();

    // ย้ายการตั้งค่า notification listener มาไว้ที่นี่
    _notificationSubscription = NotificationService()
        .notificationStream
        .listen(_handleNotificationEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodayMealPlan();
      await NotificationService().init();
    });
  }

  void _handleNotificationEvent(NotificationEvent event) {
    final eventKey = event.eventId;

    if (_processedNotificationEvents.contains(eventKey)) {
      return;
    }

    _processedNotificationEvents.add(eventKey);

    if (event.type == 'meal_completed') {
      if (mounted) {
        setState(() {
          if (todayMealPlan != null && todayMealPlan!['completed'] != null) {
            todayMealPlan!['completed'][event.mealType] = true;
          }
        });
      }
    }

    // นำทางไปหน้า TodayPage ถ้ายังไม่อยู่ในหน้านั้น
    if (ModalRoute.of(context)?.settings.name != '/today') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/today',
          (route) => false,
        );
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  void _loadHealthConditionImage() {
    setState(() {
      // แปลงเป็นตัวพิมพ์เล็กและลบช่องว่างเพื่อให้แมปได้ถูกต้อง
      String condition = healthCondition.toLowerCase().trim();

      switch (condition) {
        case 'diabetes':
        case 'โรคเบาหวาน':
          healthConditionImage =
              'assets/diabetes_tips.png'; // เปลี่ยนเป็น .png หรือนามสกุลไฟล์จริง
          break;
        case 'hypertension':
        case 'highbloodpressure':
        case 'โรคความดันโลหิตสูง':
          healthConditionImage = 'assets/hypertension_tips.png';
          break;
        case 'heart disease':
        case 'heartdisease':
        case 'โรคหัวใจ':
          healthConditionImage = 'assets/heart_disease_tips.png';
          break;
        default:
          healthConditionImage = null;
      }
    });
  }

  Future<void> _loadTodayMealPlan() async {
    if (_isUpdating) return; // ป้องกันการโหลดซ้ำ

    setState(() => isLoading = true);
    _isUpdating = true;

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot activePlanSnapshot = await _firestore
            .collection('mealPlans')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (activePlanSnapshot.docs.isNotEmpty) {
          DocumentSnapshot planDoc = activePlanSnapshot.docs[0];
          currentMealPlanId = planDoc.id;

          // โหลดข้อมูลทันทีโดยไม่รอ listener
          await _updateTodayMealPlanFromSnapshot(planDoc);
          _setupFirestoreListener();
        }
      }
    } catch (e) {
      debugPrint("Error loading meal plan: $e");
    } finally {
      _isUpdating = false;
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateTodayMealPlanFromSnapshot(
      DocumentSnapshot planDoc) async {
    if (!mounted) return;

    try {
      Map<String, dynamic> planData = planDoc.data() as Map<String, dynamic>;

      // ตรวจสอบและอัปเดต health condition
      String newHealthCondition = planData['healthCondition'] ?? 'healthy';
      if (newHealthCondition != healthCondition) {
        setState(() => healthCondition = newHealthCondition);
        _loadHealthConditionImage();
      }

      if (planData.containsKey('dailyPlans')) {
        List<dynamic> dailyPlans = planData['dailyPlans'];
        DateTime today = DateTime.now();

        for (int i = 0; i < dailyPlans.length; i++) {
          var dayPlan = dailyPlans[i];
          if (dayPlan['date'] != null &&
              DateUtils.isSameDay(dayPlan['date'].toDate(), today)) {
            setState(() {
              todayMealPlan = Map<String, dynamic>.from(dayPlan);
              todayDayIndex = i;
            });
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error updating plan: $e");
    }
  }

  // เพิ่มฟังก์ชันตั้งค่า Firestore listener
  void _setupFirestoreListener() {
    if (currentMealPlanId != null) {
      _firestoreSubscription?.cancel(); // ยกเลิกตัวเก่าก่อน

      _firestoreSubscription = _firestore
          .collection('mealPlans')
          .doc(currentMealPlanId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        if (snapshot.exists && mounted) {
          print("🔄 Firestore data changed, updating...");
          _updateTodayMealPlanFromSnapshot(snapshot);
        }
      }, onError: (error) {
        print("Firestore listener error: $error");
      });
    }
  }

  Future<void> _updateMealMenu(
      String mealType, Map<String, dynamic> newMenu) async {
    try {
      if (currentMealPlanId == null || todayDayIndex == null) {
        throw Exception('ไม่พบ ID ของแผนอาหารหรือดัชนีของวัน');
      }

      print("กำลังอัปเดตเมนู $mealType ที่ index: $todayDayIndex");

      // สร้างข้อมูลเมนูใหม่
      Map<String, dynamic> mealData = {
        'menuId': newMenu['id'],
        'name': newMenu['name'],
        'description': newMenu['description'] ?? '',
        'nutritionalInfo': newMenu['nutritionalInfo'] ?? {},
        'ingredients': newMenu['ingredients'] ?? [],
        'imageUrl': newMenu['imageUrl'] ?? '',
        'instructions': newMenu['instructions'] ?? [],
      };

      // ดึงข้อมูลแผนอาหารปัจจุบันจาก Firestore
      DocumentSnapshot docSnapshot =
          await _firestore.collection('mealPlans').doc(currentMealPlanId).get();
      if (!docSnapshot.exists) {
        throw Exception('ไม่พบแผนอาหาร');
      }

      // อัปเดตข้อมูลใน Firestore โดยตรง
      Map<String, dynamic> currentData =
          docSnapshot.data() as Map<String, dynamic>;
      List<dynamic> updatedDailyPlans = List.from(currentData['dailyPlans']);
      updatedDailyPlans[todayDayIndex!]['meals'][mealType] = mealData;

      await _firestore
          .collection('mealPlans')
          .doc(currentMealPlanId)
          .update({'dailyPlans': updatedDailyPlans});

      // แจ้งเตือนผู้ใช้
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนเมนู${_getMealTypeName(mealType)}สำเร็จ'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // หมายเหตุ: ไม่ต้องอัปเดต state ด้วยตนเอง เพราะ Firestore listener จะทำให้
    } catch (e) {
      print("Error updating meal menu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเปลี่ยนเมนู: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // โหลดข้อมูลใหม่ในกรณีเกิดข้อผิดพลาด
      await _loadTodayMealPlan();
    }
  }

  Future<void> _forceRefreshData() async {
    if (currentMealPlanId != null) {
      try {
        DocumentSnapshot docSnapshot = await _firestore
            .collection('mealPlans')
            .doc(currentMealPlanId)
            .get();
        if (docSnapshot.exists) {
          await _updateTodayMealPlanFromSnapshot(docSnapshot);
        }
      } catch (e) {
        print("Error force refreshing data: $e");
      }
    }
  }

  // ฟังก์ชันหลักสำหรับการอัปเดต meal completion
// แทนที่ฟังก์ชัน _updateMealCompletion เดิมด้วยโค้ดนี้
Future<void> _updateMealCompletion(String mealType, bool isCompleted) async {
  // ป้องกันการทำงานซ้ำ
  if (_isUpdating) {
    print("⚠️ Already updating, skipping...");
    return;
  }

  try {
    _isUpdating = true;
    print("=== DEBUG Meal Completion Update ===");
    print("Meal Type: $mealType");
    print("Is Completed: $isCompleted");
    print("todayMealPlan: ${todayMealPlan != null}");
    print("currentMealPlanId: $currentMealPlanId");
    print("todayDayIndex: $todayDayIndex");
    print("====================================");

    if (todayMealPlan == null ||
        currentMealPlanId == null ||
        todayDayIndex == null) {
      String debugInfo = "Debug: ";
      debugInfo += "todayMealPlan=${todayMealPlan != null}, ";
      debugInfo += "currentMealPlanId=$currentMealPlanId, ";
      debugInfo += "todayDayIndex=$todayDayIndex";

      throw Exception('ไม่พบข้อมูลแผนอาหาร - $debugInfo');
    }

    // ดึงข้อมูลแผนอาหารปัจจุบันจาก Firestore
    DocumentSnapshot docSnapshot = await _firestore
        .collection('mealPlans')
        .doc(currentMealPlanId)
        .get();
    
    if (!docSnapshot.exists) {
      throw Exception('ไม่พบแผนอาหาร');
    }

    // อัปเดตข้อมูล completion status
    Map<String, dynamic> currentData = docSnapshot.data() as Map<String, dynamic>;
    List<dynamic> updatedDailyPlans = List.from(currentData['dailyPlans']);
    
    // อัปเดต completed status
    if (updatedDailyPlans[todayDayIndex!]['completed'] == null) {
      updatedDailyPlans[todayDayIndex!]['completed'] = {};
    }
    updatedDailyPlans[todayDayIndex!]['completed'][mealType] = isCompleted;

    // บันทึกข้อมูลกลับไปยัง Firestore
    await _firestore
        .collection('mealPlans')
        .doc(currentMealPlanId)
        .update({'dailyPlans': updatedDailyPlans});

    print("✅ Successfully updated meal completion status");

    // แสดงข้อความแจ้งเตือน
    if (mounted) {
      HapticFeedback.lightImpact(); // การสั่นเบา ๆ
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCompleted 
              ? 'บันทึกการทาน${_getMealTypeName(mealType)}เรียบร้อยแล้ว'
              : 'ยกเลิกการทาน${_getMealTypeName(mealType)}แล้ว',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    }

    // อัปเดต state ใน UI ทันที (ไม่ต้องรอ Firestore listener)
    if (mounted) {
      setState(() {
        todayMealPlan!['completed'][mealType] = isCompleted;
      });
    }

  } catch (e) {
    debugPrint("❌ Error updating meal completion: $e");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }

    // รีเฟรชข้อมูลจาก Firestore
    await Future.delayed(Duration(milliseconds: 1000));
    await _forceRefreshData();
  } finally {
    _isUpdating = false;
  }
}

  // เพิ่มฟังก์ชันช่วยเหลือในการแปล mealType เป็นชื่อภาษาไทย
  String _getMealTypeName(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'เช้า';
      case 'lunch':
        return 'กลางวัน';
      case 'dinner':
        return 'เย็น';
      default:
        return mealType;
    }
  }

  // เพิ่มฟังก์ชันสำหรับรีเซ็ต processed events เมื่อเปลี่ยนหน้า
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ล้าง processed events เมื่อกลับมาที่หน้านี้
    _processedNotificationEvents.clear();
  }

  // เปิดหน้าเปลี่ยนเมนูอาหาร
  void _navigateToMealSelection(String mealType) async {
    if (todayDayIndex == null || currentMealPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถเปลี่ยนเมนูได้ โปรดลองใหม่อีกครั้ง'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ดึงข้อมูลวันที่และมื้ออาหาร
    Map<String, dynamic> dayPlan = todayMealPlan!;
    String currentMealId = dayPlan['meals'][mealType]['menuId'] ?? '';

    // นำทางไปยังหน้าเลือกเมนูอาหาร
    final selectedMenu = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealSelectionPage(
          healthCondition: healthCondition,
          mealType: mealType,
          currentMealId: currentMealId,
          mealPlanId: currentMealPlanId!,
          dayIndex: todayDayIndex!,
        ),
      ),
    );

    // ตรวจสอบว่ามีการเลือกเมนูใหม่หรือไม่ และตรวจสอบ mounted
    if (mounted && selectedMenu != null) {
      _updateMealMenu(mealType, selectedMenu);
    }
  }

  // แสดงรายละเอียดของเมนูอาหาร
  void _showMealDetails(String mealType) {
    Map<String, dynamic> meal = todayMealPlan!['meals'][mealType];
    String mealName = meal['name'] ?? 'ไม่มีข้อมูล';
    String description = meal['description'] ?? 'ไม่มีคำอธิบาย';
    List<dynamic> ingredients = meal['ingredients'] ?? [];
    List<dynamic> instructions = meal['instructions'] ?? []; // เพิ่มวิธีทำ
    String imageUrl = meal['imageUrl'] ?? ''; // เพิ่ม URL รูปภาพ
    bool isCompleted = todayMealPlan!['completed'][mealType] ?? false;

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

              // แสดงรูปภาพอาหาร
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.error),
                  ),
                ),

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

              // เพิ่มวิธีทำ
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'วิธีทำ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...instructions.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${idx + 1}",
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // คุณค่าทางอาหาร
              if (meal['nutritionalInfo'] != null) ...[
                const Text(
                  'คุณค่าทางอาหาร',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailedNutritionalInfo(meal['nutritionalInfo']),
              ],

              const SizedBox(height: 12),

              // ปุ่มเปลี่ยนเมนู
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // ปิด modal ปัจจุบัน
                    _navigateToMealSelection(mealType);
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
                    bool currentStatus = isCompleted;
                    _updateMealCompletion(mealType, !currentStatus);
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    isCompleted ? Icons.close : Icons.check,
                  ),
                  label: Text(
                    isCompleted ? 'ยกเลิกการทานอาหาร' : 'ทานอาหารเสร็จแล้ว',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor:
                        isCompleted ? Colors.red.shade400 : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้าง Widget แสดงข้อมูลคุณค่าทางอาหาร (สำหรับหน้ารายละเอียด)
  Widget _buildDetailedNutritionalInfo(Map<String, dynamic> nutritionalInfo) {
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
                  child: _buildNutrientDetailItem(
                      entries[i].key, entries[i].value),
                ),
                // คอลัมน์ขวา (ถ้ามี)
                if (i + 1 < entries.length)
                  Expanded(
                    child: _buildNutrientDetailItem(
                        entries[i + 1].key, entries[i + 1].value),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // สร้าง Widget สำหรับแสดงข้อมูลสารอาหารแต่ละรายการ (สำหรับหน้ารายละเอียด)
  Widget _buildNutrientDetailItem(String name, dynamic value) {
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

  // แปลงชื่อมื้อเป็นภาษาไทย

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (todayMealPlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_meals, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              "ไม่พบรายการอาหารวันนี้",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("ไม่พบแผนอาหารสำหรับวันนี้ กรุณาสร้างแผนอาหารใหม่"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("โหลดข้อมูลใหม่"),
              onPressed: _loadTodayMealPlan,
            ),
          ],
        ),
      );
    }

    // ชื่อวันและวันที่
    String dayName = todayMealPlan!['dayName'];
    DateTime planDate = (todayMealPlan!['date'] as Timestamp).toDate();
    String formattedDate = DateFormat('d MMMM yyyy', 'th_TH').format(planDate);

    // ข้อมูลมื้ออาหาร
    Map<String, dynamic> meals = todayMealPlan!['meals'];
    Map<String, dynamic> completed = todayMealPlan!['completed'];

    // รายการไอคอนและสีของมื้ออาหาร
    List<IconData> mealIcons = [
      Icons.wb_sunny_outlined,
      Icons.wb_sunny,
      Icons.nightlight_round
    ];
    List<Color> mealIconColors = [
      Colors.orange,
      Colors.orange.shade700,
      Colors.indigo
    ];

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // ส่วนหัวและวันที่ (โค้ดเดิม)
          Row(
            children: [
              const Icon(Icons.today, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เมนูอาหารวันนี้',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      '$dayName ($formattedDate)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (healthCondition != 'healthy')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    healthCondition,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // เพิ่มส่วนแสดงรูปภาพแนะนำด้านล่างส่วนหัว
          // แสดงรูปภาพแนะนำด้านสุขภาพ
          if (healthConditionImage != null)
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.width * (9 / 16), // 16:9
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: AssetImage(healthConditionImage!),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // รายการมื้ออาหาร (โค้ดเดิม)
          _buildMealCard(
            icon: mealIcons[0],
            iconColor: mealIconColors[0],
            mealType: 'breakfast',
            mealName: 'มื้อเช้า',
            meal: meals['breakfast'],
            isCompleted: completed['breakfast'] ?? false,
          ),
          const SizedBox(height: 16),
          _buildMealCard(
            icon: mealIcons[1],
            iconColor: mealIconColors[1],
            mealType: 'lunch',
            mealName: 'มื้อเที่ยง',
            meal: meals['lunch'],
            isCompleted: completed['lunch'] ?? false,
          ),
          const SizedBox(height: 16),
          _buildMealCard(
            icon: mealIcons[2],
            iconColor: mealIconColors[2],
            mealType: 'dinner',
            mealName: 'มื้อเย็น',
            meal: meals['dinner'],
            isCompleted: completed['dinner'] ?? false,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // สร้างการ์ดแสดงเมนูอาหาร
  Widget _buildMealCard({
    required IconData icon,
    required Color iconColor,
    required String mealType,
    required String mealName,
    required Map<String, dynamic> meal,
    required bool isCompleted,
  }) {
    String menuName = meal['name'] ?? 'ยังไม่ได้กำหนด';
    String description = meal['description'] ?? '';
    String imageUrl = meal['imageUrl'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนหัว (ไอคอน + ชื่อมื้อ + ปุ่มทำเครื่องหมาย)
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    mealName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Checkbox(
                  value: isCompleted,
                  activeColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) {
                    _updateMealCompletion(mealType, value ?? false);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(Icons.error),
                  ),
                ),
              ),

            // ชื่อเมนู
            Text(
              menuName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.green : Colors.black,
              ),
            ),

            // รายละเอียด (ถ้ามี)
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),

            // แสดงสารอาหาร (ถ้ามี)
            if (meal['nutritionalInfo'] != null &&
                meal['nutritionalInfo'] is Map)
              _buildNutritionalInfo(meal['nutritionalInfo']),

            const SizedBox(height: 16),

            // แถวปุ่ม ดูรายละเอียด และ เปลี่ยนเมนู
            Row(
              children: [
                // ปุ่มดูรายละเอียด
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMealDetails(mealType),
                    icon: const Icon(Icons.visibility),
                    label: const Text('ดูรายละเอียด'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ปุ่มเปลี่ยนเมนู
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToMealSelection(mealType),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('เปลี่ยนเมนู'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            // แสดงป้ายกำกับการทานแล้ว
            if (isCompleted)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "ทานแล้ว",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // แสดงข้อมูลสารอาหาร
  Widget _buildNutritionalInfo(Map<String, dynamic> nutritionalInfo) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ข้อมูลสารอาหาร",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (nutritionalInfo['calories'] != null)
                _nutrientItem("แคลอรี่", "${nutritionalInfo['calories']}"),
              if (nutritionalInfo['protein'] != null)
                _nutrientItem("โปรตีน", "${nutritionalInfo['protein']}"),
              if (nutritionalInfo['carbs'] != null)
                _nutrientItem("คาร์โบไฮเดรต", "${nutritionalInfo['carbs']}"),
              if (nutritionalInfo['fat'] != null)
                _nutrientItem("ไขมัน", "${nutritionalInfo['fat']}"),
              if (nutritionalInfo['fiber'] != null)
                _nutrientItem("ใยอาหาร", "${nutritionalInfo['fiber']}"),
              if (nutritionalInfo['sugar'] != null)
                _nutrientItem("น้ำตาล", "${nutritionalInfo['sugar']}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutrientItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          value, // ใช้ค่าเดิมที่มีหน่วยอยู่แล้ว
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
