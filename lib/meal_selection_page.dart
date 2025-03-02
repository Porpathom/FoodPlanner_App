// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealSelectionPage extends StatefulWidget {
  final String healthCondition;
  final String mealType;
  final String currentMealId;
  final String mealPlanId; // Add this line
  final int dayIndex; // Add this line if it doesn't exist

  const MealSelectionPage({
    Key? key,
    required this.healthCondition,
    required this.mealType,
    required this.currentMealId,
    required this.mealPlanId, // Add this line
    required this.dayIndex, // Add this line if it doesn't exist
  }) : super(key: key);

  @override
  _MealSelectionPageState createState() => _MealSelectionPageState();
}

class _MealSelectionPageState extends State<MealSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> availableMeals = [];
  bool isLoading = true;
  String? selectedMealId;
  String searchQuery = "";
  String? selectedCategory;
  
  // คำอธิบายประเภทมื้ออาหาร
  Map<String, String> mealTypeNames = {
    'breakfast': 'อาหารเช้า',
    'lunch': 'อาหารกลางวัน',
    'dinner': 'อาหารเย็น'
  };
  
  // ไอคอนตามประเภทมื้ออาหาร
  Map<String, IconData> mealTypeIcons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch': Icons.wb_sunny,
    'dinner': Icons.nightlight_round
  };
  
  // สีตามประเภทมื้ออาหาร
  Map<String, Color> mealTypeColors = {
    'breakfast': Colors.orange,
    'lunch': Colors.orange.shade700,
    'dinner': Colors.indigo
  };

  // ตัวกรองหมวดหมู่อาหาร
  Set<String> mealCategories = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableMeals();
    selectedMealId = widget.currentMealId;
  }

  // โหลดรายการเมนูอาหารที่สามารถเลือกได้
  Future<void> _loadAvailableMeals() async {
  setState(() {
    isLoading = true;
  });

  try {
    // แปลง healthCondition เป็นคีย์ที่ใช้ใน Firestore
    String conditionKey = _getConditionKey(widget.healthCondition);
    
    print("กำลังโหลดเมนูอาหารสำหรับ ${widget.mealType} ของผู้มีสภาวะ ${widget.healthCondition} (คีย์: $conditionKey)");
    
    // ดึงรายการเมนูอาหารจาก Firestore โดยใช้ conditionKey
    QuerySnapshot mealsSnapshot = await _firestore
      .collection('foodMenus')
      .where('mealType', isEqualTo: widget.mealType)
      .where('suitableFor.$conditionKey', isEqualTo: true)
      .get();
    
    // แปลงผลลัพธ์เป็นรายการเมนู
    List<Map<String, dynamic>> menus = mealsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
    
    print("พบเมนูทั้งหมด ${menus.length} รายการ");
    
    // ดึงหมวดหมู่อาหารทั้งหมด
    Set<String> categories = {};
    for (var meal in menus) {
      if (meal.containsKey('category') && meal['category'] != null) {
        categories.add(meal['category']);
      }
    }
    
    setState(() {
      availableMeals = menus;
      mealCategories = categories;
      isLoading = false;
    });
  } catch (e) {
    print("เกิดข้อผิดพลาดในการโหลดเมนูอาหาร: $e");
    setState(() {
      isLoading = false;
    });
    
    // แสดงข้อความแจ้งเตือน
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เกิดข้อผิดพลาดในการโหลดเมนูอาหาร: ${e.toString()}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// เพิ่มฟังก์ชัน _getConditionKey ใน MealSelectionPage
String _getConditionKey(String condition) {
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
    case 'high blood pressure':
    case 'highbloodpressure':
      return 'highBloodPressure';
    case 'โรคหัวใจ':
    case 'heart disease':
    case 'heartdisease':
      return 'heartDisease';
    default:
      // เพิ่ม log เพื่อดูว่าค่า condition ที่ได้รับคืออะไร
      print("ไม่พบการแปลงสำหรับสภาวะ: $condition ใช้ค่า 'healthy' แทน");
      return 'healthy';
  }
}

  // เลือกเมนูอาหาร
  void _selectMeal(Map<String, dynamic> meal) {
  setState(() {
    selectedMealId = meal['id'];
  });

  // ส่งข้อมูลเมนูที่เลือกกลับไปยังหน้าก่อนหน้า
  Navigator.pop(context, meal);
}

  // กรองรายการอาหารตามการค้นหาและหมวดหมู่
  List<Map<String, dynamic>> _getFilteredMeals() {
    if (searchQuery.isEmpty && selectedCategory == null) {
      return availableMeals;
    }
    
    return availableMeals.where((meal) {
      // กรองตามการค้นหา
      bool matchesSearch = searchQuery.isEmpty || 
          (meal['name'] != null && meal['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()));
      
      // กรองตามหมวดหมู่
      bool matchesCategory = selectedCategory == null || 
          (meal['category'] != null && meal['category'] == selectedCategory);
      
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // สร้าง Widget แสดงข้อมูลโภชนาการ
  Widget _buildNutritionalInfo(Map<String, dynamic>? nutritionalInfo, {bool detailed = false}) {
    if (nutritionalInfo == null || nutritionalInfo.isEmpty) {
      return const Text('ไม่มีข้อมูลโภชนาการ');
    }
    
    // กำหนดสารอาหารที่จะแสดง
    List<String> nutrients = detailed
        ? ['calories', 'protein', 'carbs', 'fat', 'sugar', 'fiber', 'sodium', 'cholesterol']
        : ['calories', 'protein', 'carbs'];
    
    // กรองเฉพาะที่มีข้อมูล
    nutrients = nutrients.where((key) => nutritionalInfo.containsKey(key)).toList();
    
    if (detailed) {
      // แสดงในรูปแบบตาราง
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'ข้อมูลโภชนาการ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...nutrients.map((key) {
            String label = _translateNutrientName(key);
            String value = nutritionalInfo[key].toString();
            String unit = _getNutrientUnit(key);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '$value $unit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } else {
      // แสดงในรูปแบบบรรทัด
      List<Widget> nutrientWidgets = [];
      
      for (String key in nutrients) {
        String label = _translateNutrientName(key);
        String value = nutritionalInfo[key].toString();
        String unit = _getNutrientUnit(key);
        
        nutrientWidgets.add(
          Row(
            children: [
              Text(
                '$label: ',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '$value $unit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      }
      
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: nutrientWidgets,
      );
    }
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
      case 'cholesterol':
        return 'mg';
      default:
        return '';
    }
  }

  // แสดงหน้ารายละเอียดเมนูอาหาร
// แสดงหน้ารายละเอียดเมนูอาหาร
void _showMealDetails(Map<String, dynamic> meal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true, // เพิ่มตัวเลือกให้สามารถปิดโดยการแตะด้านนอก
    enableDrag: true, // เปิดใช้งานการลากเพื่อปิด
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => GestureDetector(
        // ป้องกันการปิดเมื่อแตะบนเนื้อหา
        onTap: () {}, 
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25.0),
              topRight: Radius.circular(25.0),
            ),
          ),
          child: Column(
            children: [
              // เพิ่มปุ่มปิดที่ชัดเจน
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // เนื้อหารายละเอียดเมนู
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ชื่อเมนูและไอคอน
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mealTypeColors[widget.mealType]?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            mealTypeIcons[widget.mealType] ?? Icons.restaurant,
                            color: mealTypeColors[widget.mealType] ?? Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal['name'] ?? 'ไม่มีชื่อเมนู',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (meal['category'] != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    meal['category'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // รายละเอียดเมนู
                    if (meal['description'] != null && meal['description'].toString().isNotEmpty) ...[
                      const Text(
                        'รายละเอียด',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meal['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // ข้อมูลโภชนาการแบบละเอียด
                    if (meal['nutritionalInfo'] != null) ...[
                      _buildNutritionalInfo(meal['nutritionalInfo'], detailed: true),
                      const SizedBox(height: 24),
                    ],
                    
                    // ส่วนประกอบทั้งหมด
                    if (meal['ingredients'] != null && (meal['ingredients'] as List).isNotEmpty) ...[
                      const Text(
                        'ส่วนประกอบ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildIngredientsDetail(meal['ingredients']),
                      const SizedBox(height: 24),
                    ],
                    
                    // ประโยชน์ต่อสุขภาพ (ถ้ามี)
                    if (meal['healthBenefits'] != null && (meal['healthBenefits'] as List).isNotEmpty) ...[
                      const Text(
                        'ประโยชน์ต่อสุขภาพ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate((meal['healthBenefits'] as List).length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  meal['healthBenefits'][index],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                    
                    // ข้อควรระวัง (ถ้ามี)
                    if (meal['warnings'] != null && meal['warnings'].toString().isNotEmpty) ...[
                      const Text(
                        'ข้อควรระวัง',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                meal['warnings'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
              
              // ปุ่มเลือกเมนู
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectMeal(meal);
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: meal['id'] == selectedMealId ? Colors.green : Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    meal['id'] == selectedMealId ? 'เลือกเมนูนี้อยู่แล้ว' : 'เลือกเมนูนี้',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  
  // แสดงส่วนประกอบแบบละเอียด
  Widget _buildIngredientsDetail(List<dynamic> ingredients) {
    return Column(
      children: ingredients.map((ingredient) {
        String ingredientName;
        String? amount;
        
        if (ingredient is String) {
          ingredientName = ingredient;
        } else {
          ingredientName = ingredient['name'] ?? 'ไม่ระบุ';
          amount = ingredient['amount']?.toString();
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ingredientName,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (amount != null) ...[
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เลือกเมนู${mealTypeNames[widget.mealType] ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableMeals,
            tooltip: 'รีเฟรชรายการเมนู',
          ),
        ],
      ),
      body: isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('กำลังโหลดรายการเมนู...'),
              ],
            ),
          )
        : availableMeals.isEmpty
          ? _buildEmptyState()
          : _buildPageContent(),
    );
  }
  
  // สร้างหน้าว่างกรณีไม่พบเมนู
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_meals, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'ไม่พบเมนูอาหารที่เหมาะสม',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAvailableMeals,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่อีกครั้ง'),
          ),
        ],
      ),
    );
  }

  // สร้างเนื้อหาของหน้า
  Widget _buildPageContent() {
    final filteredMeals = _getFilteredMeals();
    
    return Column(
      children: [
        // ส่วนการค้นหาและตัวกรอง
        _buildSearchAndFilterBar(),
        
        // แสดงว่าไม่พบเมนูจากการค้นหา
        if (filteredMeals.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'ไม่พบเมนูที่ตรงกับการค้นหา',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        searchQuery = '';
                        selectedCategory = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('ล้างตัวกรอง'),
                  ),
                ],
              ),
            ),
          )
        // แสดงรายการเมนูที่กรองแล้ว
        else
          Expanded(
            child: _buildMealsList(filteredMeals),
          ),
      ],
    );
  }

  // สร้างส่วนค้นหาและตัวกรอง
  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ช่องค้นหา
          TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาเมนูอาหาร...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
          
          // ตัวกรองหมวดหมู่
          if (mealCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // ปุ่มแสดงทั้งหมด
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('ทั้งหมด'),
                      selected: selectedCategory == null,
                      checkmarkColor: Colors.white,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: selectedCategory == null ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = null;
                        });
                      },
                    ),
                  ),
                  
                  // ปุ่มตัวกรองหมวดหมู่
                  ...mealCategories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        checkmarkColor: Colors.white,
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: selectedCategory == category ? Colors.white : Colors.black,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // สร้าง ListView แสดงรายการเมนูอาหาร
  Widget _buildMealsList(List<Map<String, dynamic>> meals) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
        final bool isSelected = meal['id'] == selectedMealId;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showMealDetails(meal),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ส่วนหัวคาร์ด
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ไอคอนประเภทอาหาร
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: mealTypeColors[widget.mealType]?.withOpacity(0.1) 
                                ?? Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          mealTypeIcons[widget.mealType] ?? Icons.restaurant,
                          color: mealTypeColors[widget.mealType] ?? Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // ชื่อเมนูและข้อมูลโภชนาการ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal['name'] ?? 'ไม่มีชื่อเมนู',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (meal['category'] != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  meal['category'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                            if (meal['nutritionalInfo'] != null) ...[
                              const SizedBox(height: 4),
                              _buildNutritionalInfo(meal['nutritionalInfo']),
                            ],
                          ],
                        ),
                      ),
                      
                      // ปุ่มเลือก
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.blue)
                    ],
                  ),
                  
                  // คำอธิบายเมนู
                  if (meal['description'] != null && meal['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      meal['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // รายการส่วนประกอบ
                  if (meal['ingredients'] != null && 
                     (meal['ingredients'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildIngredientsList(meal['ingredients']),
                  ],
                  
                  // ปุ่มดูรายละเอียดและเลือกเมนูนี้
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showMealDetails(meal),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('ดูรายละเอียด'),
                      ),
                      ElevatedButton(
                        onPressed: () => _selectMeal(meal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.green : null,
                        ),
                        child: Text(
                          isSelected ? 'เมนูที่เลือกอยู่' : 'เลือกเมนูนี้',
                          style: TextStyle(
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // สร้างรายการส่วนประกอบ
  Widget _buildIngredientsList(List<dynamic> ingredients) {
    // แสดงส่วนประกอบหลัก 3 รายการแรก
    final displayedIngredients = ingredients.take(3).toList();
    final remainingCount = ingredients.length - displayedIngredients.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ส่วนประกอบหลัก:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...displayedIngredients.map((ingredient) {
              String ingredientName = ingredient is String 
                  ? ingredient 
                  : ingredient['name'] ?? 'ไม่ระบุ';
                  
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ingredientName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              );
            }).toList(),
            
            // แสดงจำนวนส่วนประกอบที่เหลือ
            if (remainingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+$remainingCount อื่นๆ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}