# بحث المصادر

تطبيق أندرويد: تلصق نصًا، فيبحث عنه في مكتبة «تراث» (turath.io)، ويعرض لك:
- اسم الكتاب والمؤلف
- الجزء والصفحة
- رابطًا مباشرًا يفتح الصفحة في تراث
- زرًّا لنسخ المصدر بصيغة: [📓اسم الكتاب (صـ 3/270)]

## بناء ملف APK بلا كمبيوتر (عن طريق GitHub)
1. أنشئ حسابًا في github.com، ثم مستودعًا جديدًا (New repository).
2. ارفع محتويات هذا المجلد كما هي، ومنها المجلد `.github`.
3. افتح تبويب **Actions**، وانتظر انتهاء «Build APK» (نحو 5 إلى 10 دقائق).
4. افتح العملية المنتهية، ونزّل **turath-finder-apk** من أسفل الصفحة.
5. فكّ الضغط، وثبّت `app-release.apk` على جوالك (اسمح بالتثبيت من مصادر غير معروفة).

## أو على كمبيوتر فيه Flutter
```
flutter create --platforms=android --org com.fawaid .
flutter pub get
flutter run
```
وأضف السطر التالي في `android/app/src/main/AndroidManifest.xml` قبل `<application`:
`<uses-permission android:name="android.permission.INTERNET"/>`
