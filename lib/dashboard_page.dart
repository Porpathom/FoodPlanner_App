// dashboard_page.dart - หน้า Dashboard ที่ได้รับการออกแบบใหม่
// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'today_page.dart';
import 'menu_plan_page.dart';
import 'raw_materials_page.dart';
import 'profile_page.dart';
import 'meal_history_report_page.dart'; // เพิ่ม import สำหรับหน้ารายงาน

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  
  static final List<Widget> _pages = [
    TodayPage(),
    MenuPlanPage(),
    RawMaterialsPage(),
    MealHistoryReportPage(), // เพิ่มหน้ารายงาน
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 28),
            SizedBox(width: 10),
            Text(
              "Food Planner",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // แสดงการแจ้งเตือน
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          backgroundColor: Colors.white,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.today),
              label: 'วันนี้',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'แผนเมนู',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'วัตถุดิบ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),  // เปลี่ยนไอคอนเป็น bar_chart เพื่อสื่อถึงรายงาน
              label: 'รายงาน',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'โปรไฟล์',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}