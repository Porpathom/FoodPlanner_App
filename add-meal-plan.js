const admin = require('firebase-admin');
const serviceAccount = require('./demoapp-ffc17-firebase-adminsdk-fbsvc-e08543c7bd.json');

// เริ่มต้นการเชื่อมต่อกับ Firebase
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'demoapp-ffc17',
  storageBucket: 'demoapp-ffc17.appspot.com'
});

const db = admin.firestore();

// ข้อมูลเมนูอาหารสำหรับผู้ป่วยโรคความดันโลหิตสูง
const highBloodPressureMenus = {
  breakfast: [
    {
      name: "โยเกิร์ตกรีกไม่หวาน + ซีเรียลโฮลเกรน + ผลไม้ตระกูลเบอร์รี่",
      description: "อาหารเช้าที่เหมาะสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยใยอาหารและสารต้านอนุมูลอิสระที่ช่วยบำรุงหัวใจ",
      ingredients: ["โยเกิร์ตกรีกไม่หวาน", "ซีเรียลโฮลเกรนไม่หวาน", "สตรอเบอร์รี่", "บลูเบอร์รี่", "เมล็ดแฟลกซ์"],
      nutritionalInfo: { calories: 280, protein: 15, carbs: 40, fat: 5, fiber: 8, sodium: "ต่ำมาก", cholesterol: "ต่ำ" }
    },
    {
      name: "ข้าวโอ๊ตต้มนมไขมันต่ำ + ถั่วและเมล็ดพืช",
      description: "อาหารเช้าเพื่อสุขภาพหัวใจ อุดมด้วยเบต้ากลูแคนที่ช่วยลดคอเลสเตอรอล",
      ingredients: ["ข้าวโอ๊ตเต็มเมล็ด", "นมไขมันต่ำ", "ถั่วอัลมอนด์", "เมล็ดเจีย", "อบเชย", "แอปเปิ้ลหั่น"],
      nutritionalInfo: { calories: 320, protein: 14, carbs: 45, fat: 9, fiber: 10, sodium: "ต่ำ", cholesterol: "ต่ำมาก" }
    },
    {
      name: "สมูทตี้ผักใบเขียว + ผลไม้ + โปรตีนจากพืช",
      description: "อาหารเช้าสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยสารอาหารที่ช่วยบำรุงหลอดเลือดและหัวใจ",
      ingredients: ["ผักคะน้า", "ผักโขม", "กล้วย", "แอปเปิ้ล", "โปรตีนถั่วลันเตา", "เมล็ดแฟลกซ์", "น้ำมะนาว"],
      nutritionalInfo: { calories: 250, protein: 15, carbs: 35, fat: 5, fiber: 9, sodium: "ต่ำมาก", cholesterol: "ไม่มี" }
    },
    {
      name: "ไข่ขาวโอเมเล็ตผัก + ขนมปังโฮลเกรน",
      description: "อาหารเช้าโปรตีนสูงสำหรับผู้ป่วยโรคหัวใจ ไม่มีคอเลสเตอรอลจากไข่แดง",
      ingredients: ["ไข่ขาว", "ผักโขม", "มะเขือเทศ", "หอมใหญ่", "พริกหวาน", "ขนมปังโฮลเกรนไม่เค็ม"],
      nutritionalInfo: { calories: 290, protein: 25, carbs: 30, fat: 4, fiber: 7, sodium: "ต่ำ", cholesterol: "ต่ำมาก" }
    },
    {
      name: "พุดดิ้งเมล็ดเจีย + นมถั่วเหลือง + ผลไม้",
      description: "อาหารเช้าสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยโอเมก้า-3 ที่ช่วยลดการอักเสบในร่างกาย",
      ingredients: ["เมล็ดเจีย", "นมถั่วเหลืองไม่หวาน", "กล้วย", "ส้ม", "อัลมอนด์", "อบเชย"],
      nutritionalInfo: { calories: 300, protein: 12, carbs: 35, fat: 12, fiber: 15, sodium: "ต่ำมาก", cholesterol: "ไม่มี" }
    },
    {
      name: "โทสต์อะโวคาโด + มะเขือเทศย่าง",
      description: "อาหารเช้าที่อุดมด้วยไขมันดีสำหรับผู้ป่วยโรคหัวใจ ช่วยลดคอเลสเตอรอลชนิดไม่ดี",
      ingredients: ["ขนมปังโฮลเกรนไม่เค็ม", "อะโวคาโด", "มะเขือเทศย่าง", "น้ำมะนาว", "พริกไทยดำ", "ต้นอ่อนทานตะวัน"],
      nutritionalInfo: { calories: 310, protein: 8, carbs: 30, fat: 18, fiber: 10, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "โจ๊กข้าวกล้อง + ปลาย่าง + ผักใบเขียว",
      description: "อาหารเช้าแบบเอเชียสำหรับผู้ป่วยโรคหัวใจ ให้โปรตีนคุณภาพดีและโอเมก้า-3",
      ingredients: ["ข้าวกล้อง", "ปลาแซลมอน", "ผักคะน้า", "ขิง", "ต้นหอม", "งาขาว"],
      nutritionalInfo: { calories: 340, protein: 25, carbs: 40, fat: 8, fiber: 6, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "สลัดผลไม้ + โยเกิร์ต + ถั่วไม่เค็ม",
      description: "อาหารเช้าเบาๆสำหรับผู้ป่วยโรคหัวใจ ให้วิตามินและแร่ธาตุที่จำเป็นต่อการทำงานของหัวใจ",
      ingredients: ["แอปเปิ้ล", "ส้ม", "กีวี", "องุ่น", "โยเกิร์ตกรีกไม่หวาน", "ถั่ววอลนัทไม่เค็ม"],
      nutritionalInfo: { calories: 270, protein: 12, carbs: 35, fat: 10, fiber: 8, sodium: "ต่ำมาก", cholesterol: "ต่ำ" }
    },
    {
      name: "แพนเค้กข้าวโพดโฮลเกรน + น้ำเมเปิลแท้",
      description: "อาหารเช้าสำหรับผู้ป่วยโรคหัวใจ ใช้แป้งโฮลเกรนและไม่ใช้เนย",
      ingredients: ["แป้งข้าวโพดโฮลเกรน", "นมอัลมอนด์", "ไข่ขาว", "กล้วยบด", "น้ำเมเปิลแท้", "เบอร์รี่รวม"],
      nutritionalInfo: { calories: 340, protein: 10, carbs: 60, fat: 6, fiber: 7, sodium: "ต่ำ", cholesterol: "ต่ำมาก" }
    },
    {
      name: "มัฟฟินควินัวผัก + น้ำผลไม้คั้นสด",
      description: "อาหารเช้าสำหรับผู้ป่วยโรคหัวใจ ใช้ควินัวที่อุดมด้วยโปรตีนคุณภาพดีและใยอาหาร",
      ingredients: ["ควินัว", "แป้งโฮลวีต", "แครอท", "ซุกินี", "ไข่ขาว", "น้ำส้มคั้นสด"],
      nutritionalInfo: { calories: 320, protein: 12, carbs: 50, fat: 6, fiber: 8, sodium: "ต่ำ", cholesterol: "ต่ำมาก" }
    },
  ],
  lunch: [
    {
      name: "สลัดผักใบเขียว + ปลาแซลมอนย่าง + น้ำสลัดมะนาว",
      description: "อาหารกลางวันที่เหมาะสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยโอเมก้า-3 และไฟเบอร์",
      ingredients: ["ผักคะน้า", "ผักโขม", "ผักกาดแก้ว", "ปลาแซลมอน", "มะเขือเทศ", "แตงกวา", "น้ำมันมะกอก", "น้ำมะนาว"],
      nutritionalInfo: { calories: 380, protein: 30, carbs: 20, fat: 20, fiber: 8, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ซุปถั่วเลนทิล + ผักรวม + ขนมปังโฮลเกรน",
      description: "อาหารกลางวันสำหรับผู้ป่วยโรคหัวใจ ให้โปรตีนจากพืชที่ช่วยลดคอเลสเตอรอล",
      ingredients: ["ถั่วเลนทิล", "แครอท", "เซเลอรี่", "หอมใหญ่", "กระเทียม", "มะเขือเทศ", "ขนมปังโฮลเกรนไม่เค็ม"],
      nutritionalInfo: { calories: 340, protein: 18, carbs: 50, fat: 5, fiber: 15, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "โบวล์ควินัว + ปลา + ผักรวม",
      description: "อาหารกลางวันสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยโปรตีนคุณภาพดีและกรดไขมันจำเป็น",
      ingredients: ["ควินัว", "ปลาเทราต์", "บล็อกโคลี่", "พริกหวาน", "มะเขือเทศ", "น้ำมันมะกอก", "น้ำมะนาว"],
      nutritionalInfo: { calories: 410, protein: 30, carbs: 40, fat: 14, fiber: 8, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "แกงส้มชายทะเล + ผัก + ข้าวกล้อง (ไม่ใส่ผงปรุงรส)",
      description: "อาหารไทยปรับสูตรสำหรับผู้ป่วยโรคหัวใจ ลดโซเดียมและเน้นสมุนไพรธรรมชาติ",
      ingredients: ["ปลา", "กุ้ง", "ยอดมะพร้าว", "ฟักทอง", "ดอกแค", "พริกสด", "มะนาว", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 400, protein: 30, carbs: 45, fat: 8, fiber: 7, sodium: "ต่ำ", cholesterol: "ปานกลาง" }
    },
    {
      name: "สลัดถั่วรวม + อะโวคาโด + ธัญพืช",
      description: "อาหารกลางวันสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยโปรตีนจากพืชและไขมันดีที่ช่วยบำรุงหัวใจ",
      ingredients: ["ถั่วแดง", "ถั่วเลนทิล", "ถั่วลูกไก่", "อะโวคาโด", "ผักกาดหอม", "ควินัว", "น้ำมันมะกอก", "น้ำมะนาว"],
      nutritionalInfo: { calories: 420, protein: 20, carbs: 45, fat: 18, fiber: 17, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "พาสต้าโฮลวีตซอสมะเขือเทศโฮมเมด + ปลา",
      description: "อาหารอิตาเลียนเพื่อสุขภาพสำหรับผู้ป่วยโรคหัวใจ ให้ไลโคปีนจากมะเขือเทศที่ช่วยลดความเสี่ยงโรคหัวใจ",
      ingredients: ["พาสต้าโฮลวีต", "มะเขือเทศสด", "กระเทียม", "หอมใหญ่", "ใบโหระพา", "น้ำมันมะกอก", "ปลากะพง"],
      nutritionalInfo: { calories: 420, protein: 25, carbs: 60, fat: 10, fiber: 10, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ผัดผักรวมกับเต้าหู้ + ข้าวกล้อง (ไม่ใส่ผงปรุงรส)",
      description: "อาหารมังสวิรัติเอเชียสำหรับผู้ป่วยโรคหัวใจ ช่วยลดคอเลสเตอรอลและให้โปรตีนจากพืช",
      ingredients: ["เต้าหู้", "บล็อกโคลี่", "แครอท", "พริกหวาน", "ขิง", "กระเทียม", "ซีอิ๊วลดโซเดียม", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 350, protein: 20, carbs: 50, fat: 8, fiber: 9, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "แซนด์วิชปลาทูน่า + ผักสลัด",
      description: "อาหารกลางวันสะดวกสำหรับผู้ป่วยโรคหัวใจ ใช้ปลาทูน่าในน้ำและขนมปังโฮลเกรน",
      ingredients: ["ขนมปังโฮลเกรนไม่เค็ม", "ปลาทูน่าในน้ำ", "โยเกิร์ตกรีกไม่หวาน", "ผักกาดหอม", "แตงกวา", "มะเขือเทศ"],
      nutritionalInfo: { calories: 330, protein: 30, carbs: 35, fat: 8, fiber: 7, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ต้มยำปลา (ไม่ใส่ผงปรุงรส) + ข้าวกล้อง",
      description: "อาหารไทยปรับสูตรสำหรับผู้ป่วยโรคหัวใจ ปรุงรสด้วยสมุนไพรที่มีคุณสมบัติต้านการอักเสบ",
      ingredients: ["ปลากะพง", "เห็ดฟาง", "ใบมะกรูด", "ข่า", "ตะไคร้", "พริกขี้หนูสด", "น้ำมะนาว", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 370, protein: 30, carbs: 45, fat: 6, fiber: 5, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ซุปมิเนสโตรเน่ + ขนมปังโฮลเกรน",
      description: "อาหารอิตาเลียนแบบดั้งเดิมสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยผักและถั่วที่ช่วยลดคอเลสเตอรอล",
      ingredients: ["ถั่วแดง", "ถั่วลันเตา", "มะเขือเทศ", "แครอท", "เซเลอรี่", "หอมใหญ่", "น้ำมันมะกอก", "ขนมปังโฮลเกรน"],
      nutritionalInfo: { calories: 380, protein: 15, carbs: 60, fat: 7, fiber: 15, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
  ],
  dinner: [
    {
      name: "ปลาอบสมุนไพร + มันฝรั่งหวานอบ + ผักย่าง",
      description: "อาหารเย็นสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยโอเมก้า-3 และสารต้านอนุมูลอิสระ",
      ingredients: ["ปลาแซลมอน", "โรสแมรี", "ไทม์", "มันฝรั่งหวาน", "บล็อกโคลี่", "แครอท", "น้ำมันมะกอก"],
      nutritionalInfo: { calories: 390, protein: 30, carbs: 35, fat: 16, fiber: 8, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ซุปผักใบเขียว + ถั่วต่างๆ",
      description: "อาหารเย็นเบาๆสำหรับผู้ป่วยโรคหัวใจ ให้ใยอาหารและสารต้านอนุมูลอิสระสูง",
      ingredients: ["ผักคะน้า", "ผักโขม", "ถั่วแดง", "ถั่วลันเตา", "หอมใหญ่", "กระเทียม", "น้ำมันมะกอก"],
      nutritionalInfo: { calories: 320, protein: 15, carbs: 45, fat: 8, fiber: 12, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "แกงเลียงผัก + ข้าวกล้อง",
      description: "อาหารไทยดั้งเดิมที่เหมาะสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยผักพื้นบ้านและไม่ใช้กะทิ",
      ingredients: ["ฟักทอง", "บวบ", "ข้าวโพดอ่อน", "เห็ดฟาง", "ใบแมงลัก", "พริกไทยอ่อน", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 300, protein: 10, carbs: 50, fat: 3, fiber: 10, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "อกไก่อบมะนาว + มันฝรั่งหวานอบ + ผักสลัด",
      description: "อาหารเย็นที่สมดุลสำหรับผู้ป่วยโรคหัวใจ ใช้เนื้อสัตว์ไขมันต่ำและรสชาติจากสมุนไพร",
      ingredients: ["อกไก่", "มะนาว", "มันฝรั่งหวาน", "น้ำมันมะกอก", "ผักกาดหอม", "มะเขือเทศ", "แตงกวา"],
      nutritionalInfo: { calories: 390, protein: 35, carbs: 40, fat: 8, fiber: 8, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "สลัดควินัว + ถั่วรวม + อะโวคาโด",
      description: "อาหารเย็นมังสวิรัติสำหรับผู้ป่วยโรคหัวใจ ให้โปรตีนจากพืชและไขมันดี",
      ingredients: ["ควินัว", "ถั่วแดง", "ถั่วดำ", "อะโวคาโด", "ผักกาดหอม", "มะเขือเทศ", "น้ำมันมะกอก", "น้ำมะนาว"],
      nutritionalInfo: { calories: 380, protein: 15, carbs: 45, fat: 18, fiber: 13, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "ปลาย่างเมดิเตอเรเนียน + ผักย่าง + ข้าวสีดำ",
      description: "อาหารเย็นสไตล์เมดิเตอร์เรเนียนสำหรับผู้ป่วยโรคหัวใจ ตามแนวทางอาหาร DASH",
      ingredients: ["ปลากะพง", "มะนาว", "กระเทียม", "โรสแมรี่", "พริกหวาน", "มะเขือม่วง", "น้ำมันมะกอก", "ข้าวกล้องสีดำ"],
      nutritionalInfo: { calories: 420, protein: 30, carbs: 40, fat: 15, fiber: 7, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "ต้มจืดเต้าหู้ผัก + ข้าวกล้อง",
      description: "อาหารเย็นเอเชียสำหรับผู้ป่วยโรคหัวใจ รสชาติกลมกล่อมโดยไม่ใช้ผงปรุงรส",
      ingredients: ["เต้าหู้ไข่", "ผักกาดขาว", "แครอท", "เห็ดหอม", "ขิง", "กระเทียม", "พริกไทย", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 320, protein: 20, carbs: 40, fat: 8, fiber: 7, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "ปลานึ่งมะนาว + ข้าวกล้อง",
      description: "อาหารไทยเบาๆสำหรับผู้ป่วยโรคหัวใจ ไขมันต่ำและใช้สมุนไพรแทนเกลือ",
      ingredients: ["ปลากะพง", "มะนาว", "พริกขี้หนูสด", "กระเทียม", "ใบมะกรูด", "ต้นหอม", "ผักชี", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 320, protein: 30, carbs: 35, fat: 5, fiber: 4, sodium: "ต่ำ", cholesterol: "ต่ำ" }
    },
    {
      name: "สปาเกตตีโฮลวีต + ซอสมะเขือเทศผัก",
      description: "อาหารอิตาเลียนสำหรับผู้ป่วยโรคหัวใจ อุดมด้วยไลโคปีนจากมะเขือเทศที่ช่วยบำรุงหัวใจ",
      ingredients: ["สปาเกตตีโฮลวีต", "มะเขือเทศ", "หอมใหญ่", "แครอท", "เซเลอรี่", "กระเทียม", "โรสแมรี่", "ใบโหระพา"],
      nutritionalInfo: { calories: 350, protein: 12, carbs: 65, fat: 5, fiber: 14, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
    {
      name: "พัฟไฟว์ผัก + ซุปถั่วลันเตา",
      description: "อาหารเย็นแนวเมดิเตอร์เรเนียนสำหรับผู้ป่วยโรคหัวใจ ให้คุณค่าทางโภชนาการสูง",
      ingredients: ["ถั่วลันเตา", "บล็อกโคลี่", "แครอท", "มันฝรั่ง", "หอมใหญ่", "กระเทียม", "น้ำมันมะกอก", "ผักกาดหอม"],
      nutritionalInfo: { calories: 340, protein: 15, carbs: 50, fat: 8, fiber: 12, sodium: "ต่ำ", cholesterol: "ไม่มี" }
    },
  ]
};

// เพิ่มฟังก์ชันสำหรับเพิ่มเมนูอาหารสำหรับผู้ป่วยโรคหัวใจ
async function addhighBloodPressureMenus() {
  const batch = db.batch();
  let menuCount = 0;
  
  // เพิ่มเมนูอาหารเช้า
  for (const menu of highBloodPressureMenus.breakfast) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "breakfast",
      suitableFor: {
        healthy: false,
        diabetes: false,
        highBloodPressure: true,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // เพิ่มเมนูอาหารกลางวัน
  for (const menu of highBloodPressureMenus.lunch) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "lunch",
      suitableFor: {
        healthy: false,
        diabetes: false,
        highBloodPressure: true,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // เพิ่มเมนูอาหารเย็น
  for (const menu of highBloodPressureMenus.dinner) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "dinner",
      suitableFor: {
        healthy: false,
        diabetes: false,
        highBloodPressure: true,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // ทำการบันทึกข้อมูลทั้งหมด
  await batch.commit();
  console.log(`เพิ่มเมนูอาหารสำหรับผู้ป่วยโรคหัวใจสำเร็จ จำนวน ${menuCount} เมนู`);
}

// เรียกใช้ฟังก์ชัน
addhighBloodPressureMenus()
  .then(() => {
    console.log('เสร็จสิ้นการนำเข้าเมนูอาหารสำหรับผู้ป่วยโรคหัวใจ');
    process.exit(0);
  })
  .catch(error => {
    console.error('เกิดข้อผิดพลาด:', error);
    process.exit(1);
  });