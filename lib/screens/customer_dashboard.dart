import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config_constants.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart' as order_service;
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text.dart';
import '../utils.dart' as utils;
import '../widgets/common.dart';
import '../widgets/leaflet_map.dart';
import 'activity_view.dart';
import 'profile_view.dart';
import 'wallet_view.dart';
import 'chat_view.dart';
import 'ai_assistant.dart';

/// نسخة Flutter من pages/CustomerDashboard.tsx — نفس المنطق والتصميم بالظبط.
class CustomerDashboard extends StatefulWidget {
  final AppUser user;
  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

enum _DashView { newOrder, profile, activity, wallet }

class _CustomerDashboardState extends State<CustomerDashboard> {
  _DashView _activeView = _DashView.newOrder;
  OrderCategory _selectedCategory = OrderCategory.taxi;

  District? _pickupDistrict;
  Village? _pickupVillage;
  final _pickupNoteCtrl = TextEditingController();

  District? _dropoffDistrict;
  Village? _dropoffVillage;
  final _dropoffNoteCtrl = TextEditingController();

  List<Restaurant> _restaurants = [];
  List<Ad> _ads = [];
  Ad? _viewingAd;
  Restaurant? _viewingRestaurant;
  bool _showManualRest = false;

  // Pharmacy
  final _pharmacyNoteCtrl = TextEditingController();
  String? _prescriptionImage; // data:image/...;base64,...

  VehicleType _selectedVehicle = VehicleType.motorcycle;
  Order? _activeOrder;
  List<Offer> _incomingOffers = [];

  double _actualRoadDist = 0;
  bool _isCalculatingDist = false;

  bool _aiOpen = false;
  bool _showChat = false;
  bool _isSubmitting = false;
  String? _acceptingOfferId;

  int _rating = 5;
  final _feedbackCtrl = TextEditingController();
  bool _isRatingSubmitting = false;

  // Tracking
  ll.LatLng? _driverLoc;
  List<ll.LatLng> _routeGeometry = [];

  StreamSubscription? _subRestaurants, _subAds, _subOrders, _subOffers, _subDriver;

  AppUser get user => widget.user;

