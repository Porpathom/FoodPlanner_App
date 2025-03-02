const admin = require('firebase-admin');
const serviceAccount = require('./demoapp-ffc17-firebase-adminsdk-fbsvc-e08543c7bd.json');

// เริ่มต้นการเชื่อมต่อกับ Firebase
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'demoapp-ffc17',
  storageBucket: 'demoapp-ffc17.appspot.com'
});

const db = admin.firestore();

// ข้อมูลเมนูอาหารสำหรับผู้ป่วยเบาหวาน
const diabetesMenus = {
  breakfast: [
    {
      name: "โจ๊กข้าวกล้อง + ไข่ต้ม",
      description: "อาหารเช้าที่เหมาะสำหรับผู้ป่วยเบาหวาน มีไฟเบอร์สูงจากข้าวกล้อง ช่วยควบคุมน้ำตาลในเลือด",
      ingredients: ["ข้าวกล้อง", "ไข่ไก่", "ต้นหอม", "ขิง", "พริกไทย"],
      nutritionalInfo: { calories: 220, protein: 15, carbs: 25, fat: 6, fiber: 4, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ขนมปังโฮลเกรน + ไข่ขาวออมเล็ต + อะโวคาโด",
      description: "อาหารเช้าดัชนีน้ำตาลต่ำ เน้นโปรตีนและไขมันดี ช่วยควบคุมระดับน้ำตาลในเลือด",
      ingredients: ["ขนมปังโฮลเกรน", "ไข่ขาว", "อะโวคาโด", "ผักโขม", "พริกหวาน"],
      nutritionalInfo: { calories: 280, protein: 18, carbs: 28, fat: 12, fiber: 7, glycemicIndex: "ต่ำ" }
    },
    {
      name: "โยเกิร์ตกรีกไม่มีน้ำตาล + เมล็ดเจีย + เบอร์รี่",
      description: "อาหารเช้าที่เหมาะกับผู้ป่วยเบาหวาน มีโปรตีนสูง น้ำตาลต่ำ และไฟเบอร์ดี",
      ingredients: ["โยเกิร์ตกรีกไม่มีน้ำตาล", "เมล็ดเจีย", "สตรอเบอร์รี่", "บลูเบอร์รี่", "อัลมอนด์"],
      nutritionalInfo: { calories: 230, protein: 15, carbs: 20, fat: 10, fiber: 8, glycemicIndex: "ต่ำ" }
    },
    {
      name: "สมูทตี้ผักโปรตีนสูง + เมล็ดแฟลกซ์",
      description: "เครื่องดื่มเพื่อสุขภาพสำหรับผู้ป่วยเบาหวาน เต็มไปด้วยวิตามินและแร่ธาตุ ไม่เพิ่มน้ำตาลในเลือดเร็ว",
      ingredients: ["ผักคะน้า", "ผักโขม", "แตงกวา", "โปรตีนถั่วลันเตา", "เมล็ดแฟลกซ์", "น้ำมะนาว"],
      nutritionalInfo: { calories: 180, protein: 15, carbs: 18, fat: 6, fiber: 9, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ไข่ต้ม + อะโวคาโด + มะเขือเทศ",
      description: "อาหารเช้าคาร์บต่ำสำหรับผู้ป่วยเบาหวาน ช่วยควบคุมระดับน้ำตาลในเลือดได้ดี",
      ingredients: ["ไข่ไก่", "อะโวคาโด", "มะเขือเทศราชินี", "เกลือทะเล", "พริกไทย"],
      nutritionalInfo: { calories: 210, protein: 14, carbs: 10, fat: 15, fiber: 6, glycemicIndex: "ต่ำมาก" }
    },
    {
      name: "ข้าวโอ๊ตไม่ขัดสี + นมถั่วเหลืองไม่หวาน",
      description: "อาหารเช้าที่เหมาะกับผู้ป่วยเบาหวาน มีเบต้ากลูแคนช่วยควบคุมน้ำตาลในเลือด",
      ingredients: ["ข้าวโอ๊ตไม่ขัดสี", "นมถั่วเหลืองไม่หวาน", "อบเชยผง", "เมล็ดฟักทอง", "เมล็ดทานตะวัน"],
      nutritionalInfo: { calories: 250, protein: 12, carbs: 35, fat: 8, fiber: 7, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "แพนเค้กถั่วลันเตา + เบอร์รี่สด",
      description: "อาหารเช้าทดแทนแป้งขัดขาวสำหรับผู้ป่วยเบาหวาน ให้โปรตีนสูงและคาร์บน้อย",
      ingredients: ["แป้งถั่วลันเตา", "ไข่ไก่", "นมอัลมอนด์ไม่หวาน", "สตรอเบอร์รี่", "บลูเบอร์รี่"],
      nutritionalInfo: { calories: 270, protein: 18, carbs: 25, fat: 10, fiber: 6, glycemicIndex: "ต่ำ" }
    },
    {
      name: "พุดดิ้งเมล็ดเจีย + ผลไม้ดัชนีน้ำตาลต่ำ",
      description: "อาหารเช้าเพื่อควบคุมน้ำตาลในเลือด อุดมไปด้วยโอเมก้า-3 และไฟเบอร์",
      ingredients: ["เมล็ดเจีย", "นมอัลมอนด์ไม่หวาน", "แอปเปิ้ลเขียว", "ผลแพร์", "อบเชย"],
      nutritionalInfo: { calories: 220, protein: 8, carbs: 28, fat: 10, fiber: 10, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ขนมปังไรย์ + ไข่ดาว + ผักย่าง",
      description: "อาหารเช้าดัชนีน้ำตาลต่ำ เหมาะสำหรับผู้ป่วยเบาหวาน ให้พลังงานยาวนาน",
      ingredients: ["ขนมปังไรย์", "ไข่ไก่", "ผักโขม", "เห็ด", "มะเขือเทศ"],
      nutritionalInfo: { calories: 260, protein: 16, carbs: 30, fat: 8, fiber: 6, glycemicIndex: "ต่ำ" }
    },
    {
      name: "สลัดผักใบเขียว + ไข่ต้ม + ถั่ว",
      description: "อาหารเช้าคาร์บต่ำสำหรับผู้ป่วยเบาหวาน ช่วยรักษาระดับน้ำตาลในเลือดให้คงที่",
      ingredients: ["ผักกาดแก้ว", "ผักโขม", "ไข่ไก่", "ถั่วอัลมอนด์", "น้ำสลัดมะนาวน้ำมันมะกอก"],
      nutritionalInfo: { calories: 190, protein: 14, carbs: 12, fat: 12, fiber: 5, glycemicIndex: "ต่ำมาก" }
    },
  ],
  lunch: [
    {
      name: "สลัดไก่ย่าง + น้ำสลัดไขมันต่ำ",
      description: "อาหารกลางวันสำหรับผู้ป่วยเบาหวาน ให้โปรตีนสูงและคาร์บต่ำ ช่วยควบคุมน้ำตาลในเลือด",
      ingredients: ["อกไก่", "ผักกาดแก้ว", "ผักโขม", "แตงกวา", "พริกหวาน", "มะเขือเทศ", "น้ำสลัดมะนาวน้ำมันมะกอก"],
      nutritionalInfo: { calories: 320, protein: 35, carbs: 15, fat: 12, fiber: 6, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ข้าวกล้อง + แกงจืดเต้าหู้ + ปลานึ่งซีอิ๊ว",
      description: "อาหารกลางวันสมดุลสำหรับผู้ป่วยเบาหวาน ข้าวกล้องปลดปล่อยน้ำตาลช้า ป้องกันน้ำตาลพุ่ง",
      ingredients: ["ข้าวกล้อง", "เต้าหู้", "ผักกาดขาว", "ปลาแซลมอน", "ซีอิ๊วลดโซเดียม", "ขิง"],
      nutritionalInfo: { calories: 380, protein: 30, carbs: 40, fat: 10, fiber: 7, glycemicIndex: "ปานกลาง-ต่ำ" }
    },
    {
      name: "สลัดควินัว + อกไก่ + ผักรวม",
      description: "อาหารกลางวันที่เหมาะกับผู้ป่วยเบาหวาน ควินัวมีดัชนีน้ำตาลต่ำและให้โปรตีนสูงกว่าธัญพืชทั่วไป",
      ingredients: ["ควินัว", "อกไก่", "ผักกาดแก้ว", "แตงกวา", "อะโวคาโด", "มะเขือเทศ", "น้ำมันมะกอก"],
      nutritionalInfo: { calories: 350, protein: 28, carbs: 30, fat: 14, fiber: 8, glycemicIndex: "ต่ำ" }
    },
    {
      name: "แกงส้มผักรวม + ปลาทอดไม่มีแป้ง + ข้าวไรซ์เบอร์รี่",
      description: "อาหารไทยดัดแปลงสำหรับผู้ป่วยเบาหวาน ใช้ข้าวไรซ์เบอร์รี่ซึ่งมีดัชนีน้ำตาลต่ำกว่าข้าวขาว",
      ingredients: ["ข้าวไรซ์เบอร์รี่", "ปลาแซลมอน", "ผักบุ้ง", "ดอกแค", "น้ำมะขามเปียก", "พริกแกงส้ม"],
      nutritionalInfo: { calories: 400, protein: 30, carbs: 35, fat: 15, fiber: 8, glycemicIndex: "ปานกลาง-ต่ำ" }
    },
    {
      name: "สปาเก็ตตี้โฮลวีต + ซอสมะเขือเทศ + ไก่บด",
      description: "อาหารกลางวันแบบอิตาเลียนที่ปรับให้เหมาะกับผู้ป่วยเบาหวาน ใช้เส้นโฮลวีตเพื่อลดการดีดน้ำตาล",
      ingredients: ["สปาเก็ตตี้โฮลวีต", "มะเขือเทศ", "หอมใหญ่", "ไก่บด", "กระเทียม", "ออริกาโน"],
      nutritionalInfo: { calories: 370, protein: 28, carbs: 45, fat: 8, fiber: 8, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "ข้าวกล้อง + ผัดบล็อกโคลี่ไก่สับ",
      description: "อาหารกลางวันที่สมดุลสำหรับผู้ป่วยเบาหวาน บล็อกโคลี่ช่วยลดระดับน้ำตาลในเลือด",
      ingredients: ["ข้าวกล้อง", "บล็อกโคลี่", "ไก่สับ", "กระเทียม", "ซอสถั่วเหลืองลดโซเดียม"],
      nutritionalInfo: { calories: 350, protein: 25, carbs: 40, fat: 8, fiber: 7, glycemicIndex: "ปานกลาง-ต่ำ" }
    },
    {
      name: "ซุปเลนทิลกับผัก + ขนมปังไรย์",
      description: "อาหารกลางวันรสอ่อนสำหรับผู้ป่วยเบาหวาน เลนทิลปลดปล่อยน้ำตาลช้า ควบคุมระดับน้ำตาลได้ดี",
      ingredients: ["เลนทิล", "แครอท", "หอมใหญ่", "เซเลอรี่", "มะเขือเทศ", "ขนมปังไรย์"],
      nutritionalInfo: { calories: 300, protein: 18, carbs: 45, fat: 5, fiber: 12, glycemicIndex: "ต่ำ" }
    },
    {
      name: "แซนด์วิชไข่+อะโวคาโด+ขนมปังโฮลวีต",
      description: "อาหารกลางวันที่สะดวกสำหรับผู้ป่วยเบาหวาน มีไขมันดีจากอะโวคาโดช่วยชะลอการดูดซึมน้ำตาล",
      ingredients: ["ขนมปังโฮลวีต", "ไข่ต้ม", "อะโวคาโด", "มะเขือเทศ", "ผักสลัด"],
      nutritionalInfo: { calories: 320, protein: 15, carbs: 30, fat: 18, fiber: 9, glycemicIndex: "ต่ำ" }
    },
    {
      name: "สลัดอูด้ง + ปลาซาบะย่าง",
      description: "อาหารกลางวันแบบญี่ปุ่นสำหรับผู้ป่วยเบาหวาน ปลาซาบะให้ไขมันโอเมก้า-3 ดีต่อระบบหัวใจและหลอดเลือด",
      ingredients: ["อูด้งโฮลวีต", "ปลาซาบะ", "สาหร่ายวากาเมะ", "แตงกวา", "วาซาบิ", "ซอสถั่วเหลืองลดโซเดียม"],
      nutritionalInfo: { calories: 390, protein: 30, carbs: 40, fat: 12, fiber: 6, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "ผัดไทยเส้นบุก + กุ้ง + ผักเพิ่ม",
      description: "อาหารไทยดัดแปลงสำหรับผู้ป่วยเบาหวาน ใช้เส้นบุกแทนเส้นก๋วยเตี๋ยวเพื่อลดคาร์โบไฮเดรต",
      ingredients: ["เส้นบุก", "กุ้ง", "ไข่", "ถั่วงอก", "ผักบุ้ง", "หัวไชเท้าดอง"],
      nutritionalInfo: { calories: 280, protein: 25, carbs: 15, fat: 10, fiber: 5, glycemicIndex: "ต่ำ" }
    },
  ],
  dinner: [
    {
      name: "ปลาย่าง + ผักนึ่ง + มันฝรั่งหวานนึ่ง",
      description: "อาหารเย็นที่สมดุลสำหรับผู้ป่วยเบาหวาน มันฝรั่งหวานมีดัชนีน้ำตาลต่ำกว่ามันฝรั่งธรรมดา",
      ingredients: ["ปลาแซลมอน", "บล็อกโคลี่", "แครอท", "มันฝรั่งหวาน", "มะนาว", "ผักโขม"],
      nutritionalInfo: { calories: 350, protein: 30, carbs: 25, fat: 15, fiber: 7, glycemicIndex: "ต่ำ-ปานกลาง" }
    },
    {
      name: "สลัดไข่ต้ม + ปลาทูน่า + ถั่วรวม",
      description: "อาหารเย็นคาร์บต่ำสำหรับผู้ป่วยเบาหวาน ช่วยควบคุมระดับน้ำตาลในเลือดก่อนนอน",
      ingredients: ["ไข่ไก่", "ปลาทูน่า", "ผักกาดแก้ว", "แตงกวา", "มะเขือเทศ", "ถั่วลิสง", "น้ำสลัดมะนาวไขมันต่ำ"],
      nutritionalInfo: { calories: 300, protein: 28, carbs: 15, fat: 15, fiber: 6, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ต้มยำเต้าหู้ + ข้าวกล้อง",
      description: "อาหารไทยที่เหมาะกับผู้ป่วยเบาหวาน ต้มยำมีสมุนไพรช่วยลดระดับน้ำตาลในเลือด",
      ingredients: ["เต้าหู้แข็ง", "เห็ดหูหนู", "ข่า", "ตะไคร้", "ใบมะกรูด", "พริก", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 320, protein: 20, carbs: 40, fat: 7, fiber: 8, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "ไก่อบสมุนไพร + ผักอบ + ควินัว",
      description: "อาหารเย็นที่สมดุลสำหรับผู้ป่วยเบาหวาน ควินัวมีดัชนีน้ำตาลต่ำและไม่ทำให้น้ำตาลในเลือดพุ่งสูง",
      ingredients: ["อกไก่", "โรสแมรี่", "ไทม์", "พริกหวาน", "มะเขือม่วง", "ควินัว", "น้ำมันมะกอก"],
      nutritionalInfo: { calories: 370, protein: 35, carbs: 30, fat: 12, fiber: 7, glycemicIndex: "ต่ำ" }
    },
    {
      name: "แกงเขียวหวานไก่ไม่ใส่น้ำตาล + ข้าวไรซ์เบอร์รี่",
      description: "อาหารไทยดัดแปลงสำหรับผู้ป่วยเบาหวาน ปรุงรสด้วยสมุนไพรแทนน้ำตาล",
      ingredients: ["อกไก่", "มะเขือพวง", "ใบโหระพา", "พริกแกงเขียวหวาน", "กะทิ", "ข้าวไรซ์เบอร์รี่"],
      nutritionalInfo: { calories: 400, protein: 30, carbs: 35, fat: 18, fiber: 6, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "ซุปถั่วเขียว + ปลาย่าง + ผักสด",
      description: "อาหารเย็นที่ย่อยง่ายสำหรับผู้ป่วยเบาหวาน ถั่วเขียวช่วยควบคุมระดับน้ำตาลในเลือด",
      ingredients: ["ถั่วเขียว", "ปลาคอด", "ผักบุ้ง", "แตงกวา", "ผักกาดหอม", "ต้นหอม"],
      nutritionalInfo: { calories: 320, protein: 35, carbs: 25, fat: 8, fiber: 10, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ลาบไก่ + ผักสด + ข้าวกล้อง",
      description: "อาหารไทยอีสานดัดแปลงสำหรับผู้ป่วยเบาหวาน ใช้ข้าวกล้องแทนข้าวเหนียว เพิ่มผักให้มากขึ้น",
      ingredients: ["อกไก่", "ผักสด", "ต้นหอม", "หอมแดง", "ข้าวคั่ว", "น้ำปลา", "พริกป่น", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 350, protein: 30, carbs: 35, fat: 10, fiber: 6, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "โทสต์อะโวคาโด + ไข่ดาว + ผักโขม",
      description: "อาหารเย็นเบาๆ สำหรับผู้ป่วยเบาหวาน ทำง่ายและควบคุมน้ำตาลในเลือดได้ดี",
      ingredients: ["ขนมปังโฮลเกรน", "อะโวคาโด", "ไข่ไก่", "ผักโขม", "มะเขือเทศราชินี"],
      nutritionalInfo: { calories: 310, protein: 15, carbs: 25, fat: 18, fiber: 8, glycemicIndex: "ต่ำ" }
    },
    {
      name: "ผัดผักรวมกับเต้าหู้ + ข้าวกล้อง",
      description: "อาหารเย็นมังสวิรัติสำหรับผู้ป่วยเบาหวาน เน้นผักหลากหลายชนิดเพื่อควบคุมน้ำตาลในเลือด",
      ingredients: ["เต้าหู้แข็ง", "บล็อกโคลี่", "แครอท", "ถั่วลันเตา", "เห็ดหอม", "ซอสถั่วเหลืองลดโซเดียม", "ข้าวกล้อง"],
      nutritionalInfo: { calories: 320, protein: 18, carbs: 40, fat: 10, fiber: 10, glycemicIndex: "ปานกลาง" }
    },
    {
      name: "ปลาอบเนย + บร็อคโคลี่นึ่ง + มันบด",
      description: "อาหารเย็นแบบตะวันตกสำหรับผู้ป่วยเบาหวาน ใช้มันฝรั่งหวานบดแทนมันฝรั่งปกติ ช่วยลดการเพิ่มน้ำตาลในเลือด",
      ingredients: ["ปลาแซลมอน", "เนยไม่เค็ม", "บร็อคโคลี่", "มันฝรั่งหวาน", "กระเทียม", "มะนาว"],
      nutritionalInfo: { calories: 380, protein: 30, carbs: 30, fat: 15, fiber: 6, glycemicIndex: "ปานกลาง-ต่ำ" }
    },
  ]
};

// เพิ่มฟังก์ชันสำหรับเพิ่มเมนูอาหารสำหรับผู้ป่วยเบาหวาน
async function addDiabetesMenus() {
  const batch = db.batch();
  let menuCount = 0;
  
  // เพิ่มเมนูอาหารเช้า
  for (const menu of diabetesMenus.breakfast) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "breakfast",
      suitableFor: {
        healthy: false,
        diabetes: true,
        highBloodPressure: false,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // เพิ่มเมนูอาหารกลางวัน
  for (const menu of diabetesMenus.lunch) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "lunch",
      suitableFor: {
        healthy: false,
        diabetes: true,
        highBloodPressure: false,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // เพิ่มเมนูอาหารเย็น
  for (const menu of diabetesMenus.dinner) {
    const menuRef = db.collection('foodMenus').doc();
    batch.set(menuRef, {
      ...menu,
      mealType: "dinner",
      suitableFor: {
        healthy: false,
        diabetes: true,
        highBloodPressure: false,
        heartDisease: false
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    menuCount++;
  }
  
  // ทำการบันทึกข้อมูลทั้งหมด
  await batch.commit();
  console.log(`เพิ่มเมนูอาหารสำเร็จ จำนวน ${menuCount} เมนู`);
}

// เรียกใช้ฟังก์ชัน
addDiabetesMenus()
  .then(() => {
    console.log('เสร็จสิ้นการนำเข้าเมนูอาหาร');
    process.exit(0);
  })
  .catch(error => {
    console.error('เกิดข้อผิดพลาด:', error);
    process.exit(1);
  });