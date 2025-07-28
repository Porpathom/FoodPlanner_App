import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class MealNotificationDialog extends StatefulWidget {
  final int mealId;
  final String mealName;
  final String mealTime;
  final bool isMedication; // เพิ่มพารามิเตอร์สำหรับยา
  final bool isBeforeMeal; // เพิ่มพารามิเตอร์สำหรับยาก่อนอาหาร

  const MealNotificationDialog({
    super.key,
    required this.mealId,
    required this.mealName,
    required this.mealTime,
    this.isMedication = false, // ค่าเริ่มต้นเป็น false
    this.isBeforeMeal = false, // ค่าเริ่มต้นเป็น false
  });

  @override
  State<MealNotificationDialog> createState() => _MealNotificationDialogState();
}

class _MealNotificationDialogState extends State<MealNotificationDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  Map<String, dynamic>? mealData;
  bool isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadMealData();
    _checkCompletionStatus();
  }

  Future<void> _loadMealData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // ดึงข้อมูลแผนอาหารปัจจุบัน
      QuerySnapshot mealPlanQuery = await _firestore
          .collection('mealPlans')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (mealPlanQuery.docs.isEmpty) return;

      DocumentSnapshot mealPlanDoc = mealPlanQuery.docs.first;
      Map<String, dynamic> mealPlanData = mealPlanDoc.data() as Map<String, dynamic>;

      // หาวันปัจจุบัน
      DateTime today = DateTime.now();
      List<dynamic> dailyPlans = mealPlanData['dailyPlans'];
      
      for (int i = 0; i < dailyPlans.length; i++) {
        DateTime planDate = (dailyPlans[i]['date'] as Timestamp).toDate();
        if (DateUtils.isSameDay(planDate, today)) {
          String mealType = widget.mealId == 1 ? 'breakfast' : widget.mealId == 2 ? 'lunch' : 'dinner';
          mealData = dailyPlans[i]['meals'][mealType];
          isCompleted = dailyPlans[i]['completed'][mealType] ?? false;
          break;
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading meal data: $e');
    }
  }

  Future<void> _checkCompletionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String mealType = widget.mealId == 1 ? 'breakfast' : widget.mealId == 2 ? 'lunch' : 'dinner';
      isCompleted = prefs.getBool('${mealType}_completed_$today') ?? false;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error checking completion status: $e');
    }
  }

  Future<void> _toggleMealCompletion() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (widget.isMedication) {
        // ถ้าเป็นยา ให้จัดการแยกต่างหาก
        if (widget.isBeforeMeal) {
          // ยาก่อนอาหาร
          await NotificationService().handleBeforeMealMedicationResponse(widget.mealId, widget.mealName.replaceAll('ยาก่อน', ''));
        } else {
          // ยาหลังอาหาร
          await NotificationService().handleAfterMealMedicationResponse(widget.mealId, widget.mealName.replaceAll('ยาหลัง', ''));
        }
        
        // สำหรับยา ไม่ต้องอัปเดต isCompleted ใน SharedPreferences
        setState(() {
          isCompleted = true; // ยาจะเสร็จสิ้นทันทีเมื่อกด
          isLoading = false;
        });
      } else {
        // ถ้าเป็นอาหาร ใช้ฟังก์ชันเดิม
        await NotificationService().updateMealCompletionInDatabase(
          widget.mealId,
          !isCompleted,
        );
        
        setState(() {
          isCompleted = !isCompleted;
          isLoading = false;
        });
      }

      // แสดง SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isMedication 
                ? 'บันทึกการทานยาแล้ว' 
                : (isCompleted 
                    ? 'บันทึกการทาน${widget.mealName}สำเร็จ' 
                    : 'ยกเลิกการทาน${widget.mealName}สำเร็จ')
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // ปิด dialog หลังจาก 2 วินาที
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // หัวข้อ
            Row(
              children: [
                Icon(
                  widget.isMedication 
                    ? Icons.medication // ไอคอนยา
                    : (widget.mealId == 1 
                        ? Icons.wb_sunny_outlined 
                        : widget.mealId == 2 
                          ? Icons.wb_sunny 
                          : Icons.nightlight_round),
                  color: widget.isMedication 
                    ? Colors.purple // สีม่วงสำหรับยา
                    : (widget.mealId == 1 
                        ? Colors.orange 
                        : widget.mealId == 2 
                          ? Colors.green 
                          : Colors.indigo),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.mealName} - ${widget.mealTime}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ข้อมูลเมนูอาหาร
            if (mealData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealData!['name'] ?? 'ไม่มีข้อมูล',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mealData!['description'] != null && mealData!['description'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        mealData!['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // สถานะการทาน
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCompleted ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.schedule,
                    color: isCompleted ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isMedication 
                      ? (isCompleted ? 'ทานยาแล้ว' : 'ยังไม่ได้ทานยา')
                      : (isCompleted ? 'ทานแล้ว' : 'ยังไม่ได้ทาน'),
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ปุ่มต่างๆ
            Row(
              children: [
                // ปุ่มหลัก (ทาน/ยกเลิก)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _toggleMealCompletion,
                    icon: isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isCompleted ? Icons.close : Icons.check),
                    label: Text(
                      isLoading 
                        ? 'กำลังบันทึก...' 
                        : widget.isMedication 
                          ? 'ทานยาแล้ว'
                          : (isCompleted 
                              ? 'ยกเลิกการทาน' 
                              : 'ทานอาหารแล้ว')
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // ปุ่มปิด
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ปิด'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 