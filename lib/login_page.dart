// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_is_empty, avoid_print, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isFirebaseInitialized = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
void initState() {
  super.initState();
  _initializeFirebase().then((_) {
    _checkLoginStatus();
  });
}


  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.length == 0) {
        await Firebase.initializeApp();
      }
      setState(() {
        _isFirebaseInitialized = true;
      });
    } catch (e) {
      print('Error initializing Firebase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize Firebase: $e')),
      );
    }
  }

 Future<void> _checkLoginStatus() async {
  try {
    final _auth = FirebaseAuth.instance;
    User? user = _auth.currentUser;

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
    }
  } catch (e) {
    print('Error checking login status: $e');
  }
}

  void _loginUser() async {
    if (!_isFirebaseInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เข้าสู่ระบบสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = '';
        
        if (e.code == 'user-not-found') {
          errorMessage = 'ไม่พบบัญชีผู้ใช้นี้';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'รหัสผ่านไม่ถูกต้อง';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
        } else if (e.code == 'expired-action-code') {
          errorMessage = 'โค้ดนี้หมดอายุแล้ว';
        } else {
          errorMessage = 'เกิดข้อผิดพลาด: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isFirebaseInitialized
          ? Container(
              decoration: BoxDecoration(
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
                      SizedBox(height: 30),
                      Center(
                        child: Text(
                          "เข้าสู่ระบบ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 50),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "อีเมล",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: "กรุณากรอกอีเมลของคุณ",
                                  prefixIcon: Icon(Icons.email, color: Colors.grey),
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
                              SizedBox(height: 20),
                              Text(
                                "รหัสผ่าน",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                decoration: InputDecoration(
                                  hintText: "กรุณากรอกรหัสผ่านของคุณ",
                                  prefixIcon: Icon(Icons.lock, color: Colors.grey),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                                  if (value == null || value.isEmpty) {
                                    return "กรุณากรอกรหัสผ่าน";
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // ลืมรหัสผ่าน
                                  },
                                  child: Text(
                                    "ลืมรหัสผ่าน?",
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              _isLoading
                                  ? Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _loginUser,
                                      child: Text(
                                        "เข้าสู่ระบบ",
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(double.infinity, 54),
                                      ),
                                    ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("ยังไม่มีบัญชีผู้ใช้? "),
                                  TextButton(
                                    onPressed: () {
                                      // ลบบรรทัด Navigator.pop(context); เพื่อแก้ไขปัญหา
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => RegisterPage()),
                                      );
                                    },
                                    child: Text(
                                      "สมัครสมาชิกเลย",
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
                    ],
                  ),
                ),
              ),
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}