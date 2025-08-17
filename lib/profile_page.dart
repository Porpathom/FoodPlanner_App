import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'edit_user_data_page.dart'; // นำเข้าหน้าแก้ไขข้อมูล

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ฟังก์ชันโหลดข้อมูลผู้ใช้
  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        } else {
          setState(() {
            userData = null;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          userData = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

String _formatMedicationTime(Map<String, dynamic>? medicationData) {
  if (medicationData == null || medicationData['hasMedication'] == false) {
    return 'ไม่มีการทานยา';
  }

  List<String> times = [];
  if (medicationData['beforeMeal'] == true) {
    times.add('ก่อนอาหาร ${medicationData['beforeMinutes']} นาที');
  }
  if (medicationData['afterMeal'] == true) {
    times.add('หลังอาหาร ${medicationData['afterMinutes']} นาที');
  }

  return times.isEmpty ? 'ไม่มีการทานยา' : times.join('\n');
}

  // ฟังก์ชันการออกจากระบบ
  void _signOut(BuildContext context) async {
    try {
      // แสดง dialog ยืนยัน
      bool confirm = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("ยืนยันการออกจากระบบ"),
                content: const Text("คุณต้องการออกจากระบบใช่หรือไม่?"),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("ยกเลิก"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("ออกจากระบบ"),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (confirm) {
        // แสดง loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(child: CircularProgressIndicator());
          },
        );

        await _auth.signOut();

        // ปิด loading
        Navigator.pop(context);

        // ใช้ Future.microtask เพื่อให้แน่ใจว่า Navigator ถูกเรียกหลังจากที่ Widget ได้รับการ build เสร็จสิ้นแล้ว
        Future.microtask(() {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (route) => false, // ล้าง stack ทั้งหมด
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ฟังก์ชันสำหรับการเปลี่ยนรหัสผ่าน
  void _changePassword(BuildContext context) async {
    final emailController = TextEditingController();

    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        emailController.text = user.email!;

        // แสดงกล่องยืนยัน
        bool confirm = await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("เปลี่ยนรหัสผ่าน"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("ระบบจะส่งอีเมลสำหรับรีเซ็ตรหัสผ่านไปยัง:"),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "อีเมล",
                          prefixIcon: Icon(Icons.email),
                        ),
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                      const Text("กรุณาตรวจสอบอีเมลของท่านหลังจากยืนยัน"),
                    ],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("ยกเลิก"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("ส่งอีเมลรีเซ็ต"),
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (confirm) {
          // แสดง loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(child: CircularProgressIndicator());
            },
          );

          // ส่งอีเมลรีเซ็ตรหัสผ่าน
          await _auth.sendPasswordResetEmail(email: emailController.text);

          // ปิด loading
          Navigator.pop(context);

          // แสดงข้อความสำเร็จ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'ส่งอีเมลรีเซ็ตรหัสผ่านเรียบร้อยแล้ว กรุณาตรวจสอบอีเมลของท่าน'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ไม่พบข้อมูลอีเมลผู้ใช้'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการรีเซ็ตรหัสผ่าน: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // สร้าง widget แถวข้อมูลมื้ออาหาร
  Widget _buildMealTimeRow({
    required String mealName,
    required String mealTime,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Text(
            mealName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const Spacer(),
          Text(
            mealTime,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // สร้าง widget แถวข้อมูลทั่วไป
Widget _buildInfoRow({
  required String label,
  required String value,
  IconData? icon,
  Color? iconColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8), // ลดจาก 12 เป็น 8
        ],
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(width: 16), // ใช้ SizedBox แทน Spacer เพื่อควบคุมระยะห่าง
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: value.split('\n').map((line) => Text(
              line,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
            )).toList(),
          ),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    // กรณีกำลังโหลดข้อมูล
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _auth.currentUser;
    final username = userData?['username'] ?? 'ผู้ใช้';
    final email = user?.email ?? 'ไม่มีอีเมล';
    final breakfastTime = userData?['breakfastTime'] ?? 'ยังไม่มีข้อมูล';
    final lunchTime = userData?['lunchTime'] ?? 'ยังไม่มีข้อมูล';
    final dinnerTime = userData?['dinnerTime'] ?? 'ยังไม่มีข้อมูล';
    final medicalCondition = userData?['medicalCondition'] ?? 'ยังไม่มีข้อมูล';
    final double? weight = (userData?['weight'] is num)
        ? (userData?['weight'] as num).toDouble()
        : null;
    final double? height = (userData?['height'] is num)
        ? (userData?['height'] as num).toDouble()
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ส่วน Header (รูปโปรไฟล์และชื่อ)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.person,
                              size: 60, color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email,
                                color: Colors.grey[600], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              email,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ส่วนข้อมูลสุขภาพ
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อ
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.health_and_safety,
                                color: Colors.red.shade600),
                            const SizedBox(width: 8),
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

                      // ข้อมูลโรคประจำตัว
                      _buildInfoRow(
                        label: "โรคประจำตัว",
                        value: medicalCondition,
                        icon: Icons.medical_services,
                        iconColor: Colors.red.shade400,
                      ),

                      // น้ำหนัก
                      _buildInfoRow(
                        label: "น้ำหนัก",
                        value: weight != null ? "${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} กก." : 'ยังไม่มีข้อมูล',
                        icon: Icons.monitor_weight,
                        iconColor: Colors.blueGrey.shade600,
                      ),

                      // ส่วนสูง
                      _buildInfoRow(
                        label: "ส่วนสูง",
                        value: height != null ? "${height.toStringAsFixed(height % 1 == 0 ? 0 : 1)} ซม." : 'ยังไม่มีข้อมูล',
                        icon: Icons.height,
                        iconColor: Colors.blueGrey.shade600,
                      ),

                      // เพิ่มข้อมูลเวลาทานยา
// ในส่วนของข้อมูลสุขภาพ
_buildInfoRow(
  label: "เวลาทานยา",
  value: _formatMedicationTime(userData?['medicationData']),
  icon: Icons.medication,
  iconColor: Colors.green.shade600,
),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ส่วนตารางเวลาทานอาหาร
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อ
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "ตารางเวลาทานอาหาร",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ข้อมูลมื้ออาหาร
                      _buildMealTimeRow(
                        mealName: "มื้อเช้า",
                        mealTime: breakfastTime,
                        icon: Icons.wb_sunny_outlined,
                        iconColor: Colors.orange,
                      ),
                      _buildMealTimeRow(
                        mealName: "มื้อเที่ยง",
                        mealTime: lunchTime,
                        icon: Icons.wb_sunny,
                        iconColor: Colors.orange.shade700,
                      ),
                      _buildMealTimeRow(
                        mealName: "มื้อเย็น",
                        mealTime: dinnerTime,
                        icon: Icons.nightlight_round,
                        iconColor: Colors.indigo,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ส่วนปุ่มการทำงาน
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หัวข้อ
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.settings, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "การตั้งค่า",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ปุ่มแก้ไขข้อมูล
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.blue),
                        title: const Text("แก้ไขข้อมูลส่วนตัว"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        // ในส่วนของปุ่มแก้ไขข้อมูล
                        onTap: () {
                          // นำทางไปยังหน้าแก้ไขข้อมูลผู้ใช้
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditUserDataPage(
                                breakfastTime: breakfastTime == 'ยังไม่มีข้อมูล'
                                    ? ''
                                    : breakfastTime,
                                lunchTime: lunchTime == 'ยังไม่มีข้อมูล'
                                    ? ''
                                    : lunchTime,
                                dinnerTime: dinnerTime == 'ยังไม่มีข้อมูล'
                                    ? ''
                                    : dinnerTime,
                                medicalCondition:
                                    medicalCondition == 'ยังไม่มีข้อมูล'
                                        ? ''
                                        : medicalCondition,
                                medicationData: userData?[
                                    'medicationData'], // เปลี่ยนจาก medicationTime เป็น medicationData
                                weight: weight,
                                height: height,
                                onMedicalConditionUpdated: (newCondition) {
                                  setState(() {
                                    _loadUserData();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      // ปุ่มเปลี่ยนรหัสผ่าน
                      ListTile(
                        leading: Icon(Icons.lock_outline,
                            color: Colors.amber.shade700),
                        title: const Text("เปลี่ยนรหัสผ่าน"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _changePassword(context),
                      ),

                      // ปุ่มออกจากระบบ
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text("ออกจากระบบ"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