  @override
  void initState() {
    super.initState();

    _subRestaurants = db
        .collection('restaurants')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _restaurants = snap.docs
            .map((d) => Restaurant.fromMap(
                stripFirestore(d.data()) as Map<String, dynamic>, d.id))
            .toList();
      });
    }, onError: (e) => handleFirestoreError(e, OperationType.list, 'restaurants'));

    _subAds = db
        .collection('ads')
        .orderBy('displayOrder')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _ads = snap.docs
            .map((d) => Ad.fromMap(
                stripFirestore(d.data()) as Map<String, dynamic>, d.id))
            .where((a) => a.isActive)
            .toList();
      });
    }, onError: (e) => handleFirestoreError(e, OperationType.list, 'ads'));

    _subOrders = db
        .collection('orders')
        .where('customerId', isEqualTo: user.id)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final all = snap.docs
          .map((d) => Order.fromMap(
              stripFirestore(d.data()) as Map<String, dynamic>, d.id))
          .toList();
      Order? active;
      for (final o in all) {
        if (o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled) {
          active = o;
          break;
        }
      }
      final prevId = _activeOrder?.id;
      final prevStatus = _activeOrder?.status;
      final prevDriver = _activeOrder?.driverId;
      setState(() => _activeOrder = active);
      if (active?.id != prevId ||
          active?.status != prevStatus ||
          active?.driverId != prevDriver) {
        _onActiveOrderChanged();
      }
    }, onError: (e) => handleFirestoreError(e, OperationType.list, 'orders'));

    _pickupNoteCtrl.addListener(() {});
  }

  @override
  void dispose() {
    _subRestaurants?.cancel();
    _subAds?.cancel();
    _subOrders?.cancel();
    _subOffers?.cancel();
    _subDriver?.cancel();
    _pickupNoteCtrl.dispose();
    _dropoffNoteCtrl.dispose();
    _pharmacyNoteCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  /// مكافئ الـ useEffect الخاص بـ [activeOrder?.id, activeOrder?.status, activeOrder?.driverId]
  void _onActiveOrderChanged() {
    _subOffers?.cancel();
    _subDriver?.cancel();

    final order = _activeOrder;
    if (order != null && order.status == OrderStatus.pending) {
      _subOffers = db
          .collection('offers')
          .where('orderId', isEqualTo: order.id)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        setState(() {
          _incomingOffers = snap.docs
              .map((d) => Offer.fromMap(
                  stripFirestore(d.data()) as Map<String, dynamic>, d.id))
              .toList();
        });
      }, onError: (e) =>
          handleFirestoreError(e, OperationType.list, 'offers (order: ${order.id})'));
    }

    if (order != null &&
        order.driverId != null &&
        order.status != OrderStatus.pending) {
      _subDriver = db
          .collection('users')
          .doc(order.driverId)
          .snapshots()
          .listen((docSnap) async {
        if (!mounted || !docSnap.exists) return;
        final data = docSnap.data();
        final loc = data?['location'];
        if (loc is Map) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          setState(() => _driverLoc = ll.LatLng(lat, lng));
          final dest = order.status == OrderStatus.assigned
              ? order.pickup
              : order.dropoff;
          final geo = await utils.getRouteGeometry(lat, lng, dest.lat, dest.lng);
          if (mounted) {
            setState(() => _routeGeometry =
                geo.map((p) => ll.LatLng(p[0], p[1])).toList());
          }
        }
      }, onError: (e) => handleFirestoreError(
          e, OperationType.get, 'users/${order.driverId}'));
    } else {
      setState(() {
        _driverLoc = null;
        _routeGeometry = [];
      });
    }
  }

  Future<void> _recalcDistance() async {
    final p = _pickupVillage, d = _dropoffVillage;
    if (p == null || d == null) return;
    if (p.id == d.id) {
      setState(() => _actualRoadDist = 0);
      return;
    }
    setState(() => _isCalculatingDist = true);
    try {
      final res = await utils.getRoadDistance(
          p.center.lat, p.center.lng, d.center.lat, d.center.lng);
      if (!mounted) return;
      setState(() {
        _actualRoadDist = res.distance;
        _isCalculatingDist = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isCalculatingDist = false);
    }
  }

  void _onPickupVillageChanged(Village v) {
    setState(() => _pickupVillage = v);
    _recalcDistance();
  }

  void _onDropoffVillageChanged(Village v) {
    setState(() => _dropoffVillage = v);
    _recalcDistance();
  }

  double get _estimatedPrice {
    final p = _pickupVillage, d = _dropoffVillage;
    if (p == null || d == null) return 0;
    if (p.id == d.id) return configDefaultPricing.sameVillagePrice;
    final baseFare =
        configDefaultPricing.basePrice + (_actualRoadDist * configDefaultPricing.pricePerKm);
    final multiplier = configDefaultPricing.multipliers[_selectedVehicle] ?? 1.0;
    final v = baseFare * multiplier;
    return (v < configDefaultPricing.minPrice ? configDefaultPricing.minPrice : v)
        .roundToDouble();
  }

  Future<void> _handleAcceptOffer(Offer offer) async {
    final order = _activeOrder;
    if (order == null) return;
    try {
      await order_service.updateOrderStatus(
          order.id, OrderStatus.assigned, user.id, user.role);
      await db.collection('orders').doc(order.id).update({
        'driverId': offer.driverId,
        'driverName': offer.driverName,
        'driverPhone': offer.driverPhone,
        'driverPhoto': offer.driverPhoto,
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
        'price': offer.price,
      });
      await NotificationService.notifyUser(
        userId: offer.driverId,
        title: 'تم قبول عرضك ✅',
        body: '${user.name} وافق على عرضك ${offer.price.toInt()} ج.م — ابدأ المشوار',
        type: 'SUCCESS',
        key: 'accepted_${order.id}',
        orderId: order.id,
      );
    } catch (e) {
      if (mounted) showAppAlert(context, 'فشل قبول العرض');
    }
  }

  Future<void> _handleCreateOrder({
    Village? deliveryVillage,
    double? price,
    double? distance,
    OrderPlace? pickup,
    String? specialRequest,
    String? restaurantId,
    String? restaurantName,
    List<CartItem>? foodItems,
    String? prescriptionImage,
  }) async {
    final finalVillage = deliveryVillage ?? _dropoffVillage;
    if (finalVillage == null) {
      showAppAlert(context, 'يرجى تحديد مكان التوصيل');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final orderPrice = price ?? _estimatedPrice;
      final orderPickup = (_selectedCategory == OrderCategory.taxi &&
              _pickupVillage != null)
          ? OrderPlace(
              address: _pickupVillage!.name,
              lat: _pickupVillage!.center.lat,
              lng: _pickupVillage!.center.lng,
              villageName: _pickupVillage!.name)
          : pickup;

      final orderData = <String, dynamic>{
        'customerId': user.id,
        'customerPhone': user.phone,
        'category': _selectedCategory.value,
        'paymentMethod': PaymentMethod.cash.value,
        'pickup': orderPickup?.toMap(),
        'dropoff': OrderPlace(
                address: finalVillage.name,
                lat: finalVillage.center.lat,
                lng: finalVillage.center.lng,
                villageName: finalVillage.name)
            .toMap(),
        'requestedVehicleType': _selectedVehicle.value,
        'price': orderPrice,
        'distance': distance ?? _actualRoadDist,
        'pickupNotes': _pickupNoteCtrl.text,
        'dropoffNotes': _dropoffNoteCtrl.text,
        if (specialRequest != null) 'specialRequest': specialRequest,
        if (restaurantId != null) 'restaurantId': restaurantId,
        if (restaurantName != null) 'restaurantName': restaurantName,
        if (foodItems != null)
          'foodItems': foodItems.map((e) => e.toMap()).toList(),
        if (prescriptionImage != null) 'prescriptionImage': prescriptionImage,
      };

      final newOrderId = await order_service.createOrder(orderData);
      await NotificationService.notifyUser(
        userId: UserRole.driver.value,
        title: 'طلب جديد 🛵',
        body:
            '${orderPickup?.villageName ?? "مشوار"} ← ${finalVillage.name} • ${orderPrice.toInt()} ج.م',
        type: 'ALERT',
        key: 'order_$newOrderId',
        orderId: newOrderId,
      );

      // بناء رسالة واتساب تفصيلية وشاملة (نفس نص نسخة الويب بالظبط)
      final catLabel = _selectedCategory == OrderCategory.taxi
          ? '🚖 مشوار'
          : _selectedCategory == OrderCategory.food
              ? '🍔 طلب أكل'
              : '💊 صيدلية';
      final vehicleLabel = _selectedVehicle == VehicleType.toktok
          ? 'توكتوك 🛺'
          : _selectedVehicle == VehicleType.motorcycle
              ? 'موتوسيكل 🏍️'
              : 'سيارة 🚗';

      var foodSummary = '';
      if (foodItems != null && foodItems.isNotEmpty) {
        foodSummary = '\n📋 *الأصناف المطلوبة:*\n' +
            foodItems.map((i) => '- ${i.name} (عدد: ${i.quantity})').join('\n');
      }

      final whatsappMsg = '*📢 طلب جديد من تطبيق وصلها*\n\n'
          '👤 *العميل:* ${user.name}\n'
          '📱 *الهاتف:* ${user.phone}\n'
          '📂 *القسم:* $catLabel\n'
          '📍 *الانطلاق:* ${orderPickup?.villageName ?? "غير محدد"}\n'
          '🏁 *التوصيل:* ${finalVillage.name}\n'
          '🛵 *المركبة:* $vehicleLabel\n'
          '💰 *التكلفة:* $orderPrice ج.م\n'
          '${specialRequest != null ? "📝 *ملاحظة:* $specialRequest\n" : ""}'
          '$foodSummary'
          '\n\n_تم الإرسال من تطبيق وصلها المنوفية_';

      final url = Uri.parse(
          'https://wa.me/201065019364?text=${Uri.encodeComponent(whatsappMsg)}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showAppAlert(context, 'خطأ في إرسال الطلب');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handlePrescriptionUpload() async {
    try {
      const typeGroup =
          XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,$b64';
      final compressed = await utils.compressImage(dataUrl);
      if (mounted) setState(() => _prescriptionImage = compressed);
    } catch (_) {
      // المستخدم لغى اختيار الصورة
    }
  }

  Future<void> _handleRateTrip() async {
    final order = _activeOrder;
    if (order == null) return;
    setState(() => _isRatingSubmitting = true);
    try {
      await db.collection('orders').doc(order.id).update({
        'rating': _rating,
        'feedback': _feedbackCtrl.text.trim(),
        'ratedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _rating = 5;
        _feedbackCtrl.clear();
      });
    } catch (e) {
      if (mounted) showAppAlert(context, 'خطأ في التقييم');
    } finally {
      if (mounted) setState(() => _isRatingSubmitting = false);
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showChat && _activeOrder != null) {
      return ChatView(
        user: user,
        order: _activeOrder!,
        onBack: () => setState(() => _showChat = false),
      );
    }
    if (_activeView == _DashView.wallet) {
      return WalletView(
          user: user, onBack: () => setState(() => _activeView = _DashView.newOrder));
    }
    if (_activeView == _DashView.profile) {
      return ProfileView(
        user: user,
        onUpdate: (_) {},
        onBack: () => setState(() => _activeView = _DashView.newOrder),
        onOpenWallet: () => setState(() => _activeView = _DashView.wallet),
      );
    }
    if (_activeView == _DashView.activity) {
      return ActivityView(
          user: user, onBack: () => setState(() => _activeView = _DashView.newOrder));
    }

    return Stack(
      children: [
        Container(
          color: C.slate50,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 128),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 672),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _activeOrder == null
                              ? _newOrderChildren(context)
                              : [_activeOrderView(context)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _bottomNav(),
        if (_aiOpen) AIAssistant(isOpen: _aiOpen, onClose: () => setState(() => _aiOpen = false)),
        if (_viewingAd != null)
          AdDetailsView(ad: _viewingAd!, onClose: () => setState(() => _viewingAd = null)),
        if (_showManualRest)
          ManualRestaurantView(
            onClose: () => setState(() => _showManualRest = false),
            onConfirm: (data) {
              _handleCreateOrder(
                restaurantName: data.name,
                specialRequest: data.items,
                deliveryVillage: data.village,
                price: 35, // سعر مبدأي تقديري (نفس نسخة الويب)
                pickup: const OrderPlace(
                    address: '', lat: 30.2931, lng: 30.9863, villageName: 'خارجي'),
              );
              setState(() => _showManualRest = false);
            },
          ),
        if (_viewingRestaurant != null)
          RestaurantMenuView(
            restaurant: _viewingRestaurant!,
            initialDropoffVillage: _dropoffVillage,
            initialDistrict: _dropoffDistrict,
            onClose: () => setState(() => _viewingRestaurant = null),
            onConfirmOrder: (cart, foodTotal, deliveryTotal, grandTotal, distance,
                village, specialRequest) {
              _handleCreateOrder(
                restaurantId: _viewingRestaurant!.id,
                restaurantName: _viewingRestaurant!.name,
                foodItems: cart,
                specialRequest: specialRequest,
                price: grandTotal,
                distance: distance,
                deliveryVillage: village,
                pickup: OrderPlace(
                    address: _viewingRestaurant!.name,
                    lat: _viewingRestaurant!.lat,
                    lng: _viewingRestaurant!.lng,
                    villageName: _viewingRestaurant!.address),
              );
              setState(() => _viewingRestaurant = null);
            },
          ),
      ],
    );
  }

  // ── الحالة الافتراضية: طلب جديد ──

  List<Widget> _newOrderChildren(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            scale: 0.95,
            onTap: () => setState(() => _aiOpen = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  C.emerald50.withOpacity(0.9),
                  const Color(0xFFF0FDFA), // teal-50
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.emerald200.withOpacity(0.6)),
                boxShadow: Sh.sm(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.bot, size: 16, color: C.white),
                  ),
                  const SizedBox(width: 8),
                  Text('المساعد الذكي',
                      style: T.s(12, T.w700, C.emerald800)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('توصيل فوري في مراكز وقرى المنوفية',
                      style: T.s(12, T.w700, C.emerald600)),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: C.emerald500, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'أهلاً ${user.name.isNotEmpty ? user.name.split(" ").first : "بك"} 👋',
                style: T.s(isMd(context) ? 30 : 24, T.w900, C.slate900,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text('اطلب مشوار، وجبة، أو علاجك يوصلك لحد عندك',
                  style: T.s(12, T.w600, C.slate500)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 32),
      AdsSlider(ads: _ads, onAdClick: (ad) => setState(() => _viewingAd = ad)),
      if (_ads.isNotEmpty) const SizedBox(height: 32),
      _categorySelector(),
      const SizedBox(height: 32),
      if (_selectedCategory == OrderCategory.pharmacy)
        ..._pharmacyForm()
      else if (_selectedCategory == OrderCategory.food)
        ..._foodForm()
      else
        ..._taxiForm(context),
    ];
  }

  Widget _categorySelector() {
    final cats = [
      (OrderCategory.taxi, 'مشوار', 'توصيل ركاب', '🛵'),
      (OrderCategory.food, 'مطاعم', 'أكل جاهز', '🍔'),
      (OrderCategory.pharmacy, 'صيدلية', 'روشتة وعلاج', '💊'),
    ];
    return Row(
      children: [
        for (var i = 0; i < cats.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: Builder(builder: (context) {
            final c = cats[i];
            final isActive = _selectedCategory == c.$1;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedCategory = c.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [C.emerald600, C.emerald700])
                      : null,
                  color: isActive ? null : C.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: isActive
                          ? C.emerald500
                          : C.slate200.withOpacity(0.6),
                      width: isActive ? 2 : 1),
                  boxShadow: isActive
                      ? Sh.lg(color: C.emerald600.withOpacity(0.25))
                      : Sh.sm(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.$4, style: const TextStyle(fontSize: 24, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(c.$2,
                        style: T.s(14, T.w900, isActive ? C.white : C.slate700)),
                    const SizedBox(height: 2),
                    Text(c.$3,
                        style: T.s(10, T.w600,
                            isActive ? C.emerald100 : C.slate400)),
                  ],
                ),
              ),
            );
          })),
        ],
      ],
    );
  }

  // ── الصيدلية ──

  List<Widget> _pharmacyForm() {
    return [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: C.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.emerald950.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('طلب علاج من الصيدلية',
                          style: T.s(18, T.w800, C.slate900)),
                      const SizedBox(height: 2),
                      Text('ارفع صورة الروشتة أو اكتب أسماء الأدوية',
                          style: T.s(12, T.w500, C.slate500)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.emerald600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.stethoscope,
                      size: 24, color: C.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _textArea(_pharmacyNoteCtrl,
                'اكتب أسماء الأدوية والكميات المطلوبة هنا بالتفصيل...'),
            const SizedBox(height: 16),
            if (_prescriptionImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.memory(
                        base64Decode(_prescriptionImage!.split(',').last),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _prescriptionImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: C.slate900.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.x,
                            size: 16, color: C.white),
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: _handlePrescriptionUpload,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: C.emerald50.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: C.emerald200, width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: Sh.sm(),
                        ),
                        child: const Icon(LucideIcons.image,
                            size: 24, color: C.emerald600),
                      ),
                      const SizedBox(height: 8),
                      Text('إرفاق صورة الروشتة أو علبة الدواء',
                          style: T.s(12, T.w800, C.emerald700)),
                      const SizedBox(height: 4),
                      Text('كاميرا الموبايل أو معرض الصور',
                          style: T.s(10, T.w400, C.slate400)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      LocationSelector(
        label: 'مكان استلام العلاج',
        helper: 'أين سيسلمك الكابتن الطلب؟',
        icon: LucideIcons.checkCircle2,
        iconBg: C.rose500,
        selectedDistrict: _dropoffDistrict,
        selectedVillage: _dropoffVillage,
        onSelectDistrict: (d) => setState(() => _dropoffDistrict = d),
        onSelectVillage: (v) => setState(() => _dropoffVillage = v),
        addressNoteCtrl: _dropoffNoteCtrl,
      ),
      const SizedBox(height: 24),
      PressScale(
        onTap: (_isSubmitting ||
                (_pharmacyNoteCtrl.text.isEmpty && _prescriptionImage == null) ||
                _dropoffVillage == null)
            ? null
            : () => _handleCreateOrder(
                specialRequest: _pharmacyNoteCtrl.text,
                prescriptionImage: _prescriptionImage,
                pickup: const OrderPlace(
                    address: 'صيدلية',
                    lat: 30.2931,
                    lng: 30.9863,
                    villageName: 'أقرب صيدلية')),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.emerald600, C.emerald700]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: Sh.lg(color: C.emerald600.withOpacity(0.25)),
          ),
          child: _isSubmitting
              ? const Spinner()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('اطلب العلاج الآن', style: T.s(15, T.w900, C.white)),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowLeft, size: 16, color: C.white),
                  ],
                ),
        ),
      ),
    ];
  }

  Widget _textArea(TextEditingController c, String hint, {double minHeight = 110}) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: C.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.slate200.withOpacity(0.7)),
      ),
      child: TextField(
        controller: c,
        maxLines: null,
        minLines: 4,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: T.s(13, T.w600, C.slate800),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: T.s(13, T.w500, C.gray400),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  // ── المطاعم ──

  List<Widget> _foodForm() {
    return [
      GestureDetector(
        onTap: () => setState(() => _showManualRest = true),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.slate900, C.slate800]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.slate700.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.plusCircle,
                  size: 24, color: Color(0xCC34D399)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('المطعم مش في القائمة؟',
                        style: T.s(14, T.w800, C.white)),
                    const SizedBox(height: 2),
                    Text('اطلب يدوي من أي مطعم في منطقتك وسنوصله لك',
                        textAlign: TextAlign.right,
                        style: T.s(11, T.w500, const Color(0xE534D399))),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: C.emerald500.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.clipboardList,
                    size: 20, color: Color(0xFF34D399)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (final rest in _restaurants) ...[
        GestureDetector(
          onTap: () => setState(() => _viewingRestaurant = rest),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: C.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: C.slate200.withOpacity(0.6)),
              boxShadow: Sh.sm(),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.chevronRight,
                    size: 20, color: C.slate400),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rest.name,
                          style: T.s(15, T.w900, C.slate800)),
                      const SizedBox(height: 2),
                      Text(rest.category.isNotEmpty
                              ? rest.category
                              : 'وجبات ومأكولات',
                          style: T.s(12, T.w500, C.slate500)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: C.slate100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.slate200.withOpacity(0.5)),
                  ),
                  child: rest.photoURL != null
                      ? SmartImage(rest.photoURL, fit: BoxFit.cover)
                      : const Icon(LucideIcons.utensils,
                          size: 24, color: C.emerald600),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  // ── التاكسي ──

  List<Widget> _taxiForm(BuildContext context) {
    return [
      LocationSelector(
        label: 'نقطة الانطلاق (الركوب)',
        helper: 'من أين ستبدأ الرحلة؟',
        icon: LucideIcons.mapPin,
        iconBg: C.emerald600,
        selectedDistrict: _pickupDistrict,
        selectedVillage: _pickupVillage,
        onSelectDistrict: (d) => setState(() => _pickupDistrict = d),
        onSelectVillage: _onPickupVillageChanged,
        addressNoteCtrl: _pickupNoteCtrl,
      ),
      const SizedBox(height: 20),
      LocationSelector(
        label: 'نقطة الوصول (النزول)',
        helper: 'إلى أين تريد الذهاب؟',
        icon: LucideIcons.checkCircle2,
        iconBg: C.rose500,
        selectedDistrict: _dropoffDistrict,
        selectedVillage: _dropoffVillage,
        onSelectDistrict: (d) => setState(() => _dropoffDistrict = d),
        onSelectVillage: _onDropoffVillageChanged,
        addressNoteCtrl: _dropoffNoteCtrl,
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerRight,
        child: Text('نوع المركبة المفضلة (أسطول وصلها)',
            style: T.s(12, T.w700, C.slate600)),
      ),
      const SizedBox(height: 8),
      _vehicleSelector(),
      if (_pickupVillage != null && _dropoffVillage != null) ...[
        const SizedBox(height: 20),
        _priceEstimateCard(),
      ],
      const SizedBox(height: 24),
      PressScale(
        onTap: (_isSubmitting ||
                _dropoffVillage == null ||
                (_selectedCategory == OrderCategory.taxi &&
                    _pickupVillage == null) ||
                _isCalculatingDist)
            ? null
            : () => _handleCreateOrder(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [C.emerald600, C.emerald700]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: Sh.lg(color: C.emerald600.withOpacity(0.25)),
          ),
          child: _isSubmitting
              ? const Spinner()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.sparkles,
                        size: 18, color: Color(0xFFA7F3D0)),
                    const SizedBox(width: 10),
                    Text('تأكيد وطلب المشوار الآن',
                        style: T.s(15, T.w900, C.white)),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowLeft, size: 16, color: C.white),
                  ],
                ),
        ),
      ),
    ];
  }

  Widget _vehicleSelector() {
    final items = [
      (VehicleType.toktok, 'توكتوك', '🛺', 'اقتصادي وسريع', C.amber500,
          C.amber950, C.amber400.withOpacity(0.5)),
      (VehicleType.car, 'سيارة', '🚗', 'عائلي ومريح', C.slate900, C.white,
          C.slate600.withOpacity(0.7)),
      (VehicleType.motorcycle, 'موتوسيكل', '🏍️', 'فرد واحد فوري',
          C.emerald600, C.white, C.emerald400.withOpacity(0.5)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: Builder(builder: (context) {
            final v = items[i];
            final isSelected = _selectedVehicle == v.$1;
            return GestureDetector(
              onTap: () => setState(() => _selectedVehicle = v.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? v.$5 : C.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isSelected ? v.$5 : C.slate200.withOpacity(0.8),
                      width: isSelected ? 2 : 1),
                  boxShadow: isSelected ? Sh.lg() : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.$3, style: const TextStyle(fontSize: 24, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(v.$2,
                        style: T.s(12, T.w900,
                            isSelected ? v.$6 : C.slate700)),
                    const SizedBox(height: 4),
                    Text(v.$4,
                        textAlign: TextAlign.center,
                        style: T.s(9, T.w600,
                            isSelected ? v.$6.withOpacity(0.9) : C.slate400)),
                  ],
                ),
              ),
            );
          })),
        ],
      ],
    );
  }

  Widget _priceEstimateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            C.emerald500.withOpacity(0.05),
            C.white,
            const Color(0x0D14B8A6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.emerald500.withOpacity(0.20)),
        boxShadow: Sh.md(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: C.emerald600,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Sh.md(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_isCalculatingDist ? '...' : '${_estimatedPrice.toInt()}',
                        style: T.s(24, T.w900, C.white)),
                    const SizedBox(width: 4),
                    Text('ج.م', style: T.s(12, T.w700, C.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('التكلفة التقديرية العادلة',
                          style: T.s(15, T.w900, C.slate900)),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.calculator,
                          size: 16, color: C.emerald600),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isCalculatingDist
                        ? 'جاري قياس المسافة...'
                        : 'المسافة المقدرة: ~${_actualRoadDist.toStringAsFixed(1)} كم',
                    style: T.s(11, T.w500, C.slate500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
              height: 1, color: C.slate100, margin: const EdgeInsets.symmetric(vertical: 4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تسعيرة رسمية معتمدة',
                  style: T.s(11, T.w700, C.emerald600)),
              Text('✨ الدفع نقداً للكابتن عند الوصول',
                  style: T.s(11, T.w500, C.slate500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── حالة الطلب النشط (بحث عن كباتن / تتبع / تقييم) ──

  Widget _activeOrderView(BuildContext context) {
    final order = _activeOrder!;

    // ملاحظة أمانة نقل: في نسخة الويب الأصلية الشرط الأول يقارن بـ
    // OrderStatus.WAITING_FOR_OFFERS وهي قيمة غير موجودة أصلاً في enum
    // OrderStatus (القيم الحقيقية: DRAFT/PENDING/ASSIGNED/PICKED/IN_DELIVERY/
    // DELIVERED/CANCELLED) — فالشرط ده دايماً false في الأصل، فالتصميم هنا
    // بيحافظ على نفس السلوك تماماً (bug-for-bug) بدل ما "يصلحه" من تلقاء نفسه.
    if (order.status == OrderStatus.pending) {
      return _waitingForOffersView(order);
    } else if (order.status == OrderStatus.delivered) {
      return _deliveredRatingView(order);
    } else {
      return _trackingView(context, order);
    }
  }

  /// عروض الأسعار: أحدث عرض لكل كابتن، مرتبة من الأرخص، والعميل بيختار.
  List<Offer> get _sortedOffers {
    final latest = <String, Offer>{};
    for (final o in _incomingOffers) {
      final prev = latest[o.driverId];
      if (prev == null || o.createdAt >= prev.createdAt) latest[o.driverId] = o;
    }
    final list = latest.values.toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  Future<void> _acceptOfferTapped(Offer offer) async {
    if (_acceptingOfferId != null) return;
    setState(() => _acceptingOfferId = offer.id);
    try {
      await _handleAcceptOffer(offer);
    } finally {
      if (mounted) setState(() => _acceptingOfferId = null);
    }
  }

  Future<void> _cancelPendingOrder(Order order) async {
    try {
      await db
          .collection('orders')
          .doc(order.id)
          .update({'status': OrderStatus.cancelled.value});
    } catch (_) {
      if (mounted) showAppAlert(context, 'تعذر إلغاء الطلب');
    }
  }

  Widget _waitingForOffersView(Order order) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: C.white,
            shape: BoxShape.circle,
            border: Border.all(color: C.emerald50, width: 4),
            boxShadow: Sh.xxl(color: C.emerald900.withOpacity(0.1)),
          ),
          child: Pulse(
              child: const Icon(LucideIcons.radar, size: 80, color: C.emerald600)),
        ),
        const SizedBox(height: 24),
        Text('جاري البحث عن كباتن متاحين...',
            textAlign: TextAlign.center,
            style: T.s(24, T.w900, C.slate900, letterSpacing: -0.6)),
        const SizedBox(height: 4),
        Text('ستظهر العروض في الأسفل خلال لحظات',
            style: T.s(11, T.w700, C.slate400)),
        const SizedBox(height: 24),
        for (final offer in _sortedOffers)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: C.emerald50, width: 2),
              boxShadow: Sh.xl(color: C.emerald900.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PressScale(
                  onTap: _acceptingOfferId != null ? null : () => _acceptOfferTapped(offer),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Sh.lg(),
                    ),
                    child: _acceptingOfferId == offer.id
                        ? const Spinner()
                        : Text('قبول ${offer.price.toInt()} ج.م',
                            style: T.s(11, T.w900, C.white)),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(offer.driverName, style: T.s(14, T.w900, C.slate900)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(offer.driverRating > 0
                                ? offer.driverRating.toStringAsFixed(1)
                                : '5.0',
                            style: T.s(10, T.w900, C.amber500)),
                        const SizedBox(width: 2),
                        const Icon(LucideIcons.star,
                            size: 12, color: C.amber400),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _cancelPendingOrder(order),
          child: Text('إلغاء الطلب',
              style: T.s(11, T.w900, C.rose500, letterSpacing: 1.2)),
        ),
      ],
    );
  }

  Widget _deliveredRatingView(Order order) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(64),
        boxShadow: Sh.xxl(),
        border: Border.all(color: C.emerald500.withOpacity(0.1), width: 4),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.partyPopper, size: 96, color: C.emerald500),
          const SizedBox(height: 24),
          Text('وصلت بالسلامة!',
              style: T.s(36, T.w900, C.slate950, letterSpacing: -0.9)),
          const SizedBox(height: 8),
          Text('يرجى تقييم تجربة التوصيل مع الكابتن ${order.driverName ?? ""}',
              textAlign: TextAlign.center,
              style: T.s(14, T.w700, C.slate400)),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: C.slate50,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var s = 1; s <= 5; s++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(LucideIcons.star,
                              size: 48,
                              color: _rating >= s ? C.amber400 : C.slate200),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  constraints: const BoxConstraints(minHeight: 120),
                  child: TextField(
                    controller: _feedbackCtrl,
                    maxLines: null,
                    minLines: 4,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: T.s(13, T.w700, C.slate800),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'هل لديك أي ملاحظات أخرى على الرحلة؟ (اختياري)',
                      hintStyle: T.s(13, T.w700, C.gray400),
                      contentPadding: const EdgeInsets.all(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          PressScale(
            onTap: _isRatingSubmitting ? null : _handleRateTrip,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(24),
                boxShadow: Sh.xxl(),
              ),
              child: _isRatingSubmitting
                  ? const Spinner(size: 32)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.thumbsUp,
                            size: 24, color: C.white),
                        const SizedBox(width: 12),
                        Text('تأكيد وإرسال التقييم',
                            style: T.s(24, T.w900, C.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingView(BuildContext context, Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_driverLoc != null) ...[
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(72),
              border: Border.all(color: C.white, width: 4),
              boxShadow: Sh.xxl(),
            ),
            child: Stack(
              children: [
                WasalhaMap(
                  center: _driverLoc!,
                  zoom: 15,
                  markers: [
                    driverMarker(_driverLoc!),
                    order.status == OrderStatus.assigned
                        ? pickupPointMarker(
                            ll.LatLng(order.pickup.lat, order.pickup.lng))
                        : customerHomeMarker(
                            ll.LatLng(order.dropoff.lat, order.dropoff.lng)),
                  ],
                  routeGeometry: _routeGeometry,
                  fitPoints: [
                    _driverLoc!,
                    order.status == OrderStatus.assigned
                        ? ll.LatLng(order.pickup.lat, order.pickup.lng)
                        : ll.LatLng(order.dropoff.lat, order.dropoff.lng),
                  ],
                ),
                Positioned(
                  top: 24,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IgnorePointer(
                        ignoring: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: C.slate900.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(32),
                            border:
                                Border.all(color: C.white.withOpacity(0.1)),
                            boxShadow: Sh.xxl(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: C.emerald500,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(LucideIcons.timer,
                                    size: 20, color: C.white),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('وصول متوقع',
                                      style: T.s(9, T.w900, C.emerald400,
                                          letterSpacing: 1.4)),
                                  const SizedBox(height: 4),
                                  Text('~ 8-12 دقيقة',
                                      style: T.s(14, T.w900, C.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: C.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: Sh.xl(),
                      border: Border.all(color: C.slate100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PingDot(size: 8, color: C.emerald500),
                        const SizedBox(width: 8),
                        Text('الكابتن يتحرك الآن',
                            style: T.s(9, T.w900, C.slate800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: C.emerald600,
            borderRadius: BorderRadius.circular(48),
            boxShadow: Sh.xl(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: C.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.navigation,
                    size: 32, color: C.white),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('تتبع الرحلة',
                      style: T.s(11, T.w900, C.white.withOpacity(0.6),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(order.status.value,
                      style: T.s(22, T.w900, C.white)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Column(
          children: [
            Container(
              width: 128,
              height: 128,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: C.slate100, width: 8),
                boxShadow: Sh.xxl(),
              ),
              child: order.driverPhoto != null
                  ? SmartImage(order.driverPhoto, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                          (order.driverName?.isNotEmpty ?? false)
                              ? order.driverName!.substring(0, 1)
                              : 'ك',
                          style: T.s(32, T.w900, C.slate400))),
            ),
            const SizedBox(height: 24),
            Text(order.driverName ?? '',
                style: T.s(30, T.w900, C.slate950, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: C.emerald50,
                borderRadius: BorderRadius.circular(999),
              ),
              child:
                  Text('كابتن معتمد', style: T.s(11, T.w700, C.emerald600)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: PressScale(
                onTap: () async {
                  final uri = Uri.parse('tel:${order.driverPhone ?? ""}');
                  await launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.slate950,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: Sh.xl(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.phoneCall,
                          size: 24, color: C.white),
                      const SizedBox(width: 12),
                      Text('اتصال', style: T.s(14, T.w900, C.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PressScale(
                onTap: () => setState(() => _showChat = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.slate100, width: 2),
                    boxShadow: Sh.sm(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.messageCircle,
                          size: 24, color: C.slate900),
                      const SizedBox(width: 12),
                      Text('دردشة', style: T.s(14, T.w900, C.slate900)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── الشريط السفلي ──

  Widget _bottomNav() {
    final tabs = [
      (_DashView.newOrder, LucideIcons.home, 'الرئيسية'),
      (_DashView.activity, LucideIcons.history, 'طلباتي'),
      (_DashView.profile, LucideIcons.user, 'حسابي'),
    ];
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: GlassBox(
            sigma: 20,
            color: C.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: C.white.withOpacity(0.6)),
            shadows: Sh.xl(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final t in tabs)
                  GestureDetector(
                    onTap: () => setState(() => _activeView = t.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color: _activeView == t.$1 ? C.emerald600 : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _activeView == t.$1
                            ? Sh.md(color: C.emerald600.withOpacity(0.25))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.$2,
                              size: 20,
                              color: _activeView == t.$1
                                  ? C.white
                                  : C.slate500),
                          const SizedBox(width: 8),
                          Text(t.$3,
                              style: T.s(
                                  12,
                                  _activeView == t.$1 ? T.w900 : T.w700,
                                  _activeView == t.$1
                                      ? C.white
                                      : C.slate500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ AdsSlider ═══════════════════════

class AdsSlider extends StatelessWidget {
  final List<Ad> ads;
  final void Function(Ad) onAdClick;
  const AdsSlider({super.key, required this.ads, required this.onAdClick});

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) return const SizedBox.shrink();
    final md = isMd(context);
    return SizedBox(
      height: (md ? 400 : MediaQuery.of(context).size.width * 0.85) * 9 / 21,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: ads.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final ad = ads[i];
          final w = md ? 400.0 : MediaQuery.of(context).size.width * 0.85;
          return PressScale(
            onTap: () => onAdClick(ad),
            child: Container(
              width: w,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: C.slate900,
                borderRadius: BorderRadius.circular(40),
                boxShadow: Sh.xl(),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                      opacity: 0.8,
                      child: SmartImage(ad.imageUrl, fit: BoxFit.cover)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          C.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ad.title,
                            style: T.s(18, T.w900, C.white)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          decoration: BoxDecoration(
                            color: C.emerald500,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                              ad.ctaText.isNotEmpty ? ad.ctaText : 'اطلب الآن',
                              style: T.s(10, T.w900, C.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════ AdDetailsView ═══════════════════════

class AdDetailsView extends StatelessWidget {
  final Ad ad;
  final VoidCallback onClose;
  const AdDetailsView({super.key, required this.ad, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GlassBox(
        sigma: 20,
        color: C.slate950.withOpacity(0.9),
        borderRadius: BorderRadius.zero,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512, maxHeight: 700),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(56),
                    boxShadow: Sh.xxl(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 21 / 9,
                            child: SmartImage(ad.imageUrl, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 24,
                            left: 24,
                            child: PressScale(
                              onTap: onClose,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: C.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(LucideIcons.x,
                                    size: 24, color: C.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(ad.title,
                                    style: T.s(24, T.w900, C.slate900,
                                        letterSpacing: -0.4)),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 64,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: C.emerald500,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(ad.description,
                                  textAlign: TextAlign.right,
                                  style: T.s(13, T.w700, C.slate500,
                                      height: 1.7)),
                              if (ad.whatsappNumber != null) ...[
                                const SizedBox(height: 24),
                                PressScale(
                                  onTap: () async {
                                    await db
                                        .collection('ads')
                                        .doc(ad.id)
                                        .update({'clicks': FieldValue.increment(1)});
                                    final uri = Uri.parse(
                                        'https://wa.me/${ad.whatsappNumber}');
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 24),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: Sh.xl(),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(LucideIcons.messageCircle,
                                            size: 24, color: C.white),
                                        const SizedBox(width: 16),
                                        Text(
                                            ad.ctaText.isNotEmpty
                                                ? ad.ctaText
                                                : 'اطلب عبر واتساب',
                                            style:
                                                T.s(16, T.w900, C.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: C.slate50,
                          border: Border(
                              top: BorderSide(color: C.slate100)),
                        ),
                        child: PressScale(
                          onTap: onClose,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.slate900,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text('إغلاق',
                                style: T.s(11, T.w900, C.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ LocationSelector ═══════════════════════

class LocationSelector extends StatefulWidget {
  final String label;
  final String helper;
  final IconData icon;
  final Color iconBg;
  final District? selectedDistrict;
  final Village? selectedVillage;
  final void Function(District) onSelectDistrict;
  final void Function(Village) onSelectVillage;
  final TextEditingController? addressNoteCtrl;
  final bool minimal;

  const LocationSelector({
    super.key,
    required this.label,
    required this.helper,
    required this.icon,
    required this.iconBg,
    required this.selectedDistrict,
    required this.selectedVillage,
    required this.onSelectDistrict,
    required this.onSelectVillage,
    this.addressNoteCtrl,
    this.minimal = false,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  bool _showDistricts = false;
  bool _showVillages = false;

  Future<void> _pickDistrict() async {
    final picked = await _showPicker(
        menofiaData.map((d) => d.name).toList());
    if (picked != null) {
      final d = menofiaData.firstWhere((e) => e.name == picked);
      widget.onSelectDistrict(d);
    }
  }

  Future<void> _pickVillage() async {
    final d = widget.selectedDistrict;
    if (d == null) return;
    final picked = await _showPicker(d.villages.map((v) => v.name).toList());
    if (picked != null) {
      final v = d.villages.firstWhere((e) => e.name == picked);
      widget.onSelectVillage(v);
    }
  }

  Future<String?> _showPicker(List<String> options) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: const BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final o in options)
                  ListTile(
                    title: Text(o,
                        textAlign: TextAlign.right,
                        style: T.s(12, T.w700, C.slate800)),
                    onTap: () => Navigator.of(ctx).pop(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.minimal ? 16 : 24),
      decoration: BoxDecoration(
        color: C.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.emerald950.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.minimal) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.label,
                          style: T.s(18, T.w800, C.slate900)),
                      const SizedBox(height: 2),
                      Text(widget.helper,
                          style: T.s(11, T.w500, C.slate500)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: Sh.md(),
                  ),
                  child: Icon(widget.icon, size: 20, color: C.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _dropdownButton(
                  text: widget.selectedVillage?.name ?? 'اختر القرية',
                  enabled: widget.selectedDistrict != null,
                  open: _showVillages,
                  onTap: widget.selectedDistrict == null
                      ? null
                      : () {
                          setState(() {
                            _showVillages = !_showVillages;
                            _showDistricts = false;
                          });
                          if (_showVillages) _pickVillage();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdownButton(
                  text: widget.selectedDistrict?.name ?? 'اختر المركز',
                  enabled: true,
                  open: _showDistricts,
                  onTap: () {
                    setState(() {
                      _showDistricts = !_showDistricts;
                      _showVillages = false;
                    });
                    if (_showDistricts) _pickDistrict();
                  },
                ),
              ),
            ],
          ),
          if (widget.addressNoteCtrl != null) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: C.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.slate200.withOpacity(0.6)),
              ),
              child: TextField(
                controller: widget.addressNoteCtrl,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: T.s(12, T.w500, C.slate800),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'رقم المنزل، الشارع، علامة مميزة..',
                  hintStyle: T.s(12, T.w500, C.gray400),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdownButton({
    required String text,
    required bool enabled,
    required bool open,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.slate50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: open
                    ? C.emerald500.withOpacity(0.4)
                    : C.slate200.withOpacity(0.7)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.chevronDown,
                  size: 16, color: open ? C.emerald600 : C.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: T.s(11, T.w700, C.slate800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ RestaurantMenuView ═══════════════════════

class RestaurantMenuView extends StatefulWidget {
  final Restaurant restaurant;
  final Village? initialDropoffVillage;
  final District? initialDistrict;
  final VoidCallback onClose;
  final void Function(List<CartItem> cart, double foodTotal, double deliveryTotal,
      double grandTotal, double distance, Village village, String specialRequest) onConfirmOrder;

  const RestaurantMenuView({
    super.key,
    required this.restaurant,
    required this.initialDropoffVillage,
    required this.initialDistrict,
    required this.onClose,
    required this.onConfirmOrder,
  });

  @override
  State<RestaurantMenuView> createState() => _RestaurantMenuViewState();
}

class _RestaurantMenuViewState extends State<RestaurantMenuView> {
  final List<CartItem> _cart = [];
  final _specialRequestCtrl = TextEditingController();
  bool _showFullMenuImage = false;
  double _roadDist = 0;
  bool _isCalculating = false;

  District? _currentDistrict;
  Village? _currentVillage;

  @override
  void initState() {
    super.initState();
    _currentDistrict = widget.initialDistrict;
    _currentVillage = widget.initialDropoffVillage;
    if (_currentVillage != null) _recalc();
  }

  @override
  void dispose() {
    _specialRequestCtrl.dispose();
    super.dispose();
  }

  Future<void> _recalc() async {
    final v = _currentVillage;
    if (v == null) return;
    setState(() => _isCalculating = true);
    try {
      final res = await utils.getRoadDistance(widget.restaurant.lat,
          widget.restaurant.lng, v.center.lat, v.center.lng);
      if (mounted) {
        setState(() {
          _roadDist = res.distance;
          _isCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  // أصناف قديمة ممكن تكون من غير id فكلها كانت بتتحسب كصنف واحد.
  String _keyOf(MenuItem item) =>
      item.id.isNotEmpty ? item.id : '${item.name}_${item.price}';

  void _addToCart(MenuItem item) {
    final key = _keyOf(item);
    setState(() {
      final i = _cart.indexWhere((e) => e.id == key);
      if (i >= 0) {
        _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + 1);
      } else {
        _cart.add(CartItem(id: key, name: item.name, price: item.price, quantity: 1));
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      final i = _cart.indexWhere((e) => e.id == id);
      if (i >= 0) {
        final newQty = _cart[i].quantity - 1;
        if (newQty <= 0) {
          _cart.removeAt(i);
        } else {
          _cart[i] = _cart[i].copyWith(quantity: newQty);
        }
      }
    });
  }

  double get _totalFoodItemsPrice =>
      _cart.fold(0.0, (sum, i) => sum + i.price * i.quantity);

  double get _deliveryPrice {
    final v = _currentVillage;
    if (v == null) return 0;
    final isSameVillage = widget.restaurant.address == v.name;
    if (isSameVillage) return configDefaultPricing.sameVillagePrice;
    final calc = _roadDist * configDefaultPricing.foodOutsidePricePerKm;
    final rounded = calc.roundToDouble();
    return rounded < configDefaultPricing.minPrice
        ? configDefaultPricing.minPrice
        : rounded;
  }

  double get _finalEstimatedPrice => _totalFoodItemsPrice + _deliveryPrice;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: _withMenuViewer(Material(
        color: C.white,
        child: Column(
          children: [
            // Hero
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.28,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SmartImage(
                    widget.restaurant.photoURL,
                    fit: BoxFit.cover,
                    placeholder: Container(color: C.slate900),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xE6000000), Color(0x4D000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 24,
                    child: PressScale(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(LucideIcons.arrowRight,
                            size: 24, color: C.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 32,
                    left: 32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(widget.restaurant.name,
                            style: T.s(30, T.w900, C.white, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.restaurant.address,
                                style: T.s(10, T.w700, C.white.withOpacity(0.7))),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.mapPin,
                                size: 12, color: C.white.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: C.emerald500,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(widget.restaurant.category,
                                  style: T.s(9, T.w900, C.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu content
            Expanded(
              child: Container(
                color: C.slate50,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('منطقة الاستلام (التوصيل)', C.emerald500),
                      const SizedBox(height: 16),
                      LocationSelector(
                        label: '',
                        helper: '',
                        icon: LucideIcons.mapPin,
                        iconBg: C.rose500,
                        selectedDistrict: _currentDistrict,
                        selectedVillage: _currentVillage,
                        onSelectDistrict: (d) => setState(() => _currentDistrict = d),
                        onSelectVillage: (v) {
                          setState(() => _currentVillage = v);
                          _recalc();
                        },
                        minimal: true,
                      ),
                      if (widget.restaurant.menuImageURL != null) ...[
                        const SizedBox(height: 24),
                        PressScale(
                          onTap: () => setState(() => _showFullMenuImage = true),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: C.slate900,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: Sh.xl(),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: C.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(LucideIcons.zoomIn,
                                      size: 24, color: Color(0xFF34D399)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('عرض المنيو الورقي',
                                          style: T.s(14, T.w900, C.white)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'اضغط هنا لرؤية قائمة الطعام الأصلية بالأسعار',
                                          textAlign: TextAlign.right,
                                          style: T.s(10, T.w700,
                                              const Color(0xCC34D399))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('طلب خاص أو صنف غير موجود', C.amber500),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: C.slate100),
                          boxShadow: Sh.sm(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text('اكتب أي حاجة مش لاقيها في القائمة',
                                    style: T.s(10, T.w900, C.slate400,
                                        letterSpacing: 1.2)),
                                const SizedBox(width: 12),
                                const Icon(LucideIcons.edit2,
                                    size: 18, color: C.amber500),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _textArea(_specialRequestCtrl,
                                'مثلاً: رغيف حواوشي زيادة، صنف موسمي، ملاحظات على الأكل...',
                                minHeight: 100),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('أصناف القائمة الرقمية', C.emerald500),
                      const SizedBox(height: 16),
                      if (widget.restaurant.menu.isNotEmpty)
                        for (final item in widget.restaurant.menu) _menuItemRow(item)
                      else
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: C.white,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                                color: C.slate100, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(LucideIcons.clipboardList,
                                  size: 40, color: C.slate200),
                              const SizedBox(height: 8),
                              Text('القائمة الرقمية بانتظار التحديث',
                                  style: T.s(11, T.w700, C.slate400,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text('استخدم المنيو الورقي أو الطلب اليدوي',
                                  style: T.s(9, T.w400, C.slate300)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
              decoration: BoxDecoration(
                color: C.white.withOpacity(0.9),
                border: Border(top: BorderSide(color: C.slate100)),
                boxShadow: Sh.xxl(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.slate50,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: C.slate100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('قيمة الطعام',
                                  style: T.s(9, T.w900, C.slate400,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text('${_totalFoodItemsPrice.toInt()} ج.م',
                                  style: T.s(18, T.w900, C.slate900)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.slate50,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: C.slate100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  'التوصيل لـ ${_currentVillage?.name ?? "..."}',
                                  overflow: TextOverflow.ellipsis,
                                  style: T.s(9, T.w900, C.slate400,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              _isCalculating
                                  ? const Spinner(size: 18, color: C.emerald600)
                                  : Text('${_deliveryPrice.toInt()} ج.م',
                                      style:
                                          T.s(18, T.w900, C.emerald600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PressScale(
                    onTap: (_currentVillage == null ||
                            (_cart.isEmpty && _specialRequestCtrl.text.isEmpty) ||
                            _isCalculating)
                        ? null
                        : () => widget.onConfirmOrder(
                              _cart,
                              _totalFoodItemsPrice,
                              _deliveryPrice,
                              _finalEstimatedPrice,
                              _roadDist,
                              _currentVillage!,
                              _specialRequestCtrl.text,
                            ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: Sh.xxl(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.shoppingBag,
                              size: 28, color: C.white),
                          const SizedBox(width: 16),
                          Text(
                              'تأكيد وإرسال الطلب (${_finalEstimatedPrice.toInt()} ج.م)',
                              style: T.s(20, T.w900, C.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  List<String> get _menuImages {
    final r = widget.restaurant;
    final list = <String>[
      ...?r.menuImageURLs,
      if (r.menuImageURL != null && r.menuImageURL!.isNotEmpty) r.menuImageURL!,
    ].where((e) => e.trim().isNotEmpty).toList();
    return list.toSet().toList();
  }

  Widget _withMenuViewer(Widget body) {
    return Stack(
      children: [
        body,
        if (_showFullMenuImage)
          Positioned.fill(
            child: Material(
              color: const Color(0xF2000000),
              child: Stack(
                children: [
                  PageView(
                    children: [
                      for (final img in _menuImages)
                        InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Center(child: SmartImage(img, fit: BoxFit.contain)),
                        ),
                    ],
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 16,
                    child: PressScale(
                      onTap: () => setState(() => _showFullMenuImage = false),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: C.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 26, color: C.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text, Color barColor) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: barColor, width: 4)),
      ),
      child: Text(text, style: T.s(18, T.w900, C.slate800)),
    );
  }

  Widget _textArea(TextEditingController c, String hint, {double minHeight = 100}) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: C.slate50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: c,
        maxLines: null,
        minLines: 4,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: T.s(13, T.w700, C.slate800),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: T.s(13, T.w700, C.gray400),
          contentPadding: const EdgeInsets.all(20),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _menuItemRow(MenuItem item) {
    final qty = _cart.firstWhere((e) => e.id == _keyOf(item),
            orElse: () => const CartItem(id: '', name: '', price: 0, quantity: 0))
        .quantity;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: C.slate100),
        boxShadow: Sh.sm(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: C.slate50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                PressScale(
                  scale: 0.9,
                  onTap: () => _addToCart(item),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: Sh.lg(),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 28, color: C.white),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$qty',
                      textAlign: TextAlign.center,
                      style: T.s(20, T.w900, C.slate800)),
                ),
                PressScale(
                  scale: 0.9,
                  onTap: qty > 0 ? () => _removeFromCart(_keyOf(item)) : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: qty > 0 ? C.rose500 : C.slate200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.remove_rounded,
                        size: 28, color: qty > 0 ? C.white : C.slate400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: T.s(16, T.w900, C.slate900, height: 1.2)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.price.toStringAsFixed(0),
                              style: T.s(13, T.w900, C.emerald600)),
                          const SizedBox(width: 4),
                          Text('ج.م',
                              style: T.s(10, T.w900,
                                  C.emerald600.withOpacity(0.6))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: C.slate100,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: C.slate50),
                ),
                child: item.photoURL != null
                    ? SmartImage(item.photoURL, fit: BoxFit.cover)
                    : Icon(LucideIcons.utensils,
                        size: 24, color: C.slate200),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════ ManualRestaurantView ═══════════════════════

class ManualRestaurantData {
  final String name;
  final String items;
  final Village village;
  const ManualRestaurantData(
      {required this.name, required this.items, required this.village});
}

class ManualRestaurantView extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(ManualRestaurantData) onConfirm;
  const ManualRestaurantView(
      {super.key, required this.onClose, required this.onConfirm});

  @override
  State<ManualRestaurantView> createState() => _ManualRestaurantViewState();
}

class _ManualRestaurantViewState extends State<ManualRestaurantView> {
  final _restNameCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();
  District? _district;
  Village? _village;

  @override
  void dispose() {
    _restNameCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _restNameCtrl.text.isNotEmpty &&
        _itemsCtrl.text.isNotEmpty &&
        _village != null;
    return Positioned.fill(
      child: Material(
        color: C.slate50,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
              color: C.slate950,
              child: Row(
                children: [
                  PressScale(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: C.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.arrowRight,
                          size: 24, color: C.white),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('طلب من مطعم خارجي',
                          style: T.s(24, T.w900, C.white)),
                      const SizedBox(height: 4),
                      Text('أي مطعم في دماغك هنوصلك منه',
                          style: T.s(10, T.w700, const Color(0xE534D399))),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: C.emerald500, width: 4)),
                        ),
                        child: Text('بيانات المطعم والطلب',
                            style: T.s(18, T.w900, C.slate800)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: C.white,
                        borderRadius: BorderRadius.circular(48),
                        border: Border.all(color: C.slate100),
                        boxShadow: Sh.sm(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: C.slate50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: _restNameCtrl,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: T.s(13, T.w900, C.slate900),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'اسم المطعم (مثال: البرنس، كشري التحرير..)',
                                hintStyle: T.s(13, T.w900, C.gray400),
                                contentPadding: const EdgeInsets.all(24),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            constraints: const BoxConstraints(minHeight: 140),
                            decoration: BoxDecoration(
                              color: C.slate50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextField(
                              controller: _itemsCtrl,
                              maxLines: null,
                              minLines: 5,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: T.s(13, T.w700, C.slate800),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    'اكتب طلباتك هنا بالتفصيل (الوجبات، الأعداد، ملاحظات..)',
                                hintStyle: T.s(13, T.w700, C.gray400),
                                contentPadding: const EdgeInsets.all(24),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(
                              right: BorderSide(color: C.rose500, width: 4)),
                        ),
                        child:
                            Text('مكان التوصيل', style: T.s(18, T.w900, C.slate800)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LocationSelector(
                      label: '',
                      helper: '',
                      icon: LucideIcons.checkCircle2,
                      iconBg: C.rose500,
                      selectedDistrict: _district,
                      selectedVillage: _village,
                      onSelectDistrict: (d) => setState(() => _district = d),
                      onSelectVillage: (v) => setState(() => _village = v),
                      minimal: true,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: C.white,
                boxShadow: Sh.xxl(),
                border: Border(top: BorderSide(color: C.slate100)),
              ),
              child: PressScale(
                onTap: !canSubmit
                    ? null
                    : () => widget.onConfirm(ManualRestaurantData(
                        name: _restNameCtrl.text,
                        items: _itemsCtrl.text,
                        village: _village!)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.slate950,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: Sh.xxl(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.send,
                          size: 24, color: Color(0xFF34D399)),
                      const SizedBox(width: 16),
                      Text('إرسال الطلب الآن', style: T.s(20, T.w900, C.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
