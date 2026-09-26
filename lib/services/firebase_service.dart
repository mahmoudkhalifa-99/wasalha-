import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// طبقة الاتصال بـ Firebase - مقابلة لملف services/firebase.ts في نسخة الويب
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => auth.authStateChanges();
  User? get currentAuthUser => auth.currentUser;

  /// بيتفعّل مؤقتًا وقت ما شاشة الدخول/التسجيل بتكون بصدد إنشاء ملف بيانات
  /// المستخدم بنفسها (مثلاً خطوة "إكمال البيانات" بعد جوجل)، عشان الـ AuthGate
  /// ميعملش نسخة افتراضية بديلة تتعارض معاها أثناء نفس اللحظة
  bool isCreatingUserProfile = false;

  // ---------- Auth ----------
  Future<UserCredential> signIn(String email, String password) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register(String email, String password) {
    return auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // المستخدم ممكن يكون سجل دخول بطريقة تانية غير جوجل - نتجاهل الخطأ
    }
    await auth.signOut();
  }

  /// تسجيل الدخول عبر جوجل - مقابلة لـ signInWithPopup(auth, googleProvider) في نسخة الويب
  /// بترجع UserCredential، وبيحدد الكود المستدعي بعدين لو المستخدم جديد (محتاج يكمل بياناته) أو موجود بالفعل
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // المستخدم لغى تسجيل الدخول
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return auth.signInWithCredential(credential);
  }

  // ---------- Users ----------
  Future<void> createUserDoc(String uid, AppUser user) {
    return db.collection('users').doc(uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  /// قائمة إيميلات المديرين الافتراضية - نفس القائمة الموجودة في App.tsx بنسخة الويب
  static const List<String> _adminEmails = [
    'admin@ashmoun.com',
    'mahmoudkhalifa.kh91@gmail.com',
    'sadat.planning.officer@dakahlia.net',
    'admin@wasalah.com',
    'wasalah.app@gmail.com',
  ];

  /// لو مفيش مستند مستخدم في Firestore لحساب مسجل دخول فعليًا (مثلاً حساب
  /// اتعمل يدويًا أو دخل بطريقة لسه مالهاش ملف بيانات)، بننشئله ملف افتراضي -
  /// مطابقة لمنطق fetchUserData في App.tsx بنسخة الويب
  Future<AppUser> ensureUserDoc(User fbUser) async {
    final existing = await getUser(fbUser.uid);
    if (existing != null) return existing;
    final emailLower = (fbUser.email ?? '').toLowerCase();
    final isAdmin = _adminEmails.contains(emailLower);
    final defaultUser = AppUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      name: isAdmin ? 'مدير المنظومة' : (fbUser.displayName ?? 'مستخدم'),
      phone: '01000000000',
      role: isAdmin ? UserRole.ADMIN : UserRole.CUSTOMER,
      status: UserStatus.APPROVED,
      zoneId: 'أشمون',
      wallet: const Wallet(balance: 1000),
    );
    await createUserDoc(fbUser.uid, defaultUser);
    return defaultUser;
  }

  Future<void> updatePhotoUrl(String uid, String url) {
    return db.collection('users').doc(uid).update({'photoURL': url});
  }

  Stream<AppUser?> userStream(String uid) {
    return db.collection('users').doc(uid).snapshots().map(
        (doc) => doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null);
  }

  // ---------- Orders ----------
  Future<DocumentReference<Map<String, dynamic>>> createOrder(Order order) {
    return db.collection('orders').add(order.toCreateMap());
  }

  /// طلبات العميل الحالية (غير المكتملة)، الأحدث أولًا
  Stream<List<Order>> activeOrdersForCustomer(String customerId) {
    return db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: [
          'DRAFT', 'PENDING', 'ASSIGNED', 'PICKED', 'IN_DELIVERY'
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  /// سجل كل طلبات العميل
  Stream<List<Order>> orderHistoryForCustomer(String customerId) {
    return db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  Stream<Order?> orderStream(String orderId) {
    return db.collection('orders').doc(orderId).snapshots().map(
        (d) => d.exists ? Order.fromMap(d.id, d.data()!) : null);
  }

  Future<void> cancelOrder(String orderId) {
    return db.collection('orders').doc(orderId).update({
      'status': 'CANCELLED',
      'cancelledAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------- Restaurants ----------
  Stream<List<Restaurant>> restaurantsStream() {
    return db
        .collection('restaurants')
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Restaurant.fromMap(d.id, d.data())).toList());
  }

  // ---------- Zones ----------
  Future<List<Zone>> getZones() async {
    final snap = await db.collection('zones').get();
    return snap.docs.map((d) => Zone.fromMap(d.id, d.data())).toList();
  }

  Stream<List<Zone>> zonesStream() {
    return db
        .collection('zones')
        .snapshots()
        .map((s) => s.docs.map((d) => Zone.fromMap(d.id, d.data())).toList());
  }

  /// تحميل كل مراكز وقرى المنوفية دفعة واحدة إلى مجموعة zones (batch write)
  Future<void> seedDistrict(String districtId, String districtName,
      List<Map<String, dynamic>> villages) {
    return db.collection('zones').doc(districtId).set({
      'name': districtName,
      'operatorId': '',
      'center': villages.isNotEmpty ? villages.first['center'] : {'lat': 0, 'lng': 0},
      'villages': villages,
    }, SetOptions(merge: true));
  }

  /// إضافة قرية جديدة لمركز معيّن - مقابلة لـ handleAddVillage في
  /// AdminGeographyManager.tsx بنسخة الويب
  Future<void> addVillageToZone(String districtId, Village village) {
    return db.collection('zones').doc(districtId).update({
      'villages': FieldValue.arrayUnion([
        {
          'id': village.id,
          'name': village.name,
          'center': village.center.toMap(),
        }
      ]),
    });
  }

  Future<void> removeVillageFromZone(String districtId, Zone zone, Village village) {
    final updated = zone.villages.where((v) => v.id != village.id).map((v) => {
          'id': v.id,
          'name': v.name,
          'center': v.center.toMap(),
        }).toList();
    return db.collection('zones').doc(districtId).update({'villages': updated});
  }

  /// تعديل إحداثيات قرية موجودة - مقابلة لـ handleUpdateCoords بنسخة الويب
  Future<void> updateVillageCoords(
      String districtId, Zone zone, String villageId, double lat, double lng) {
    final updated = zone.villages.map((v) {
      if (v.id != villageId) {
        return {'id': v.id, 'name': v.name, 'center': v.center.toMap()};
      }
      return {
        'id': v.id,
        'name': v.name,
        'center': {'lat': lat, 'lng': lng},
      };
    }).toList();
    return db.collection('zones').doc(districtId).update({'villages': updated});
  }

  // ---------- Driver / Courier ----------

  /// الطلبات المتاحة للقبول (لسه معندهاش كابتن)
  Stream<List<Order>> pendingOrdersStream() {
    return db
        .collection('orders')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  /// الطلب النشط الحالي لكابتن معيّن (لو موجود)
  Stream<Order?> activeOrderForDriver(String driverId) {
    return db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['ASSIGNED', 'PICKED', 'IN_DELIVERY'])
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : Order.fromMap(s.docs.first.id, s.docs.first.data()));
  }

  /// سجل طلبات الكابتن (المكتملة أو الملغاة)
  Stream<List<Order>> orderHistoryForDriver(String driverId) {
    return db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  /// قبول الكابتن للطلب - يعيّنه كسائق للطلب وينقل الحالة لـ ASSIGNED
  Future<void> acceptOrder(String orderId, AppUser driver) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.collection('orders').doc(orderId).update({
      'driverId': driver.id,
      'driverName': driver.name,
      'driverPhone': driver.phone,
      if (driver.photoURL != null) 'driverPhoto': driver.photoURL,
      'status': 'ASSIGNED',
      'updatedAt': now,
      'statusHistory': FieldValue.arrayUnion([
        {'status': 'ASSIGNED', 'changedAt': now, 'changedBy': driver.id}
      ]),
    });
  }

  /// تحديث حالة الطلب (استلام / جاري التوصيل / تم التسليم)
  Future<void> updateOrderStatus(String orderId, OrderStatus status, String changedBy) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'status': enumToStr(status),
      'updatedAt': now,
      'statusHistory': FieldValue.arrayUnion([
        {'status': enumToStr(status), 'changedAt': now, 'changedBy': changedBy}
      ]),
    };
    if (status == OrderStatus.DELIVERED) data['deliveredAt'] = now;
    await db.collection('orders').doc(orderId).update(data);

    // لما الطلب يتسلّم، نضيف صافي الأرباح (السعر ناقص العمولة) لمحفظة الكابتن تلقائيًا
    if (status == OrderStatus.DELIVERED) {
      final orderDoc = await db.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();
      if (orderData != null && orderData['driverId'] != null) {
        final price = (orderData['price'] as num?)?.toDouble() ?? 0;
        final commission = (orderData['commission'] as num?)?.toDouble() ?? 0;
        await creditDriverWallet(orderData['driverId'], price - commission);
      }
    }
  }

  /// تحديث حالة أونلاين/أوفلاين للكابتن (يُخزَّن على مستند المستخدم نفسه)
  Future<void> setDriverOnline(String driverId, bool isOnline) {
    return db.collection('users').doc(driverId).update({'isOnline': isOnline});
  }

  // ---------- Operator ----------

  /// كل الطلبات (أحدث 100)، لمتابعة الأوبريتور
  Stream<List<Order>> allOrdersStream() {
    return db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  /// كل الكباتن (المعتمدين وغير المعتمدين)
  Stream<List<AppUser>> allDriversStream() {
    return db
        .collection('users')
        .where('role', isEqualTo: 'DRIVER')
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  /// الكباتن المعتمدين فقط - لاستخدامها في التوجيه اليدوي
  Future<List<AppUser>> approvedDrivers() async {
    final snap = await db
        .collection('users')
        .where('role', isEqualTo: 'DRIVER')
        .where('status', isEqualTo: 'APPROVED')
        .limit(30)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  /// توجيه كابتن يدويًا لطلب معيّن من لوحة الأوبريتور
  Future<void> assignDriverManually(String orderId, AppUser driver) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.collection('orders').doc(orderId).update({
      'driverId': driver.id,
      'driverName': driver.name,
      'driverPhone': driver.phone,
      if (driver.photoURL != null) 'driverPhoto': driver.photoURL,
      'status': 'ASSIGNED',
      'updatedAt': now,
      'statusHistory': FieldValue.arrayUnion([
        {'status': 'ASSIGNED', 'changedAt': now, 'changedBy': 'operator'}
      ]),
    });
  }

  // ---------- SuperAdmin ----------

  /// كل المستخدمين في المنظومة
  Stream<List<AppUser>> allUsersStream() {
    return db
        .collection('users')
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateUserStatus(String userId, UserStatus status) {
    return db.collection('users').doc(userId).update({'status': enumToStr(status)});
  }

  Future<void> updateUserRole(String userId, UserRole role) {
    return db.collection('users').doc(userId).update({'role': enumToStr(role)});
  }

  Future<void> deleteUser(String userId) => db.collection('users').doc(userId).delete();

  /// تعديل شامل لبيانات عضو - مقابلة لصفحة AdminEditUser.tsx بنسخة الويب
  /// (ملحوظة أمان: منعمل تحديث لكلمة المرور من هنا كنص مباشر في Firestore
  /// تجنبًا لتخزينها بشكل غير آمن؛ تغيير الباسورد لازم يتم عبر Firebase Auth
  /// من حساب المستخدم نفسه أو بإعادة تعيين رسمية)
  Future<void> updateUserFull({
    required String userId,
    required String name,
    required String phone,
    required String email,
    required UserRole role,
    required UserStatus status,
    VehicleType? vehicleType,
    double? walletBalance,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'role': enumToStr(role),
      'status': enumToStr(status),
    };
    if (role == UserRole.DRIVER) {
      data['vehicleType'] = enumToStr(vehicleType ?? VehicleType.TOKTOK);
    }
    if (walletBalance != null) {
      data['wallet.balance'] = walletBalance;
    }
    return db.collection('users').doc(userId).update(data);
  }

  /// كل المطاعم (مفتوحة ومغلقة) - لإدارة السوبر أدمن
  Stream<List<Restaurant>> allRestaurantsStream() {
    return db
        .collection('restaurants')
        .snapshots()
        .map((s) => s.docs.map((d) => Restaurant.fromMap(d.id, d.data())).toList());
  }

  Future<void> createRestaurant(
      String name, String category, String address, double lat, double lng) {
    final id = 'rest_${DateTime.now().millisecondsSinceEpoch}';
    return db.collection('restaurants').doc(id).set({
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'menu': [],
      'isOpen': true,
    });
  }

  Future<void> updateRestaurant(String id,
      {required String name,
      required String category,
      required String address,
      required double lat,
      required double lng}) {
    return db.collection('restaurants').doc(id).update({
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> deleteRestaurant(String id) {
    return db.collection('restaurants').doc(id).delete();
  }

  Future<void> toggleRestaurantOpen(String id, bool isOpen) {
    return db.collection('restaurants').doc(id).update({'isOpen': isOpen});
  }

  Future<void> addMenuItem(String restaurantId, List<MenuItem> currentMenu, String name, double price) {
    final item = MenuItem(id: 'item_${DateTime.now().millisecondsSinceEpoch}', name: name, price: price);
    final menu = [...currentMenu, item].map((e) => {
          'id': e.id,
          'name': e.name,
          'price': e.price,
          if (e.description != null) 'description': e.description,
          if (e.photoURL != null) 'photoURL': e.photoURL,
        }).toList();
    return db.collection('restaurants').doc(restaurantId).update({'menu': menu});
  }

  Future<void> removeMenuItem(String restaurantId, List<MenuItem> currentMenu, String itemId) {
    final menu = currentMenu.where((e) => e.id != itemId).map((e) => {
          'id': e.id,
          'name': e.name,
          'price': e.price,
          if (e.description != null) 'description': e.description,
          if (e.photoURL != null) 'photoURL': e.photoURL,
        }).toList();
    return db.collection('restaurants').doc(restaurantId).update({'menu': menu});
  }

  // ---------- Chat ----------

  /// رسائل الشات الخاصة بطلب معيّن، مرتبة بالوقت
  Stream<List<ChatMessage>> messagesStream(String orderId) {
    return db
        .collection('messages')
        .where('orderId', isEqualTo: orderId)
        .limit(200)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// إرسال رسالة + تنبيه فوري للطرف التاني (العميل أو الكابتن)
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String senderName,
    required String text,
    String? recipientId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.collection('messages').add({
      'orderId': orderId,
      'senderId': senderId,
      'text': text,
      'createdAt': now,
    });
    if (recipientId != null) {
      await db.collection('notifications').add({
        'userId': recipientId,
        'title': 'رسالة جديدة من $senderName',
        'body': text.length > 50 ? '${text.substring(0, 50)}...' : text,
        'type': 'INFO',
        'createdAt': now,
        'read': false,
        'orderId': orderId,
      });
    }
  }

  // ---------- Notifications ----------

  /// إشعارات المستخدم: الموجهة له شخصيًا + الإشعارات العامة (ALL) + إشعارات
  /// خاصة برتبته (مثلاً كل الكباتن) - مطابقة لاستعلام NotificationsView.tsx
  Stream<List<Map<String, dynamic>>> notificationsStream(String userId, {UserRole? role}) {
    final targets = [userId, 'ALL', if (role != null) enumToStr(role)];
    return db
        .collection('notifications')
        .where('userId', whereIn: targets)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// تعليم كل إشعارات المستخدم كمقروءة دفعة واحدة
  Future<void> markAllNotificationsRead(List<String> ids) async {
    final batch = db.batch();
    for (final id in ids) {
      batch.update(db.collection('notifications').doc(id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> markNotificationRead(String id) {
    return db.collection('notifications').doc(id).update({'read': true});
  }

  /// إرسال تقييم/ملاحظة من المستخدم - مقابلة لملف SupportView.tsx بنسخة الويب
  Future<void> submitFeedback({
    required AppUser user,
    required int rating,
    required String opinion,
  }) {
    return db.collection('feedback').add({
      'userId': user.id,
      'userName': user.name,
      'userPhone': user.phone,
      'rating': rating,
      'opinion': opinion,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<int> unreadNotificationsCount(String userId, {UserRole? role}) {
    return notificationsStream(userId, role: role)
        .map((list) => list.where((n) => n['read'] != true).length);
  }

  /// حفظ توكن FCM الخاص بالجهاز على مستند المستخدم عشان الإشعارات توصله
  Future<void> saveFcmToken(String userId, String token) {
    return db.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeFcmToken(String userId, String token) {
    return db.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  // ---------- Rating ----------

  /// تقييم الرحلة بعد التسليم + إضافة صافي الأرباح لمحفظة الكابتن
  Future<void> rateOrder(Order order, double rating, String feedback) async {
    await db.collection('orders').doc(order.id).update({
      'rating': rating,
      'feedback': feedback,
      'ratedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// إضافة صافي الأرباح لمحفظة الكابتن - تُستدعى تلقائيًا عند تأكيد التسليم
  Future<void> creditDriverWallet(String driverId, double amount) {
    return db.collection('users').doc(driverId).update({
      'wallet.balance': FieldValue.increment(amount),
      'wallet.totalEarnings': FieldValue.increment(amount),
    });
  }

  // ---------- Wallet Withdrawals ----------

  /// طلب سحب أرباح من الكابتن - بينتظر موافقة الإدارة
  Future<void> requestWithdrawal(AppUser driver, double amount) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.collection('withdrawals').add({
      'driverId': driver.id,
      'driverName': driver.name,
      'driverPhone': driver.phone,
      'amount': amount,
      'status': 'PENDING',
      'createdAt': now,
    });
  }

  Stream<List<Map<String, dynamic>>> driverWithdrawalsStream(String driverId) {
    return db
        .collection('withdrawals')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> pendingWithdrawalsStream() {
    return db
        .collection('withdrawals')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// موافقة الإدارة على طلب السحب - بيخصم من الرصيد ويضيف للمسحوب
  Future<void> approveWithdrawal(String withdrawalId, String driverId, double amount) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.collection('withdrawals').doc(withdrawalId).update({
      'status': 'PAID',
      'paidAt': now,
    });
    await db.collection('users').doc(driverId).update({
      'wallet.balance': FieldValue.increment(-amount),
      'wallet.withdrawn': FieldValue.increment(amount),
    });
  }

  Future<void> rejectWithdrawal(String withdrawalId) {
    return db.collection('withdrawals').doc(withdrawalId).update({'status': 'REJECTED'});
  }

  // ---------- Ads (بانرات الرئيسية) ----------
  // مقابلة لمنطق AdsSlider في CustomerDashboard.tsx بنسخة الويب

  Stream<List<Ad>> activeAdsStream() {
    return db
        .collection('ads')
        .orderBy('displayOrder')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Ad.fromMap(d.id, d.data()))
            .where((a) => a.isActive)
            .toList());
  }

  /// كل الإعلانات (فعّالة وغير فعّالة) - لاستخدام لوحة إدارة الإعلانات
  Stream<List<Ad>> allAdsStream() {
    return db.collection('ads').snapshots().map(
        (s) => s.docs.map((d) => Ad.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<void> saveAd(Ad ad) {
    return db.collection('ads').doc(ad.id).set({
      'title': ad.title,
      'description': ad.description,
      'imageUrl': ad.imageUrl,
      'ctaText': ad.ctaText,
      'type': enumToStr(ad.type),
      if (ad.targetId != null) 'targetId': ad.targetId,
      if (ad.whatsappNumber != null) 'whatsappNumber': ad.whatsappNumber,
      'isActive': ad.isActive,
      'displayOrder': ad.displayOrder,
      'views': ad.views,
      'clicks': ad.clicks,
      'createdAt': ad.createdAt,
    });
  }

  Future<void> deleteAd(String adId) => db.collection('ads').doc(adId).delete();

  Future<void> toggleAdActive(String adId, bool isActive) {
    return db.collection('ads').doc(adId).update({'isActive': isActive});
  }

  Future<void> incrementAdClicks(String adId) {
    return db.collection('ads').doc(adId).update({'clicks': FieldValue.increment(1)});
  }

  // ---------- Customer Wallet (شحن/سحب المحفظة الرقمية) ----------
  // مقابلة لملف WalletView.tsx بنسخة الويب

  /// سجل المعاملات المالية للمستخدم (شحن ودفع بالرصيد)، الأحدث أولًا
  Stream<List<WalletTransaction>> walletTransactionsStream(String userId) {
    return db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => WalletTransaction.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// طلب شحن أو سحب من المحفظة الرقمية - بيتحفظ في payment_requests وينتظر
  /// مراجعة الإدارة (بيتبعت كمان عبر واتساب لتسريع المراجعة، بيتم فتحه من الشاشة)
  Future<void> createPaymentRequest({
    required AppUser user,
    required PaymentRequestAction action,
    required double amount,
  }) {
    return db.collection('payment_requests').add({
      'userId': user.id,
      'userName': user.name,
      'userPhone': user.phone,
      'type': enumToStr(action),
      'amount': amount,
      'status': 'PENDING',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
