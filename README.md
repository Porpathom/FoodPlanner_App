# 🍽️ Food Planner App

> **แอปพลิเคชันวางแผนมื้ออาหารอัจฉริยะ**

![GitHub Repo Stars](https://img.shields.io/github/stars/Porpathom/demoapp?style=for-the-badge)
![GitHub Forks](https://img.shields.io/github/forks/Porpathom/demoapp?style=for-the-badge)
![GitHub Issues](https://img.shields.io/github/issues/Porpathom/demoapp?style=for-the-badge)

## 🛠️ คุณสมบัติหลัก
- 📅 **วางแผนมื้ออาหาร** – สร้างและจัดการแผนมื้ออาหารตามสุขภาพของคุณ
- 🔄 **เลือกเมนูอัตโนมัติ** – แนะนำอาหารที่เหมาะสมจากฐานข้อมูล
- 🔥 **Firebase Integration** – ใช้ Firebase Authentication และ Firestore ในการจัดเก็บข้อมูล
- 🎨 **UI ทันสมัย** – ออกแบบให้ใช้งานง่ายและสบายตา

## 📂 โครงสร้างโปรเจกต์
```
📂 demoapp
 ┣ 📂 lib
 ┃ ┣ 📜 main.dart               # จุดเริ่มต้นของแอปพลิเคชัน
 ┃ ┣ 📜 home_page.dart          # หน้าแรก
 ┃ ┣ 📜 login_page.dart         # หน้าเข้าสู่ระบบ
 ┃ ┣ 📜 register_page.dart      # หน้าสมัครสมาชิก
 ┃ ┣ 📜 profile_page.dart       # หน้าโปรไฟล์ผู้ใช้
 ┃ ┣ 📜 menu_plan_page.dart     # หน้าสร้างแผนเมนูอาหาร
 ┃ ┣ 📜 meal_plan_display_page.dart  # หน้าดูแผนมื้ออาหาร
 ┃ ┣ 📜 meal_selection_page.dart     # หน้าสำหรับเลือกเมนู
 ┃ ┣ 📜 raw_materials_page.dart      # หน้าดูวัตถุดิบที่ต้องใช้
 ┃ ┣ 📜 today_page.dart        # หน้าสรุปมื้ออาหารของวันนี้
 ┃ ┗ 📜 firebase_options.dart  # การตั้งค่า Firebase
 ┣ 📂 assets                  # ไฟล์ภาพและไอคอน
 ┣ 📜 pubspec.yaml            # รายการ dependencies
 ┗ 📜 README.md               # ไฟล์เอกสารนี้
```

## 🚀 การติดตั้งและใช้งาน
```sh
# โคลนโปรเจกต์
git clone https://github.com/Porpathom/demoapp.git
cd demoapp

# ติดตั้ง dependencies
flutter pub get

# รันแอปพลิเคชัน
flutter run
```

## 🌟 วิธีการใช้งาน
1. **สมัครสมาชิก** – ลงทะเบียนบัญชีใหม่ด้วย Firebase Authentication
2. **เข้าสู่ระบบ** – ใช้อีเมลและรหัสผ่านเพื่อเข้าถึงแอป
3. **ตั้งค่าโปรไฟล์** – เพิ่มข้อมูลส่วนตัว เช่น เวลาอาหาร และสภาวะสุขภาพ
4. **สร้างแผนมื้ออาหาร** – ระบบจะแนะนำเมนูตามข้อมูลสุขภาพของคุณ
5. **ดูและแก้ไขมื้ออาหาร** – สามารถเปลี่ยนเมนูและตรวจสอบวัตถุดิบได้


## 📬 ติดต่อ
หากมีคำถามหรือข้อเสนอแนะ สามารถเปิด Issue หรือส่งอีเมลมาที่ **porpathom990@gmail.com**

---
⭐ **ฝากกดดาวให้โปรเจกต์ด้วยนะ!** ⭐

