import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';


class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  _RawMaterialsPageState createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool isLoading = true;
  String? currentMealPlanId;
  List<Map<String, dynamic>> dailyPlans = [];
  DateTime startDate = DateTime.now();
  Map<String, Map<String, List<String>>> dailyIngredientsByMeal = {};
  Map<String, Map<String, dynamic>> mealDetails = {};
  
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

  // ชื่อมื้ออาหาร
  final Map<String, String> mealNames = {
    'breakfast': 'มื้อเช้า',
    'lunch': 'มื้อเที่ยง',
    'dinner': 'มื้อเย็น',
  };

  // ไอคอนสำหรับแต่ละมื้อ
  final Map<String, IconData> mealIcons = {
    'breakfast': Icons.free_breakfast,
    'lunch': Icons.lunch_dining,
    'dinner': Icons.dinner_dining,
  };
  
  @override
  void initState() {
    super.initState();
    _loadCurrentMealPlan();
  }
  
  // โหลดแผนอาหารปัจจุบัน
  Future<void> _loadCurrentMealPlan() async {
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
          _loadPlanData(planDoc.id, planDoc.data() as Map<String, dynamic>);
          _organizeIngredientsByMeal();
        } else {
          // ไม่พบแผนอาหาร
          _showNoMealPlanMessage();
        }
      } else {
        // ไม่มีผู้ใช้ที่ล็อกอินอยู่
        _showNoMealPlanMessage();
      }
    } catch (e) {
      print("Error loading meal plan: $e");
      _showNoMealPlanMessage();
    }

    setState(() {
      isLoading = false;
    });
  }
  
  // โหลดข้อมูลแผนอาหาร
  void _loadPlanData(String planId, Map<String, dynamic> planData) {
    try {
      // บันทึก ID ของแผนอาหารปัจจุบัน
      currentMealPlanId = planId;
      
      // ดึงวันที่เริ่มต้น
      if (planData.containsKey('startDate')) {
        Timestamp startTimestamp = planData['startDate'] as Timestamp;
        startDate = startTimestamp.toDate();
      }
      
      // ดึงข้อมูลแผนรายวัน
      if (planData.containsKey('dailyPlans')) {
        List<dynamic> rawDailyPlans = planData['dailyPlans'] as List<dynamic>;
        dailyPlans = rawDailyPlans.map((plan) => plan as Map<String, dynamic>).toList();
      } else {
        dailyPlans = [];
      }
    } catch (e) {
      print("Error in _loadPlanData: $e");
      dailyPlans = [];
    }
  }
  
  // จัดกลุ่มวัตถุดิบตามวันและมื้อ
  void _organizeIngredientsByMeal() {
    dailyIngredientsByMeal.clear();
    mealDetails.clear();
    
    for (int i = 0; i < dailyPlans.length; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      String formattedDate = DateFormat('d MMM', 'th_TH').format(currentDate);
      String dayName = thaiDays[currentDate.weekday % 7];
      String dayKey = "$dayName ($formattedDate)";
      
      Map<String, dynamic> meals = dailyPlans[i]['meals'];
      Map<String, List<String>> mealIngredients = {};
      Map<String, dynamic> dayMealDetails = {};
      
      // วนลูปผ่านมื้ออาหารแต่ละมื้อ
      for (String mealType in ['breakfast', 'lunch', 'dinner']) {
        List<String> ingredients = [];
        String mealName = '';
        String? imageUrl;
        
        if (meals.containsKey(mealType) && meals[mealType] is Map) {
          Map<String, dynamic> meal = meals[mealType];
          mealName = meal.containsKey('name') ? meal['name'] : '';
          // เก็บ URL รูปภาพถ้ามี
          imageUrl = meal.containsKey('imageUrl') ? meal['imageUrl'] : null;
          
          if (meal.containsKey('ingredients') && meal['ingredients'] is List) {
            List<dynamic> mealIngredientsList = meal['ingredients'];
            for (var ingredient in mealIngredientsList) {
              if (ingredient is String) {
                ingredients.add(ingredient);
              } else if (ingredient is Map && ingredient.containsKey('name')) {
                ingredients.add(ingredient['name']);
              }
            }
          }
        }
        
        if (ingredients.isNotEmpty) {
          mealIngredients[mealType] = [mealName, ...ingredients];
          // เก็บรายละเอียดเมนูเพิ่มเติม
          dayMealDetails[mealType] = {
            'name': mealName,
            'imageUrl': imageUrl ?? '',
          };
        }
      }
      
      if (mealIngredients.isNotEmpty) {
        dailyIngredientsByMeal[dayKey] = mealIngredients;
        mealDetails[dayKey] = dayMealDetails;
      }
    }
  }
  
  // แสดงข้อความเมื่อไม่พบแผนอาหาร
  void _showNoMealPlanMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ไม่พบแผนอาหารที่ใช้งานอยู่ กรุณาสร้างแผนอาหารก่อน'),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
