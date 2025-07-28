import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class MedicationNotificationDialog extends StatefulWidget {
  final int mealId;
  final String mealName;
  final String mealTime;
  final bool isBeforeMeal; // true = ยาก่อนอาหาร, false = ยาหลังอาหาร

  const MedicationNotificationDialog({
    super.key,
    required this.mealId,
    required this.mealName,
    required this.mealTime,
    required this.isBeforeMeal,
  });

  @override
  State<MedicationNotificationDialog> createState() => _MedicationNotificationDialogState();
}

class _MedicationNotificationDialogState extends State<MedicationNotificationDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  bool isCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkCompletionStatus();
  }

  Future<void> _checkCompletionStatus() async {
    try {
      // รีเซ็ตสถานะเป็น false เสมอเมื่อเปิด dialog
      setState(() {
        isCompleted = false;
      });
      
      // ไม่ต้องตรวจสอบจาก SharedPreferences เพราะเราต้องการให้กดปุ่มทุกครั้ง
      debugPrint('🔄 Reset medication completion status for ${widget.mealName}');
    } catch (e) {
      debugPrint('Error checking medication completion status: $e');
    }
  }

  Future<void> _toggleMedicationCompletion() async {
    // ป้องกันการกดซ้ำ
    if (isLoading || isCompleted) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      if (widget.isBeforeMeal) {
        // ยาก่อนอาหาร
        await NotificationService().handleBeforeMealMedicationResponse(widget.mealId, widget.mealName.replaceAll('ยาก่อน', ''));
      } else {
        // ยาหลังอาหาร
        await NotificationService().handleAfterMealMedicationResponse(widget.mealId, widget.mealName.replaceAll('ยาหลัง', ''));
      }

      // บันทึกสถานะใน SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String medicationType = widget.isBeforeMeal ? 'before_medication' : 'after_medication';
      String mealType = widget.mealId == 1 ? 'breakfast' : widget.mealId == 2 ? 'lunch' : 'dinner';
      await prefs.setBool('${medicationType}_${mealType}_$today', true);

      setState(() {
        isCompleted = true;
        isLoading = false;
      });

      // แสดง SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกการทานยาแล้ว'),
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
                  Icons.medication,
                  color: Colors.purple,
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
            
            // ข้อมูลยา
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medication, color: Colors.purple, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        widget.isBeforeMeal ? 'ยาก่อนอาหาร' : 'ยาหลังอาหาร',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isBeforeMeal 
                      ? 'ทานยาก่อนอาหาร ${widget.mealName.replaceAll('ยาก่อน', '')}'
                      : 'ทานยาหลังอาหาร ${widget.mealName.replaceAll('ยาหลัง', '')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // สถานะการทานยา
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
                    isCompleted ? 'ทานยาแล้ว' : 'ยังไม่ได้ทานยา',
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
                // ปุ่มหลัก (ทานยา)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isLoading || isCompleted) ? null : _toggleMedicationCompletion,
                    icon: isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : isCompleted
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.medication),
                    label: Text(
                      isLoading 
                        ? 'กำลังบันทึก...' 
                        : isCompleted
                          ? 'ทานยาแล้ว'
                          : 'ทานยา'
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? Colors.green : Colors.purple,
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