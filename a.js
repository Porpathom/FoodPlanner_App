const admin = require('firebase-admin');
const serviceAccount = require('./demoapp-ffc17-firebase-adminsdk-fbsvc-e08543c7bd.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'demoapp-ffc17'
});

const db = admin.firestore();

async function uploadImageLink(imageUrl) {
  try {
    // อัปโหลดลิงก์รูปภาพโดยตรงไปยัง Firestore
    const docRef = await db.collection('links').add({
      url: imageUrl,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('อัปโหลดลิงก์สำเร็จ! ID:', docRef.id);
    console.log('URL:', imageUrl);
    process.exit(0);
  } catch (error) {
    console.error('เกิดข้อผิดพลาดในการอัปโหลด:', error);
    process.exit(1);
  }
}

// ใช้ลิงก์ Postimg ของคุณ
const imageLink = "https://i.postimg.cc/fMJjPgxf/Screenshot-1.png";
uploadImageLink(imageLink);