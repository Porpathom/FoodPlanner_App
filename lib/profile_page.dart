import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget {
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
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // เรียก Navigator ที่นี่
  });


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
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
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

  void _signOut(BuildContext context) async {
  try {
    // แสดง dialog ยืนยัน
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("ยืนยันการออกจากระบบ"),
          content: Text("คุณต้องการออกจากระบบใช่หรือไม่?"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("ยกเลิก"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text("ออกจากระบบ"),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      // แสดง loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
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

  // สร้าง widget แถวข้อมูลมื้ออาหาร
  Widget _buildMealTimeRow({
    required String mealName,
    required String mealTime,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          SizedBox(width: 12),
          Text(
            mealName,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          Spacer(),
          Text(
            mealTime,
            style: TextStyle(fontSize: 16),
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
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 22),
            SizedBox(width: 12),
          ],
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // กรณีกำลังโหลดข้อมูล
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final user = _auth.currentUser;
    final username = userData?['username'] ?? 'ผู้ใช้';
    final email = user?.email ?? 'ไม่มีอีเมล';
    final breakfastTime = userData?['breakfastTime'] ?? 'ยังไม่มีข้อมูล';
    final lunchTime = userData?['lunchTime'] ?? 'ยังไม่มีข้อมูล';
    final dinnerTime = userData?['dinnerTime'] ?? 'ยังไม่มีข้อมูล';
    final medicalCondition = userData?['medicalCondition'] ?? 'ยังไม่มีข้อมูล';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
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
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.person, size: 60, color: Colors.blue.shade700),
                        ),
                        SizedBox(height: 16),
                        Text(
                          username,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email, color: Colors.grey[600], size: 18),
                            SizedBox(width: 8),
                            Text(
                              email,
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.health_and_safety, color: Colors.red.shade600),
                            SizedBox(width: 8),
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
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu, color: Colors.blue.shade700),
                            SizedBox(width: 8),
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
                
                SizedBox(height: 20),
                
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.settings, color: Colors.grey.shade700),
                            SizedBox(width: 8),
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
                        leading: Icon(Icons.edit, color: Colors.blue),
                        title: Text("แก้ไขข้อมูลส่วนตัว"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: เพิ่มการนำทางไปหน้าแก้ไขข้อมูลส่วนตัว
                          print("แก้ไขข้อมูลส่วนตัว");
                        },
                      ),
                      
                      // ปุ่มแก้ไขตารางเวลาทานอาหาร
                      ListTile(
                        leading: Icon(Icons.access_time, color: Colors.green),
                        title: Text("แก้ไขตารางเวลาทานอาหาร"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: เพิ่มการนำทางไปหน้าแก้ไขตารางเวลาทานอาหาร
                          print("แก้ไขตารางเวลาทานอาหาร");
                        },
                      ),
                      
                      // ปุ่มแก้ไขข้อมูลสุขภาพ
                      ListTile(
                        leading: Icon(Icons.healing, color: Colors.red),
                        title: Text("แก้ไขข้อมูลสุขภาพ"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: เพิ่มการนำทางไปหน้าแก้ไขข้อมูลสุขภาพ
                          print("แก้ไขข้อมูลสุขภาพ");
                        },
                      ),
                      
                      // ปุ่มเปลี่ยนรหัสผ่าน
                      ListTile(
                        leading: Icon(Icons.lock_outline, color: Colors.amber.shade700),
                        title: Text("เปลี่ยนรหัสผ่าน"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: เพิ่มการนำทางไปหน้าเปลี่ยนรหัสผ่าน
                          print("เปลี่ยนรหัสผ่าน");
                        },
                      ),
                      
                      // ปุ่มออกจากระบบ
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text("ออกจากระบบ"),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),

              ],
            ),
          ),
        ),
      ),
    );
  }
}