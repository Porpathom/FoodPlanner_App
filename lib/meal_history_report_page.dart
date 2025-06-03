import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';

class MealHistoryReportPage extends StatefulWidget {
  const MealHistoryReportPage({Key? key}) : super(key: key);

  @override
  State<MealHistoryReportPage> createState() => _MealHistoryReportPageState();
}

class _MealHistoryReportPageState extends State<MealHistoryReportPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  TabController? _tabController;
  bool isLoading = true;
  Map<String, dynamic>? currentMealPlan;
  List<Map<String, dynamic>> allMeals = []; // รวมทุกมื้ออาหาร
  Map<String, int> completionStats = {
    'breakfast': 0,
    'lunch': 0,
    'dinner': 0,
    'total': 0
  };
  int totalMeals = 0;
  double completionRate = 0.0;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH');
    _tabController = TabController(length: 2, vsync: this); // ลดเหลือ 2 แท็บ
    _loadMealHistory();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadMealHistory() async {
    try {
      setState(() {
        isLoading = true;
      });

      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
      }

      QuerySnapshot mealPlanQuery = await _firestore
          .collection('mealPlans')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (mealPlanQuery.docs.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      DocumentSnapshot mealPlanDoc = mealPlanQuery.docs.first;
      Map<String, dynamic> mealPlanData =
          mealPlanDoc.data() as Map<String, dynamic>;

      Timestamp startTimestamp = mealPlanData['startDate'] as Timestamp;
      Timestamp endTimestamp = mealPlanData['endDate'] as Timestamp;
      startDate = startTimestamp.toDate();
      endDate = endTimestamp.toDate();

      List<Map<String, dynamic>> allMealsList = [];
      Map<String, int> stats = {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
        'total': 0
      };
      int totalPossibleMeals = 0;

      if (mealPlanData.containsKey('dailyPlans')) {
        List<dynamic> dailyPlans = mealPlanData['dailyPlans'];

        for (int dayIndex = 0; dayIndex < dailyPlans.length; dayIndex++) {
          Map<String, dynamic> dayPlan = dailyPlans[dayIndex];
          DateTime planDate = (dayPlan['date'] as Timestamp).toDate();

          if (planDate.isBefore(DateTime.now()) ||
              DateUtils.isSameDay(planDate, DateTime.now())) {
            totalPossibleMeals += 3;

            // เพิ่มทุกมื้ออาหารลงในรายการเดียว
            _addMealToList(dayPlan, planDate, 'breakfast', allMealsList, stats);
            _addMealToList(dayPlan, planDate, 'lunch', allMealsList, stats);
            _addMealToList(dayPlan, planDate, 'dinner', allMealsList, stats);
          }
        }
      }

      double completionRateValue = totalPossibleMeals > 0
          ? (stats['total']! / totalPossibleMeals) * 100
          : 0.0;

      setState(() {
        currentMealPlan = mealPlanData;
        allMeals = allMealsList;
        completionStats = stats;
        totalMeals = totalPossibleMeals;
        completionRate = completionRateValue;
        isLoading = false;
      });
    } catch (e) {
      print("เกิดข้อผิดพลาดในการโหลดประวัติการทานอาหาร: $e");
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // เพิ่มมื้ออาหารลงในรายการเดียว
  void _addMealToList(
      Map<String, dynamic> dayPlan,
      DateTime planDate,
      String mealType,
      List<Map<String, dynamic>> allMealsList,
      Map<String, int> stats) {
    String mealName = _getMealTypeName(mealType);
    bool isCompleted = dayPlan['completed'][mealType] ?? false;
    String foodName = dayPlan['meals'][mealType]['name'] ?? 'ไม่มีข้อมูล';

    Map<String, dynamic> mealInfo = {
      'date': planDate,
      'dayName': dayPlan['dayName'],
      'mealType': mealType,
      'mealName': mealName,
      'foodName': foodName,
      'isCompleted': isCompleted,
    };

    allMealsList.add(mealInfo);

    if (isCompleted) {
      stats[mealType] = (stats[mealType] ?? 0) + 1;
      stats['total'] = (stats['total'] ?? 0) + 1;
    }
  }

  String _getMealTypeName(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'มื้อเช้า';
      case 'lunch':
        return 'มื้อเที่ยง';
      case 'dinner':
        return 'มื้อเย็น';
      default:
        return 'ไม่ระบุ';
    }
  }

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

  IconData _getMealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.wb_sunny;
      case 'dinner':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(),
        tabBarTheme: TabBarTheme(
          labelColor: const Color.fromARGB(255, 0, 0, 0),
          unselectedLabelColor:
              const Color.fromARGB(255, 59, 56, 56).withOpacity(0.7),
          indicator: BoxDecoration(
            border: null,
          ),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      child: Scaffold(
        body: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8), // เพิ่ม padding ด้านข้าง
          color: const Color.fromARGB(255, 251, 253, 255),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : currentMealPlan == null
                  ? _buildNoMealPlanView()
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                          child: Column(
                            children: [
                              Text(
                                'ประวัติการทานอาหาร',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(255, 6, 0, 0),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TabBar(
                                controller: _tabController,
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: 'ภาพรวม'),
                                  Tab(
                                      text:
                                          'ประวัติการทานอาหาร'), // แท็บเดียวสำหรับประวัติทั้งหมด
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(),
                              _buildAllMealsTab(), // แท็บแสดงประวัติทั้งหมด
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildNoMealPlanView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'ไม่พบแผนอาหาร',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรุณาสร้างแผนอาหารก่อนเพื่อติดตามการทานอาหารของคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('ไปที่หน้าแผนอาหาร'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (startDate != null && endDate != null) ...[
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                      '${DateFormat('d MMMM yyyy', 'th_TH').format(startDate!)} - ${DateFormat('d MMMM yyyy', 'th_TH').format(endDate!)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'สรุปการทานอาหารตามแผน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCircle(
                          value: completionRate,
                          label: 'อัตราทานตามแผน',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCircle(
                          value: totalMeals > 0
                              ? (completionStats['breakfast']! /
                                      (totalMeals / 3)) *
                                  100
                              : 0,
                          label: 'มื้อเช้า',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCircle(
                          value: totalMeals > 0
                              ? (completionStats['lunch']! / (totalMeals / 3)) *
                                  100
                              : 0,
                          label: 'มื้อเที่ยง',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCircle(
                          value: totalMeals > 0
                              ? (completionStats['dinner']! /
                                      (totalMeals / 3)) *
                                  100
                              : 0,
                          label: 'มื้อเย็น',
                          color: Colors.indigo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ทานอาหารตามแผนทั้งหมด ${completionStats['total']} มื้อ จาก $totalMeals มื้อ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'กราฟสถิติการทานอาหาร',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildMealCompletionChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.amber.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'ข้อแนะนำ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendation(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(
      {required double value, required String label, required Color color}) {
    return Column(
      children: [
        Container(
          width: 70, // ลดจาก 80
          height: 70, // ลดจาก 80
          margin: const EdgeInsets.all(4), // ลดจาก 8
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60, // ลดจาก 70
                height: 60, // ลดจาก 70
                child: CircularProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: color,
                  strokeWidth: 8, // ลดจาก 10
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${value.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16, // ลดจาก 18
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // ลดจาก 14
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCompletionChart() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SizedBox(
      width: MediaQuery.of(context).size.width * 1.5,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 3,
          groupsSpace: 12,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String mealType = rodIndex == 0 ? 'เช้า' : (rodIndex == 1 ? 'เที่ยง' : 'เย็น');
                return BarTooltipItem(
                  'มื้อ$mealType: ${rod.toY.toInt()} มื้อ',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (startDate == null || currentMealPlan == null) {
                    return const Text('');
                  }
                  
                  int dayIndex = value.toInt();
                  if (dayIndex < 0 || dayIndex >= (currentMealPlan!['dailyPlans'] as List).length) {
                    return const Text('');
                  }
                  
                  // คำนวณวันจริงจาก startDate
                  DateTime date = startDate!.add(Duration(days: dayIndex));
                  String dayName = DateFormat('E', 'th_TH').format(date); // E = ชื่อวันแบบย่อ
                  
                  return RotatedBox(
                    quarterTurns: 1,
                    child: Text(dayName, style: const TextStyle(fontSize: 12)),
                  );
                },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('0');
                    if (value == 1) return const Text('1');
                    if (value == 2) return const Text('2');
                    if (value == 3) return const Text('3');
                    return const Text('');
                  },
                  reservedSize: 30,
                ),
              ),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                left: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            barGroups: _generateBarGroups(),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
  List<BarChartGroupData> barGroups = [];
  
  if (currentMealPlan != null && currentMealPlan!.containsKey('dailyPlans') && startDate != null) {
    List<dynamic> dailyPlans = currentMealPlan!['dailyPlans'];
    
    // หาวันในสัปดาห์ของวันเริ่มต้น (0=อาทิตย์, 1=จันทร์, ..., 6=เสาร์)
    int startingWeekday = startDate!.weekday % 7; // Dart weekday: 1=จันทร์, 7=อาทิตย์
    
    for (int i = 0; i < dailyPlans.length; i++) {
      Map<String, dynamic> dayPlan = dailyPlans[i];
      DateTime planDate = (dayPlan['date'] as Timestamp).toDate();
      
      // คำนวณลำดับวันในกราฟโดยเริ่มจากวันแรกของแผน
      int displayOrder = i;
      
      bool breakfastCompleted = dayPlan['completed']['breakfast'] ?? false;
      bool lunchCompleted = dayPlan['completed']['lunch'] ?? false;
      bool dinnerCompleted = dayPlan['completed']['dinner'] ?? false;
      
      barGroups.add(
        BarChartGroupData(
          x: displayOrder, // ใช้ displayOrder แทน i
          barRods: [
            BarChartRodData(
              toY: breakfastCompleted ? 1 : 0,
              color: Colors.orange,
              width: 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: lunchCompleted ? 1 : 0,
              color: Colors.green,
              width: 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: dinnerCompleted ? 1 : 0,
              color: Colors.indigo,
              width: 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  return barGroups;
}

  Widget _buildRecommendation() {
    int missedCount = totalMeals - completionStats['total']!;

    String weakestMeal = 'breakfast';
    int lowestRate = completionStats['breakfast'] ?? 0;

    if ((completionStats['lunch'] ?? 0) < lowestRate) {
      weakestMeal = 'lunch';
      lowestRate = completionStats['lunch'] ?? 0;
    }

    if ((completionStats['dinner'] ?? 0) < lowestRate) {
      weakestMeal = 'dinner';
      lowestRate = completionStats['dinner'] ?? 0;
    }

    if (completionRate >= 90) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ยอดเยี่ยมมาก! คุณทานอาหารตามแผนได้ถึง ${completionRate.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 16, color: Colors.green.shade700),
          ),
          const SizedBox(height: 8),
          const Text(
            'การทานอาหารตามแผนอย่างสม่ำเสมอช่วยควบคุมระดับน้ำตาลในเลือดได้ดี ทำให้สุขภาพโดยรวมดีขึ้น',
            style: TextStyle(fontSize: 15),
          ),
        ],
      );
    } else if (completionRate >= 70) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คุณทำได้ดี! ทานอาหารตามแผนได้ ${completionRate.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 16, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'พยายามรักษาความสม่ำเสมอในการทานอาหาร โดยเฉพาะ${_getMealTypeName(weakestMeal).toLowerCase()} ซึ่งเป็นมื้อที่คุณพลาดมากที่สุด',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      );
    } else if (completionRate >= 50) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คุณทานอาหารตามแผนได้ ${completionRate.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 16, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'ควรพยายามทานอาหารตามแผนให้มากขึ้น โดยเฉพาะ${_getMealTypeName(weakestMeal).toLowerCase()} ซึ่งคุณพลาดบ่อยที่สุด เพื่อควบคุมระดับน้ำตาลในเลือดให้ดีขึ้น',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คุณพลาดการทานอาหารตามแผนถึง $missedCount มื้อ',
            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          const Text(
            'การรับประทานอาหารให้ตรงเวลาและตามแผนมีความสำคัญต่อการควบคุมระดับน้ำตาลในเลือด พยายามทานอาหารตามที่วางแผนไว้ให้มากขึ้น',
            style: TextStyle(fontSize: 15),
          ),
        ],
      );
    }
  }

  // แท็บแสดงประวัติการทานอาหารทั้งหมด
  Widget _buildAllMealsTab() {
    if (allMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'ไม่พบประวัติการทานอาหาร',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อคุณทานอาหารตามแผน ข้อมูลจะแสดงที่นี่',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    // จัดกลุ่มข้อมูลตามวันที่
    Map<DateTime, List<Map<String, dynamic>>> groupedByDate = {};
    for (var meal in allMeals) {
      DateTime date = DateUtils.dateOnly(meal['date']);
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(meal);
    }

    // เรียงลำดับวันที่จากปัจจุบันไปอดีต
    List<DateTime> sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        DateTime date = sortedDates[index];
        List<Map<String, dynamic>> dayMeals = groupedByDate[date]!;

        // เรียงลำดับมื้ออาหาร
        dayMeals.sort((a, b) {
          String typeA = a['mealType'];
          String typeB = b['mealType'];
          Map<String, int> order = {'breakfast': 0, 'lunch': 1, 'dinner': 2};
          return order[typeA]!.compareTo(order[typeB]!);
        });

        // นับจำนวนมื้อที่ทานแล้วและพลาดในวันนี้
        int completedCount =
            dayMeals.where((meal) => meal['isCompleted']).length;
        int missedCount = dayMeals.length - completedCount;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: completedCount == 3
                          ? Colors.green
                          : (completedCount == 0 ? Colors.red : Colors.orange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // ใช้รูปแบบวันที่สั้นลง: "วัน, วันที่/เดือน"
                        DateFormat('E, d MMM', 'th_TH').format(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${completedCount}/${dayMeals.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: completedCount == 3
                            ? Colors.green
                            : (completedCount == 0
                                ? Colors.red
                                : Colors.orange),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ...dayMeals.map((meal) => _buildMealItem(meal)).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // สร้างรายการอาหารแต่ละมื้อ (ปรับปรุงให้แสดงทั้งมื้อที่ทานแล้วและพลาด)
  Widget _buildMealItem(Map<String, dynamic> meal) {
    String mealType = meal['mealType'];
    String mealName = meal['mealName'];
    String foodName = meal['foodName'];
    bool isCompleted = meal['isCompleted'];
    Color mealColor = _getMealColor(mealType);
    IconData mealIcon = _getMealIcon(mealType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mealColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(mealIcon, color: mealColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: mealColor,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width:
                      MediaQuery.of(context).size.width * 0.5, // จำกัดความกว้าง
                  child: Text(
                    foodName,
                    maxLines: 2, // อนุญาตให้ขึ้นบรรทัดใหม่
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: isCompleted ? Colors.black : Colors.grey.shade600,
                      decoration:
                          isCompleted ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCompleted ? 'ทานแล้ว' : 'พลาด',
              style: TextStyle(
                color: isCompleted ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
