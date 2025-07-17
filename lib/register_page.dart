// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_is_empty, avoid_print, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, deprecated_member_use, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart'; // เพิ่มการนำเข้าไฟล์ login_page.dart

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String username = '';
  bool _isFirebaseInitialized = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

@override
void initState() {
  super.initState();
  setState(() {
    _isFirebaseInitialized = true;
  });
}


  void _registerUser() async {
  if (!_isFirebaseInitialized) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Firebase ยังไม่พร้อมใช้งาน กรุณาลองอีกครั้ง'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      final _auth = FirebaseAuth.instance;
      final _firestore = FirebaseFirestore.instance;

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': username,
          'email': email,
          'createdAt': Timestamp.now(),
          'breakfastTime': '',
          'lunchTime': '',
          'dinnerTime': '',
          'medicalCondition': 'ไม่มีโรคประจำตัว'
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );

        // ใช้ Future.microtask เพื่อให้แน่ใจว่า Navigator ถูกเรียกหลังจากที่ Widget ได้รับการ build เสร็จสิ้นแล้ว
        Future.microtask(() {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false, // ล้าง stack ทั้งหมด
          );
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isFirebaseInitialized
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF4CAF50),
                    Color(0xFFF5F5F5),
                  ],
                  stops: [0.3, 0.3],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          "สมัครสมาชิก",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ชื่อผู้ใช้",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: const InputDecoration(
                                  hintText: "กรุณากรอกชื่อผู้ใช้ของคุณ",
                                  prefixIcon:
                                      Icon(Icons.person, color: Colors.grey),
                                ),
                                onChanged: (value) {
                                  username = value;
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "กรุณากรอกชื่อผู้ใช้";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "อีเมล",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: const InputDecoration(
                                  hintText: "กรุณากรอกอีเมลของคุณ",
                                  prefixIcon:
                                      Icon(Icons.email, color: Colors.grey),
                                ),
                                onChanged: (value) {
                                  email = value;
                                },
                                validator: (value) {
                                  if (value == null || !value.contains('@')) {
                                    return "กรุณากรอกอีเมลที่ถูกต้อง";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "รหัสผ่าน",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: "กรุณากรอกรหัสผ่านของคุณ",
                                  prefixIcon:
                                      const Icon(Icons.lock, color: Colors.grey),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                onChanged: (value) {
                                  password = value;
                                },
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _registerUser,
                                      child: const Text(
                                        "สมัครสมาชิก",
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 54),
                                      ),
                                    ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("มีบัญชีผู้ใช้แล้ว? "),
                                  TextButton(
                                    onPressed: () {
                                      // แก้ไขการนำทาง
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => LoginPage()),
                                      );
                                    },
                                    child: Text(
                                      "เข้าสู่ระบบเลย",
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