@override
Widget build(BuildContext context) {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }
  
  if (dailyPlans.isEmpty || dailyIngredientsByMeal.isEmpty) {
    return Scaffold(
      // ลบ AppBar ออกและใช้ส่วนหัวแบบ Custom
      body: Column(
        children: [
          // ส่วนหัวแบบ Custom
          
          // ส่วนเนื้อหา
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    "วัตถุดิบ",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text("ไม่พบข้อมูลแผนอาหาร กรุณาสร้างแผนอาหารก่อน"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadCurrentMealPlan,
                    child: const Text("โหลดข้อมูลใหม่"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  return Scaffold(
    // ลบ AppBar ออกและใช้ส่วนหัวแบบ Custom
    body: Column(
      children: [
        // ส่วนหัวแบบ Custom
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "วัตถุดิบที่ต้องใช้",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color.fromARGB(255, 0, 0, 0)),
                onPressed: _loadCurrentMealPlan,
                tooltip: "โหลดข้อมูลใหม่",
              ),
            ],
          ),
        ),
        // ส่วนเนื้อหา
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // หัวข้อและคำแนะนำ
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shopping_basket, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "รายการวัตถุดิบประจำสัปดาห์",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "แผนอาหารวันที่ ${DateFormat('d MMMM', 'th_TH').format(startDate)} - ${DateFormat('d MMMM yyyy', 'th_TH').format(startDate.add(const Duration(days: 6)))}",
                      ),
                    ],
                  ),
                ),
              ),
              
              // แสดงรายการวัตถุดิบตามวัน
              for (String dayKey in dailyIngredientsByMeal.keys)
                _buildDayCard(dayKey, dailyIngredientsByMeal[dayKey]!, mealDetails[dayKey]!),
            ],
          ),
        ),
      ],
    ),
  );
}
  
  // สร้างการ์ดแสดงวัตถุดิบตามวัน
  Widget _buildDayCard(String dayName, Map<String, List<String>> mealIngredients, Map<String, dynamic> dayMealDetails) {
    bool isToday = dayName.contains(thaiDays[DateTime.now().weekday % 7]);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
  initiallyExpanded: isToday,
  tilePadding: const EdgeInsets.symmetric(horizontal: 16.0), // ปรับ padding ของ title
  childrenPadding: EdgeInsets.zero, // เอา padding ของ children ออก
  shape: const RoundedRectangleBorder( // กำหนด shape ที่ไม่มีเส้นขอบ
    side: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
        title: Text(
          dayName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isToday ? Colors.blue : null,
          ),
        ),
        subtitle: Text(
          "${mealIngredients.values.expand((i) => i).length} รายการ",
          style: const TextStyle(fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: mealIngredients.keys.map((mealType) {
                List<String> ingredients = mealIngredients[mealType]!;
                String mealTitle = mealNames[mealType] ?? mealType;
                IconData mealIcon = mealIcons[mealType] ?? Icons.restaurant;
                String mealName = ingredients.isNotEmpty ? ingredients[0] : '';
                String? imageUrl = dayMealDetails[mealType]?['imageUrl'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: _getMealColor(mealType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getMealColor(mealType).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: _getMealColor(mealType).withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(7),
                            topRight: Radius.circular(7),
                          ),
                        ),
                        child: Row(
                          children: [
if (imageUrl != null && imageUrl.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(right: 12.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 60,
          height: 60,
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 60,
          height: 60,
          color: Colors.grey[300],
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    ),
  ),
                            
                            // ข้อมูลมื้ออาหาร
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(mealIcon, color: _getMealColor(mealType)),
                                      const SizedBox(width: 8),
                                      Text(
                                        mealTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getMealColor(mealType),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (mealName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, top: 4.0),
                                      child: Text(
                                        mealName,
                                        style: TextStyle(
                                          color: _getMealColor(mealType),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: ingredients.sublist(1).map((ingredient) => 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(fontSize: 16)),
                                  Expanded(
                                    child: Text(
                                      ingredient,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  // กำหนดสีสำหรับแต่ละมื้ออาหาร
  Color _getMealColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}