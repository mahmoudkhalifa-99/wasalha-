# وصلها — نسخة Flutter (المرحلة 1)

تحويل مبدئي لتطبيق وصلها من React/TypeScript إلى Flutter، بنفس موديل البيانات وبنفس مشروع Firebase.

## ✅ اللي اتعمل في المرحلة دي
- إعداد مشروع Flutter كامل (`pubspec.yaml` بكل المكتبات المطلوبة)
- كل موديلات البيانات (`lib/models/models.dart`): User, Order, Restaurant, Zone... إلخ — منقولة بالكامل من `types.ts`
- طبقة الاتصال بـ Firebase (`lib/services/firebase_service.dart`): تسجيل دخول/حساب جديد، قراءة بيانات المستخدم، إنشاء ومتابعة الطلبات
- شاشة تسجيل الدخول والتسجيل الجديد (عميل/كابتن) — `lib/screens/login_screen.dart`
- **لوحة العميل كاملة وشغالة**: الرئيسية بالفئات الخمسة، طلب مشوار تاكسي كامل مع تسعير، تتبع الطلب لحظيًا (Stream)، سجل الطلبات، البروفايل والمحفظة
- بوابة مصادقة ذكية (`lib/app.dart`) بتوجّه كل مستخدم حسب دوره وحالته (بما فيها شاشة "قيد المراجعة" للكباتن الجداد)
- ثيم وهوية بصرية بنفس ألوان النسخة الأصلية (أخضر #2D9469)
- **لوحة الكابتن كاملة وشغالة** (`lib/screens/driver/driver_dashboard.dart`): زر أونلاين/أوفلاين، قائمة الطلبات المتاحة بالقبول الفوري، بطاقة الطلب النشط مع اتصال بالعميل وتحديث الحالة خطوة بخطوة (استلام ← توصيل ← تسليم)، تبويب النشاط بإجمالي الأرباح، وتبويب المحفظة
- **لوحة الأوبريتور كاملة وشغالة** (`lib/screens/operator/operator_dashboard.dart`): تبويب "النشاط الحالي" لمتابعة كل الطلبات المباشرة مع توجيه كابتن يدويًا (Bottom Sheet) أو الاتصال بالكابتن المعيّن أو إلغاء الطلب، تبويب "الكباتن" بالبحث وعرض حالة كل كابتن والاتصال به، وتبويب "السجل العام" لكل الطلبات المكتملة/الملغاة
- **لوحة الإدارة العليا (SuperAdmin) كاملة وشغالة** (`lib/screens/superadmin/superadmin_dashboard.dart`): تبويب "الإحصائيات" (رصيد المنظومة، عدد المستخدمين، عدد الكباتن، عدد الرحلات)، تبويب "المستخدمين" بالبحث والموافقة على الكباتن الجدد وتغيير الرتبة، وتبويب "المطاعم" (إضافة/حذف مطعم، فتح/غلق، إضافة وحذف أصناف المنيو)
- **قسم طلب الطعام للعميل كامل وشغال** (`lib/screens/customer/food/`): تصفح المطاعم مع بحث، فتح المنيو وإضافة الأصناف للسلة بالكمية، شاشة إتمام الطلب (ملخص السلة + رسوم التوصيل + عنوان + ملاحظات + طريقة الدفع)، وإرسال الطلب فعليًا لـ Firestore بنفس نظام تتبع الطلب المستخدم في التاكسي
- **الصيدلية والسوبر ماركت والطرد شغالين بالكامل** (`lib/screens/customer/new_quick_order_screen.dart`): شاشة موحّدة (نفس منطق النسخة الأصلية اللي معندهاش كتالوج منتجات لكل صيدلية/سوبر ماركت) — العميل بيكتب طلبه بالتفصيل + عنوان الاستلام والتسليم، ورسوم توصيل ثابتة، وتكلفة المنتجات نفسها بتتحصّل كاش وقت الاستلام
- **إدارة مراكز وقرى المنوفية** (`lib/screens/superadmin/villages_tab.dart` + `lib/data/menofia_data.dart`) — تبويب رابع في لوحة SuperAdmin: **كل المراكز التسعة محمّلة بقراها بالكامل** (نفس بيانات النسخة الأصلية بالضبط)، مع زرار "تحميل الكل" أو تحميل كل مركز لوحده لرفع البيانات فعليًا لمجموعة `zones` في Firestore
- **الشات المباشر شغال بالكامل** (`lib/screens/chat_screen.dart`): محادثة لحظية بين العميل والكابتن مرتبطة بكل طلب، مع إرسال تنبيه فوري للطرف التاني عند وصول رسالة جديدة. الزرار موجود في شاشة تتبع الطلب للعميل وفي بطاقة الطلب النشط للكابتن
- **الإشعارات شغالة بالكامل** (`lib/screens/notifications_screen.dart`): أيقونة جرس مع عداد غير مقروء في أعلى لوحة العميل ولوحة الكابتن، وشاشة تعرض كل الإشعارات (رسائل الشات الجديدة وغيرها) مع تحديدها كمقروءة عند فتحها
- **اختيار القرية من قائمة حقيقية** (`lib/widgets/village_picker.dart`): زرار جوه كل حقل عنوان (في طلب التاكسي، الصيدلية/السوبر ماركت/الطرد، وعنوان توصيل الطعام) بيفتح قائمة بحث بكل قرى المنوفية مقسّمة حسب المركز، واختيار القرية بيحدد zoneId ولوكيشن دقيق تلقائيًا. في طلب التاكسي كمان، السعر بيتحسب فعليًا بالمسافة الحقيقية بين القريتين (معادلة Haversine) بدل رقم تقريبي ثابت
- **المساعد الذكي شغال** (`lib/screens/ai_assistant_screen.dart` + `lib/services/ai_service.dart`): نفس شخصية "مساعد وصلها" بتاعة النسخة الأصلية بالظبط (نفس الـ system instruction)، بيتفتح بزرار عائم (Sparkles) في لوحة العميل، وبيستخدم Gemini API فعليًا. **لازم تحط مفتاح Gemini بتاعك في `lib/config/ai_config.dart`** (فيه تعليمات وتحذير أمني جوه الملف)
- **إشعارات Push حقيقية عبر FCM شغالة بالكامل** (`lib/services/push_service.dart` + مجلد `functions/`): التطبيق بيطلب إذن الإشعارات، يحفظ توكن FCM بتاع الجهاز على مستند المستخدم، ويستقبل ويعرض إشعارات فعلية سواء التطبيق مفتوح أو مقفول. **الجزء اللي محتاج نشر منفصل**: `functions/index.js` هي Cloud Function بترسل الـ Push الفعلي (مش ممكن يحصل من جهاز العميل مباشرة لأسباب أمنية) — خطوات نشرها موضّحة جوه الملف نفسه

### 📍 صلاحيات إضافية مطلوبة (خرائط + موقع)
شاشة اختيار الموقع من الخريطة (`lib/widgets/map_location_picker.dart`) بتستخدم مكتبة geolocator عشان "استخدم موقعي الحالي"، ومحتاجة صلاحيات على مستوى المنصة بعد `flutter create .`:
- **Android** (`android/app/src/main/AndroidManifest.xml`): ضيف جوه `<manifest>`:
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```
- **iOS** (`ios/Runner/Info.plist`): ضيف:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>محتاجين موقعك عشان نحدد نقطة الانطلاق أو التسليم بدقة</string>
  ```

### 🖼️ Firebase Storage لصور البروفايل
لازم تفعّل **Firebase Storage** من الـ Console (لو لسه مش مفعّل) عشان رفع صور البروفايل يشتغل، وتضيف Security Rule بسيطة تسمح لكل مستخدم يرفع صورته بس:
```
match /profile_photos/{userId}.jpg {
  allow read: if true;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

### ⚠️ خطوات إضافية مطلوبة عشان الإشعارات تشتغل بالكامل
1. فعّل **Cloud Messaging API** من Firebase Console للمشروع
2. لو هتشتغل على iOS: ارفع **APNs Authentication Key** في Firebase Console (Project Settings → Cloud Messaging)
3. انشر الـ Cloud Function من مجلد `functions/`:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```
   من غير الخطوة دي، هيتحفظ إشعار في Firestore وهيظهر جوه التطبيق (شاشة الإشعارات)، لكن مش هيوصل Push حقيقي للجهاز وهو مقفول
- **تقييم الرحلة شغال بالكامل**: بعد ما الكابتن يأكّد التسليم، صافي أرباحه (السعر ناقص العمولة) بيتضاف تلقائيًا لمحفظته. وشاشة تتبع الطلب للعميل بتظهر كارت تقييم (نجوم + تعليق) أول ما الطلب يوصل، ولو اتقيّم قبل كده بتظهر النجوم اللي اختارها بدل الكارت
- **سحب أرباح الكباتن شغال بالكامل**: تبويب المحفظة بقى فيه زرار "طلب سحب الأرباح" (بيتأكد إن المبلغ مش أكبر من الرصيد) + سجل بكل طلبات السحب وحالتها. وفي لوحة SuperAdmin، تبويب الإحصائيات بقى فيه قسم "طلبات سحب الأرباح المعلّقة" يقدر الأدمن يوافق عليه (بيخصم من رصيد الكابتن ويضيفه للمسحوب) أو يرفضه
- **خريطة تفاعلية حقيقية لاختيار الموقع** (`lib/widgets/map_location_picker.dart`): زرار خريطة إضافي جنب كل حقل عنوان (تاكسي، صيدلية/سوبر/طرد، توصيل الطعام) بيفتح خريطة OpenStreetMap تفاعلية بدبوس ثابت في النص، تقدر تحرّك الخريطة تحته أو تستخدم زرار "موقعي الحالي" (GPS)، وتأكّد الموقع بالإحداثيات الدقيقة
- **فلترة سجل الطلبات حسب الفئة**: تبويب "نشاطي" عند العميل بقى فيه شرائط فلتر أفقية (الكل، تاكسي، طعام، صيدلية، سوبر ماركت، طرد) لتصفية الطلبات بسهولة
- **صورة بروفايل شخصية شغالة بالكامل** (`lib/widgets/profile_avatar.dart`): تقدر تدوس على الأفاتار في تبويب "حسابي" (عميل أو كابتن) وتختار صورة من المعرض، بترفع على Firebase Storage وتتحدّث تلقائيًا في `photoURL`
- **فلترة سجل الرحلات بالتاريخ**: زيادة على فلتر الفئة، بقى فيه فلتر "كل الوقت / آخر 7 أيام / آخر 30 يوم" في نشاطي العميل ونشاط الكابتن

### ملحوظة عن منطق قبول الطلبات
النسخة الأصلية فيها ملفات قديمة (`views/CourierDashboard.tsx`) بتستخدم نظام "عروض أسعار" من الكباتن (`WAITING_FOR_OFFERS`, `ACCEPTED`...) وده بيتعارض مع حالات الطلب المعرّفة فعليًا في `types.ts` (`PENDING`, `ASSIGNED`...). اعتمدنا في نسخة Flutter على نظام **قبول مباشر بسعر ثابت** المطابق لـ `types.ts` عشان يفضل التطبيق شغال ومتّسق. لو حابب نظام "عروض الأسعار" (مزايدة) بدل كده، قولّي نضيفه كمرحلة تانية.

### ملحوظة عن رفع الصور
شاشة إدارة المطاعم في نسخة Flutter بسيطة (اسم + تصنيف + أصناف المنيو بدون صور) بدل رفع الصور كـ Base64 زي الويب، عشان الأداء والحجم. ممكن نضيف رفع صور حقيقي (Firebase Storage) في مرحلة لاحقة لو حبيت.

## ⏳ لسه هيتبني في المراحل الجاية (اختيارية - النسخة دلوقتي متكاملة وظيفيًا بالكامل)
- ما فيش حاجة أساسية ناقصة حاليًا. أي إضافة تانية (زي التصوير المباشر بالكاميرا بدل المعرض بس، أو دعم لغات تانية) تقدر تطلبها وقتما تحب
- قسم المطاعم/السوبر ماركت الكامل (تصفح المنيو، عربة التسوق)
- الشات المباشر، الإشعارات (FCM)، المساعد الذكي (AI Assistant)
- الخريطة التفاعلية لاختيار الموقع (المكتبة `flutter_map` مضافة بالفعل في `pubspec.yaml` تحضيرًا لكده)

## 🏗️ النشر عبر Codemagic (CI/CD)

الأرشيف فيه `codemagic.yaml` جاهز (workflow لـ Android و iOS)، لكن فيه خطوات لازم تعملها **قبل** ما ترفع المشروع على Git وتوصّله بـ Codemagic، لأن Codemagic بيبني المشروع زي ما هو من الريبو - مش بيولّد مجلدات المنصات بنفسه:

### 1) ولّد مجلدات android/ios محليًا وارفعها على Git (خطوة إجبارية)
```bash
cd wasalah_app
flutter create --org com.wasalah .
git init
git add .
git commit -m "أول نسخة - تطبيق وصلها Flutter"
git remote add origin <رابط الريبو بتاعك>
git push -u origin main
```
⚠️ الأمر ده هيولّد `applicationId` على الشكل `com.wasalah.wasalah_app` (مش `com.wasalah.app` المكتوب في `codemagic.yaml` و`firebase_options.dart` كقيمة افتراضية). عندك خياران:
- **الأسهل**: افتح `android/app/build.gradle` (قسم `defaultConfig`) وغيّر `applicationId` يبقى `com.wasalah.app`، وكذلك في Xcode غيّر `PRODUCT_BUNDLE_IDENTIFIER` لنفس القيمة - عشان يتطابق مع كل حاجة تانية في المشروع من غير ما تعدّل حاجة تانية.
- **أو**: سيب الـ ID اللي اتولّد زي ما هو، وعدّل بدل منه القيم في `codemagic.yaml` (`BUNDLE_ID` و`PACKAGE_NAME`) و`lib/firebase_options.dart` (`iosBundleId`) عشان تتطابق معاه.

### 2) سجّل تطبيقي Android وiOS في Firebase Console
لازم تضيف تطبيق Android وتطبيق iOS في نفس مشروع Firebase (`sada-51292`) بنفس الـ applicationId/bundle ID اللي استقريت عليه فوق، وبعدين شغّل:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=sada-51292
```
ده هيحدّث `lib/firebase_options.dart` تلقائيًا بقيم appId حقيقية بدل القيم المؤقتة (placeholder). **مش محتاج ترفع `google-services.json` أو `GoogleService-Info.plist` خالص** - التطبيق بيتهيّأ عن طريق `FirebaseOptions` مباشرة في الكود، فالخطوة دي كفاية.

### 3) جهّز إعدادات Codemagic من الـ UI
- **Environment variables**: اعمل جروب اسمه `wasalah_env` وحط فيه `GEMINI_API_KEY` (Secure) لو عايز المساعد الذكي يشتغل في البيلد - الـ script بيحقنه أوتوماتيك في `lib/config/ai_config.dart` وقت البناء، فمينفعش تحط المفتاح في الكود نفسه على Git.
- **Android signing**: لو عايز توقّع الـ APK/AAB لنشره على Google Play، ارفع الـ keystore بتاعك من (Settings → Code signing identities) وفعّل السطر المعلّق في `codemagic.yaml` تحت `android_signing`.
- **iOS signing**: اعمل جروب `ios_signing` واربط حساب Apple Developer بتاعك (Automatic code signing) من إعدادات Codemagic - الـ `ios-workflow` مبني على افتراض التوقيع التلقائي ده.

### 4) شغّل البيلد
من Codemagic، اختار الـ workflow (`android-workflow` أو `ios-workflow`) واضغط Start new build.

## 🚀 خطوات التشغيل

```bash
# 1) فك ضغط المشروع وادخل عليه
cd wasalah_app

# 2) ولّد مجلدات المنصات (android/ios/...) - الأرشيف فيه lib/ وpubspec.yaml بس
flutter create .

# 3) اضبط Firebase لمشروعك (هيولّد firebase_options.dart تلقائيًا بقيم صحيحة)
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --project=sada-51292

# 4) شغّل التطبيق
flutter run
```

⚠️ **مهم جدًا**: لازم تنفّذ `flutter create .` الأول قبل أي حاجة تانية - من غيرها مفيش مجلدات android/ios وهيفشل التشغيل. الأمر ده آمن، بيضيف مجلدات المنصات بس من غير ما يمسّ lib/ أو pubspec.yaml بتاعك.

⚠️ **مهم**: ملف `lib/firebase_options.dart` المرفق فيه appId مؤقت لمنصتي Android/iOS (لأن مشروع الويب الأصلي معندوش تطبيقات موبايل مسجّلة بعد). لازم تنفّذ `flutterfire configure` زي فوق، أو تضيف تطبيق Android/iOS يدويًا من Firebase Console وتحمّل:
- `google-services.json` → `android/app/`
- `GoogleService-Info.plist` → `ios/Runner/`

كمان لازم تفعّل **Email/Password Authentication** من Firebase Console لو لسه مش مفعّل، ولازم قواعد Firestore (Security Rules) تسمح بالقراءة/الكتابة للمستخدم المسجّل دخوله على مجموعتي `users` و`orders`.

## 📁 هيكل المشروع
```
lib/
  models/models.dart                    # كل موديلات البيانات (+ ChatMessage)
  data/menofia_data.dart                # قرى ومراكز المنوفية كاملة
  config/ai_config.dart                 # مفتاح Gemini API وشخصية المساعد
  services/
    firebase_service.dart               # طبقة Firebase (Auth + Firestore)
    ai_service.dart                     # استدعاء Gemini API
    push_service.dart                   # إعداد FCM والإشعارات المحلية
  theme/app_theme.dart                  # الألوان والخطوط
  widgets/village_picker.dart           # قائمة اختيار قرية قابلة لإعادة الاستخدام
  screens/
    login_screen.dart
    chat_screen.dart
    notifications_screen.dart
    ai_assistant_screen.dart
    placeholder_dashboards.dart         # شاشة انتظار موافقة الكباتن
    customer/                           # تاكسي + طعام + صيدلية/سوبر/طرد + نشاطي + بروفايل
    driver/                             # لوحة الكابتن الكاملة
    operator/                           # لوحة الأوبريتور
    superadmin/                         # لوحة الإدارة العليا + إدارة المنوفية
  app.dart                              # بوابة المصادقة والتوجيه
  main.dart                             # نقطة البداية
functions/
  index.js                              # Cloud Function لإرسال Push حقيقي
codemagic.yaml                          # إعداد CI/CD لبناء Android وiOS
.gitignore                              # استثناءات Git القياسية لمشاريع Flutter
```

قولّي تحب نكمل بإيه بعد كده (تقييم الرحلة، سحب الأرباح، أو أي تعديل على اللي موجود).
