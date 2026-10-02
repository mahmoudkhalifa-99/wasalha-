# وصلها — نسخة Flutter

نقل تطبيق وصلها (React/Capacitor) إلى Flutter بنفس الألوان والتصميم والمنطق ونفس مشروع Firebase (`sada-51292`).

## التشغيل
```bash
bash setup_android.sh          # مرة واحدة: يولّد مشروع الأندرويد ويطبّق الأيقونات والصلاحيات
flutterfire configure --project=sada-51292 --platforms=android --android-package-name=com.wasalah.app
flutter run --dart-define=GEMINI_API_KEY=your_key   # المفتاح مطلوب فقط لتشغيل المساعد الذكي
```
تسجيل الدخول بجوجل: لازم بصمة SHA-1 لمفتاح التوقيع تتسجل في Firebase Console (بدون Web Client ID، مطلوب فقط google-services.json).

## ملاحظة مهمة عن مصادر البيانات
الكود الأصلي فيه ملفين تعريفات مختلفين وغير متطابقين:
- `constants.ts` (بالجذر) — **غير مستخدم فعلياً** في أي شاشة حية، لكن قوائم
  `adminEmails` و`centers` فيه مطابقة لنفس القيم المكتوبة inline في
  `Login.tsx`/`App.tsx` الحقيقيين، فاستخدمناها كمرجع مريح لهذه القيم فقط
  (`lib/constants.dart`).
- `config/constants.ts` — **هو المصدر الحقيقي** المستخدم في كل الشاشات الحية
  (10 مراكز، تسعير مختلف تماماً) → منقول بالكامل في `lib/config_constants.dart`
  ومستخدم في `CustomerDashboard` وكل الشاشات المرتبطة به.

تم الإبقاء على هذا التناقض كما هو بالحرف الواحد التزاماً بطلب عدم تغيير أي منطق.

## حالة النقل
| الجزء | الحالة |
|---|---|
| الثيم (ألوان Tailwind، خط Cairo، ظلال، RTL) | ✅ |
| Models / constants (كلا المصدرين) / utils / order_service | ✅ |
| Firebase (Auth + Firestore + FCM) | ✅ |
| Onboarding + Login (كل التدفقات) | ✅ |
| App shell (الهيدر، الخروج، الإشعارات، التوجيه) | ✅ |
| **CustomerDashboard كاملة** (مشوار/مطاعم/صيدلية + تتبع حي + تقييم + خرائط) | ✅ |
| RestaurantMenuView / ManualRestaurantView / AdsSlider / AdDetailsView | ✅ |
| ChatView / WalletView / ProfileView / ActivityView / AIAssistant (Gemini) | ✅ |
| **CourierDashboard كاملة** (أونلاين/أوفلاين + عروض الأسعار + تتبع GPS حي + خريطة كاملة الشاشة) | ✅ |
| Notifications (FCM حقيقي عبر firebase_messaging) / Support Views | ✅ |
| **كل شاشات الإدارة الـ 6** (SuperAdmin + Operator + إدارة المستخدمين/المطاعم/الإعلانات/الجغرافيا) | ✅ |

## المشروع مكتمل بالكامل الآن 🎉
كل الشاشات الـ 23 منقولة بمنطقها وتصميمها الأصلي حرفياً (~17,400 سطر Dart).

## اعتماديات جديدة (Dart packages فقط، بدون أي تعديل على النسخة الأصلية)
- `flutter_map` + `latlong2` بديل Leaflet
- `file_selector` لاختيار الصور (روشتة الصيدلية، صورة البروفايل)
- `geolocator` لتتبع موقع الكابتن الحي (بديل navigator.geolocation.watchPosition)
- `http` لطلبات OSRM (المسار الفعلي) و Gemini API

## الإشعارات والأذونات (تحديث)
- أول فتح للتطبيق: شاشة شرح ثم طلب إذن الإشعارات والموقع (`lib/services/permission_service.dart`).
- إشعارات محلية + FCM + مستمع Firestore (`lib/services/notification_service.dart`).
- العميل بيطلب مشوار ← الكباتن الأونلاين بيوصلهم إشعار. الكابتن يقدّم سعر ← العميل بيوصله إشعار ويختار الأنسب.
- للإشعارات والتطبيق مقفول: انشر الـ Cloud Function في `functions/` (شوف `functions/README.md`).
