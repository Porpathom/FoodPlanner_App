// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meal_selection_page.dart';

class TodayPage extends StatefulWidget {
  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool isLoading = true;
  Map<String, dynamic>? todayMealPlan;
  String healthCondition = "healthy";
  String? currentMealPlanId;
  int? todayDayIndex;
  
  @override
  void initState() {
    super.initState();
    _loadTodayMealPlan();
  }
  
  Future<void> _loadTodayMealPlan() async {
  setState(() {
    isLoading = true;
  });
  
  try {
    User? user = _auth.currentUser;
    if (user != null) {
      // ดึงแผนอาหารที่เป็นปัจจุบันของผู้ใช้
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
        Map<String, dynamic> planData = planDoc.data() as Map<String, dynamic>;
        
        // บันทึกสภาวะสุขภาพ
        healthCondition = planData['healthCondition'] ?? 'healthy';
        
        // ดึงข้อมูลแผนรายวัน
        if (planData.containsKey('dailyPlans')) {
          List<dynamic> dailyPlans = planData['dailyPlans'] as List<dynamic>;
          
          // หาวันที่ปัจจุบัน
          DateTime now = DateTime.now();
          todayDayIndex = null; // รีเซ็ตค่า
          
          // หาแผนของวันนี้
          for (int i = 0; i < dailyPlans.length; i++) {
            var dayPlan = dailyPlans[i];
            Timestamp planDate = dayPlan['date'];
            if (DateUtils.isSameDay(planDate.toDate(), now)) {
              setState(() {
                todayMealPlan = dayPlan as Map<String, dynamic>;
                todayDayIndex = i;
              });
              print("พบแผนอาหารของวันนี้ ที่ index: $i"); // เพิ่ม log
              break;
            }
          }
        }
      }
    }
  } catch (e) {
    print("Error loading today's meal plan: $e");
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


Future<void> _updateMealMenu(String mealType, Map<String, dynamic> newMenu) async {
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
      'ingredients': newMenu['ingredients'] ?? []
    };

    // อัปเดตข้อมูลในตัวแปร state ก่อน
    setState(() {
      todayMealPlan!['meals'][mealType] = mealData;
    });

    // ดึงข้อมูลแผนอาหารปัจจุบันจาก Firestore ก่อน
    DocumentSnapshot docSnapshot = await _firestore.collection('mealPlans').doc(currentMealPlanId).get();
    if (!docSnapshot.exists) {
      throw Exception('ไม่พบแผนอาหาร');
    }
    
    // แก้ไขเฉพาะส่วนที่ต้องการ
    Map<String, dynamic> currentData = docSnapshot.data() as Map<String, dynamic>;
    List<dynamic> updatedDailyPlans = List.from(currentData['dailyPlans']);
    updatedDailyPlans[todayDayIndex!]['meals'][mealType] = mealData;
    
    // อัปเดตแผนอาหารทั้งหมด
    await _firestore.collection('mealPlans').doc(currentMealPlanId).update({
      'dailyPlans': updatedDailyPlans
    });

    // แจ้งเตือนผู้ใช้
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เปลี่ยนเมนู${_getMealTypeName(mealType)}สำเร็จ'),
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    print("Error updating meal menu: $e");
    
    // ตรวจสอบ mounted ก่อนใช้ context
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเปลี่ยนเมนู: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    // โหลดข้อมูลใหม่ในกรณีเกิดข้อผิดพลาด
    _loadTodayMealPlan();
  }
}
  
  // เฉพาะอัปเดต UI ไม่บันทึกลง Firestore
  void _updateLocalMealCompletion(String mealType, bool isCompleted) {
    setState(() {
      todayMealPlan!['completed'][mealType] = isCompleted;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCompleted ? 'ทาน${_getMealTypeName(mealType)}สำเร็จ' : 'ยกเลิกการทาน${_getMealTypeName(mealType)}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
              
              // มื้ออาหาร
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        const Icon(Icons.fiber_manual_record, size: 12, color: Colors.grey),
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
                }).toList(),
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
                    _updateLocalMealCompletion(mealType, !currentStatus);
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
                    backgroundColor: isCompleted ? Colors.red.shade400 : Colors.green,
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
    final List<MapEntry<String, dynamic>> entries = nutritionalInfo.entries.toList();
    
    return Column(
      children: [
        for (int i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                // คอลัมน์ซ้าย
                Expanded(
                  child: _buildNutrientDetailItem(entries[i].key, entries[i].value),
                ),
                // คอลัมน์ขวา (ถ้ามี)
                if (i + 1 < entries.length)
                  Expanded(
                    child: _buildNutrientDetailItem(entries[i + 1].key, entries[i + 1].value),
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
  List<IconData> mealIcons = [Icons.wb_sunny_outlined, Icons.wb_sunny, Icons.nightlight_round];
  List<Color> mealIconColors = [Colors.orange, Colors.orange.shade700, Colors.indigo];
  
  return Container(
    padding: const EdgeInsets.all(16.0),
    child: ListView(
      children: [
        // ส่วนหัวและวันที่ (ทำให้เล็กลงและเป็นส่วนหนึ่งของรายการที่เลื่อนได้)
        Row(
          children: [
            Icon(Icons.today, color: Colors.blue, size: 20),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        const Divider(),
        const SizedBox(height: 8),
        
        // รายการมื้ออาหาร
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
                    _updateLocalMealCompletion(mealType, value ?? false);
                  },
                ),
              ],
            ),
            
            const Divider(height: 24),
            
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
            if (meal['nutritionalInfo'] != null && meal['nutritionalInfo'] is Map)
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                _nutrientItem("แคลอรี่", "${nutritionalInfo['calories']} กิโลแคลอรี่"),
              if (nutritionalInfo['protein'] != null)
                _nutrientItem("โปรตีน", "${nutritionalInfo['protein']} กรัม"),
              if (nutritionalInfo['carbs'] != null)
                _nutrientItem("คาร์โบไฮเดรต", "${nutritionalInfo['carbs']} กรัม"),
              if (nutritionalInfo['fat'] != null)
                _nutrientItem("ไขมัน", "${nutritionalInfo['fat']} กรัม"),
              if (nutritionalInfo['fiber'] != null)
                _nutrientItem("ใยอาหาร", "${nutritionalInfo['fiber']} กรัม"),
              if (nutritionalInfo['sugar'] != null)
                _nutrientItem("น้ำตาล", "${nutritionalInfo['sugar']} กรัม"),
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
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}