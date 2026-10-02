import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'chat_view.dart';
import 'profile_view.dart';

enum _CourierView { home, map, activity, profile }

/// نسخة Flutter من pages/CourierDashboard.tsx — نفس المنطق والتصميم بالظبط.
class CourierDashboard extends StatefulWidget {
  final AppUser user;
  const CourierDashboard({super.key, required this.user});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();
}

class _CourierDashboardState extends State<CourierDashboard> {
  _CourierView _activeView = _CourierView.home;
  Order? _activeOrder;
  List<Order> _availableOrders = [];
  bool _isOnline = true;
  bool _isSubmitting = false;
  String? _showOfferInputFor;
  final _offerPriceCtrl = TextEditingController();
  bool _showChat = false;

  ll.LatLng _currentLocation = const ll.LatLng(30.556, 31.008);
  ll.LatLng? _customerLocation;
  List<ll.LatLng> _routeGeometry = [];

  StreamSubscription<Position>? _posSub;
  StreamSubscription? _subCustomer, _subAvailable, _subActive;

  AppUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    _setOnlineFlag(_isOnline);
    _startLocationWatch();
    _listenOrders();
  }

  @override
  void didUpdateWidget(covariant CourierDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _subCustomer?.cancel();
    _subAvailable?.cancel();
    _subActive?.cancel();
    _offerPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _startLocationWatch() async {
    if (!_isOnline) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        final newLoc = ll.LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() => _currentLocation = newLoc);
        // تحديث موقع الكابتن في Firestore ليراه العميل
        db.collection('users').doc(user.id).update({
          'location': {
            'lat': newLoc.latitude,
            'lng': newLoc.longitude,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        });
        _recalcRoute();
      }, onError: (err) => debugPrint('location error: $err'));
    } catch (err) {
      debugPrint('location watch failed: $err');
    }
  }

  void _stopLocationWatch() {
    _posSub?.cancel();
    _posSub = null;
  }

  void _setOnlineFlag(bool v) {
    db.collection('users').doc(user.id).update({'isOnline': v}).catchError((_) {});
  }

  void _toggleOnline() {
    setState(() => _isOnline = !_isOnline);
    _setOnlineFlag(_isOnline);
    _listenOrders();
    if (_isOnline) {
      _startLocationWatch();
    } else {
      _stopLocationWatch();
    }
  }

  Future<void> _recalcRoute() async {
    final order = _activeOrder;
    if (order == null) {
      if (mounted) setState(() => _routeGeometry = []);
      return;
    }
    final dest =
        order.status == OrderStatus.assigned ? order.pickup : order.dropoff;
    try {
      final geo = await utils.getRouteGeometry(_currentLocation.latitude,
          _currentLocation.longitude, dest.lat, dest.lng);
      if (mounted) {
        setState(() => _routeGeometry = geo.isNotEmpty
            ? geo.map((p) => ll.LatLng(p[0], p[1])).toList()
            : [_currentLocation, ll.LatLng(dest.lat, dest.lng)]);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _routeGeometry = [
              _currentLocation,
              ll.LatLng(dest.lat, dest.lng),
            ]);
      }
    }
  }

  void _listenOrders() {
    _subAvailable?.cancel();
    if (!_isOnline || user.status != UserStatus.approved) {
      // أوفلاين: بنوقف الطلبات الجديدة بس، والمشوار النشط يفضل متابَع.
      if (mounted) setState(() => _availableOrders = []);
      return;
    }
    _subActive?.cancel();

    var firstPending = true;
    _subAvailable = db
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.pending.value)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (firstPending) {
        firstPending = false;
      } else {
        for (final ch in snap.docChanges) {
          if (ch.type != DocumentChangeType.added) continue;
          final m = ch.doc.data();
          if (m == null) continue;
          final o = Order.fromMap(stripFirestore(m) as Map<String, dynamic>, ch.doc.id);
          NotificationService.show(
            key: 'order_${o.id}',
            title: 'طلب جديد 🛵',
            body:
                '${o.restaurantName ?? o.pickup.villageName ?? "مشوار"} ← ${o.dropoff.villageName ?? ""} • ${o.price.toInt()} ج.م',
          );
        }
      }
      setState(() {
        _availableOrders = snap.docs
            .map((d) => Order.fromMap(
                stripFirestore(d.data()) as Map<String, dynamic>, d.id))
            .toList();
      });
    }, onError: (e) =>
        handleFirestoreError(e, OperationType.list, 'orders (pending)'));

    _subActive = db
        .collection('orders')
        .where('driverId', isEqualTo: user.id)
        .snapshots()
        .listen((snap) {
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
      final changed = active?.id != _activeOrder?.id ||
          active?.status != _activeOrder?.status;
      if (!mounted) return;
      setState(() => _activeOrder = active);
      if (changed) {
        _recalcRoute();
        _listenCustomerLocation();
      }
    }, onError: (e) =>
        handleFirestoreError(e, OperationType.list, 'orders (active_driver)'));
  }

  void _listenCustomerLocation() {
    _subCustomer?.cancel();
    final order = _activeOrder;
    if (order == null) {
      setState(() => _customerLocation = null);
      return;
    }
    _subCustomer = db
        .collection('users')
        .doc(order.customerId)
        .snapshots()
        .listen((docSnap) {
      if (!mounted || !docSnap.exists) return;
      final loc = docSnap.data()?['location'];
      if (loc is Map) {
        setState(() => _customerLocation = ll.LatLng(
            (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()));
      }
    }, onError: (e) => handleFirestoreError(
        e, OperationType.get, 'users/${order.customerId}'));
  }

  Future<void> _handleSendOffer(String orderId) async {
    final price = double.tryParse(_offerPriceCtrl.text);
    if (price == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final userSnap = await db.collection('users').doc(user.id).get();
      final userData = userSnap.data();
      final rating = (userData?['rating'] as num?)?.toDouble() ?? 5.0;
      final photo = userData?['photoURL'] as String?;

      final offerRef = await db.collection('offers').add({
        'orderId': orderId,
        'driverId': user.id,
        'driverName': user.name,
        'driverPhone': user.phone,
        'driverRating': rating,
        'driverPhoto': photo,
        'vehicleType': (user.vehicleType ?? VehicleType.toktok).value,
        'price': price,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      final target = _availableOrders.where((o) => o.id == orderId).toList();
      if (target.isNotEmpty) {
        await NotificationService.notifyUser(
          userId: target.first.customerId,
          title: 'وصلك عرض سعر جديد 💰',
          body: 'الكابتن ${user.name} عرض ${price.toInt()} ج.م على طلبك',
          type: 'SUCCESS',
          key: 'offer_${offerRef.id}',
          orderId: orderId,
        );
      }
      setState(() {
        _showOfferInputFor = null;
        _offerPriceCtrl.clear();
      });
      if (mounted) showAppAlert(context, 'تم إرسال عرضك للعميل بنجاح');
    } catch (e) {
      if (mounted) showAppAlert(context, 'خطأ في إرسال العرض');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _updateOrderStatus(OrderStatus status) async {
    final order = _activeOrder;
    if (order == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await order_service.updateOrderStatus(order.id, status, user.id, user.role);
    } catch (e) {
      if (mounted) {
        showAppAlert(context, 'فشل تحديث الحالة: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleRejectOrder() async {
    final order = _activeOrder;
    if (order == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: C.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('تأكيد الاعتذار', style: T.s(16, T.w900, C.slate900)),
          content: Text(
              'هل تريد الاعتذار عن هذا المشوار؟ سيعود الطلب متاحاً للكباتن الآخرين.',
              style: T.s(13, T.w600, C.slate600)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('تراجع', style: T.s(13, T.w700, C.slate500))),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('نعم، اعتذار', style: T.s(13, T.w900, C.rose600))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await order_service.updateOrderStatus(
          order.id, OrderStatus.pending, user.id, user.role);
      await db.collection('orders').doc(order.id).update({
        'driverId': FieldValue.delete(),
        'driverName': FieldValue.delete(),
        'driverPhone': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'assignedTo': FieldValue.delete(),
      });
      if (mounted) showAppAlert(context, 'تم الاعتذار عن المشوار بنجاح');
    } catch (e) {
      if (mounted) showAppAlert(context, 'فشل الاعتذار');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (user.status != UserStatus.approved) {
      return _pendingApprovalScreen();
    }
    if (_showChat && _activeOrder != null) {
      return ChatView(
        user: user,
        order: _activeOrder!,
        onBack: () => setState(() => _showChat = false),
      );
    }
    if (_activeView == _CourierView.activity) {
      return ActivityView(
          user: user, onBack: () => setState(() => _activeView = _CourierView.home));
    }
    if (_activeView == _CourierView.profile) {
      return ProfileView(
        user: user,
        onUpdate: (_) {},
        onBack: () => setState(() => _activeView = _CourierView.home),
      );
    }

    return Stack(
      children: [
        Container(
          color: C.slate50,
          child: Offstage(
            offstage: _activeView == _CourierView.map,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 128),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _onlineStatusCard(),
                        const SizedBox(height: 32),
                        if (_activeOrder != null)
                          _activeOrderCard(_activeOrder!)
                        else
                          _availableOrdersList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_activeView == _CourierView.map) _mapView(context),
        _bottomNav(),
      ],
    );
  }

  Widget _pendingApprovalScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.shieldAlert, size: 80, color: C.emerald600),
            const SizedBox(height: 24),
            Text('حسابك بانتظار التفعيل',
                textAlign: TextAlign.center,
                style: T.s(30, T.w900, C.slate900, letterSpacing: -0.6)),
            const SizedBox(height: 12),
            Text('يرجى التواصل مع الإدارة للبدء في استقبال الطلبات.',
                textAlign: TextAlign.center,
                style: T.s(13, T.w700, C.slate400)),
            const SizedBox(height: 24),
            PressScale(
              onTap: () => launchUrl(Uri.parse('https://wa.me/201065019364'),
                  mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: Sh.xl(),
                ),
                child: Text('تواصل عبر واتساب',
                    style: T.s(15, T.w900, C.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineStatusCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: _isOnline
            ? const LinearGradient(colors: [C.emerald700, C.emerald600])
            : null,
        color: _isOnline ? null : C.slate950,
        borderRadius: BorderRadius.circular(48),
        boxShadow: Sh.xxl(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            scale: 0.9,
            onTap: _toggleOnline,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isOnline ? C.white : C.emerald500,
                borderRadius: BorderRadius.circular(32),
                boxShadow: Sh.xxl(),
              ),
              child: Icon(LucideIcons.power,
                  size: 36, color: _isOnline ? C.emerald600 : C.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isOnline ? 'نشط ومستعد' : 'متوقف',
                      style: T.s(30, T.w900, C.white, letterSpacing: -0.6)),
                  const SizedBox(width: 8),
                  _isOnline
                      ? Pulse(
                          child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF6EE7B7),
                                  shape: BoxShape.circle)))
                      : Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: C.slate500, shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: C.white.withOpacity(0.2)),
                    ),
                    child: Text(
                        user.vehicleType == VehicleType.toktok
                            ? '🛺 كابتن توكتوك'
                            : user.vehicleType == VehicleType.car
                                ? '🚗 كابتن سيارة'
                                : '🏍️ كابتن دليفري',
                        style: T.s(11, T.w900, C.white)),
                  ),
                  const SizedBox(width: 8),
                  Text('وصلها المنوفية',
                      style: T.s(10, T.w700, C.white.withOpacity(0.75))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _availableOrdersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
              'مشاوير بانتظارك في المنوفية (${_availableOrders.length})',
              textAlign: TextAlign.right,
              style: T.s(11, T.w900, C.slate400, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 24),
        for (final o in _availableOrders) _availableOrderCard(o),
        if (_availableOrders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 96),
            decoration: BoxDecoration(
              color: C.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(64),
              border: Border.all(
                  color: C.slate100, width: 4, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.bot, size: 64, color: C.slate200),
                const SizedBox(height: 24),
                Text('بانتظار طلبات جديدة من مراكز المنوفية...',
                    style: T.s(11, T.w900, C.slate300, letterSpacing: 1.4)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _availableOrderCard(Order o) {
    final isOfferOpen = _showOfferInputFor == o.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(56),
        border: Border.all(color: C.slate50, width: 2),
        boxShadow: Sh.xl(),
      ),
      child: isOfferOpen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تقديم عرض سعر للمشوار',
                    textAlign: TextAlign.center,
                    style: T.s(20, T.w900, C.slate900)),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: C.slate50,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 4,
                          spreadRadius: -1,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: TextField(
                    controller: _offerPriceCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: T.s(48, T.w900, C.slate900),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: o.price.toStringAsFixed(0),
                      hintStyle: T.s(48, T.w900, C.gray400),
                      contentPadding: const EdgeInsets.all(32),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showOfferInputFor = null),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('إلغاء',
                              textAlign: TextAlign.center,
                              style: T.s(14, T.w900, C.slate400)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: PressScale(
                        onTap: () => _handleSendOffer(o.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: C.emerald600,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow:
                                Sh.xl(color: C.emerald900.withOpacity(0.2)),
                          ),
                          child: _isSubmitting
                              ? const Spinner()
                              : Text('إرسال العرض',
                                  style: T.s(14, T.w900, C.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: C.slate950,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: Sh.xxl(),
                      ),
                      child: Text('${o.price.toInt()}',
                          style: T.s(30, T.w900, C.emerald400)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${o.restaurantName ?? o.pickup.villageName ?? ""} ← ${o.dropoff.villageName ?? ""}',
                              textAlign: TextAlign.right,
                              style: T.s(20, T.w900, C.slate950, height: 1.2)),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: C.emerald50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(o.requestedVehicleType.value,
                                    style: T.s(10, T.w900, C.emerald600)),
                              ),
                              if (o.category == OrderCategory.food)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: C.amber50,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('طلب مطعم 🍔',
                                      style: T.s(10, T.w900, C.amber500)),
                                ),
                            ],
                          ),
                          if (o.foodItems != null || o.specialRequest != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide(color: C.slate100)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (o.foodItems != null)
                                      Text(
                                          'الأصناف: ${o.foodItems!.map((i) => i.name).join("، ")}',
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.s(9, T.w700, C.slate400)),
                                    if (o.specialRequest != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: C.amber50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('طلب يدوي خاص متوفر',
                                                  style: T.s(9, T.w900,
                                                      C.amber500)),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                  LucideIcons.clipboardList,
                                                  size: 12,
                                                  color: C.amber500),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PressScale(
                  onTap: () => setState(() {
                    _showOfferInputFor = o.id;
                    _offerPriceCtrl.text = o.price.toStringAsFixed(0);
                  }),
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
                        const Icon(LucideIcons.zap,
                            size: 24, color: Color(0xFF34D399)),
                        const SizedBox(width: 16),
                        Text('تقديم عرض سريع',
                            style: T.s(20, T.w900, C.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── بطاقة الطلب النشط ──

  Widget _activeOrderCard(Order order) {
    final isAssigned = order.status == OrderStatus.assigned;
    final isPicked =
        order.status == OrderStatus.picked || order.status == OrderStatus.inDelivery;
    final destLabel = isAssigned ? 'التوجه للاستلام من' : 'التوجه للتسليم في';
    final destValue =
        isAssigned ? (order.pickup.villageName ?? '') : (order.dropoff.villageName ?? '');
    final destNotes = isAssigned ? order.pickupNotes : order.dropoffNotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(56),
            border: Border.all(color: C.emerald100, width: 2),
            boxShadow: Sh.xxl(color: C.emerald900.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PressScale(
                    onTap: () => setState(() => _activeView = _CourierView.map),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.emerald50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.navigation,
                          size: 20, color: C.emerald600),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('مشوار جاري الآن',
                          style: T.s(10, T.w900, C.emerald600,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(order.status.value,
                          style: T.s(20, T.w900, C.slate950)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.slate50,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isAssigned ? C.rose500 : C.emerald500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(destLabel,
                                    style: T.s(9, T.w900, C.slate400,
                                        letterSpacing: 1.2)),
                                const SizedBox(height: 2),
                                Text(destValue,
                                    textAlign: TextAlign.right,
                                    style: T.s(16, T.w900, C.slate900)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (destNotes != null && destNotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: C.slate200)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(destNotes,
                                    textAlign: TextAlign.right,
                                    style: T.s(11, T.w700, C.slate600)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.mapPin,
                                  size: 14, color: C.slate400),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (order.foodItems != null && order.foodItems!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.amber50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.amber200.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('محتويات الطلب:',
                          style: T.s(10, T.w900, C.amber500,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      for (final item in order.foodItems!)
                        Text('- ${item.name} (${item.quantity}x)',
                            textAlign: TextAlign.right,
                            style: T.s(11, T.w700, C.slate700)),
                    ],
                  ),
                ),
              ],
              if (order.specialRequest != null &&
                  order.specialRequest!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.blue600.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.blue600.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('طلب خاص من العميل:',
                          style: T.s(10, T.w900, C.blue600,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(order.specialRequest!,
                          textAlign: TextAlign.right,
                          style: T.s(11, T.w700, C.slate700)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PressScale(
                      onTap: () async {
                        final phone = order.customerPhone;
                        await launchUrl(Uri.parse('tel:$phone'));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.slate950,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(LucideIcons.phoneCall,
                            size: 20, color: C.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressScale(
                      onTap: () => setState(() => _showChat = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: C.slate100, width: 2),
                        ),
                        child: const Icon(LucideIcons.messageCircle,
                            size: 20, color: C.slate900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isAssigned)
                PressScale(
                  onTap: _isSubmitting
                      ? null
                      : () => _updateOrderStatus(OrderStatus.picked),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: Sh.xl(color: C.emerald600.withOpacity(0.3)),
                    ),
                    child: _isSubmitting
                        ? const Spinner()
                        : Text('تأكيد الاستلام', style: T.s(16, T.w900, C.white)),
                  ),
                )
              else if (isPicked)
                PressScale(
                  onTap: _isSubmitting
                      ? null
                      : () => _updateOrderStatus(OrderStatus.delivered),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: Sh.xl(color: C.emerald600.withOpacity(0.3)),
                    ),
                    child: _isSubmitting
                        ? const Spinner()
                        : Text('تأكيد التسليم النهائي',
                            style: T.s(16, T.w900, C.white)),
                  ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isSubmitting ? null : _handleRejectOrder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('اعتذار عن المشوار',
                      textAlign: TextAlign.center,
                      style: T.s(11, T.w700, C.rose400)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── شاشة الخريطة ──

  Widget _mapView(BuildContext context) {
    final order = _activeOrder;
    final dest = order == null
        ? null
        : (order.status == OrderStatus.assigned ? order.pickup : order.dropoff);

    return Positioned.fill(
      child: Material(
        color: C.white,
        child: Stack(
          children: [
            WasalhaMap(
              center: _currentLocation,
              zoom: 15,
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 48,
                  height: 48,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: C.emerald600,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.white, width: 3),
                      boxShadow: Sh.xl(),
                    ),
                    child: const Icon(LucideIcons.navigation,
                        size: 20, color: C.white),
                  ),
                ),
                if (dest != null)
                  order?.status == OrderStatus.assigned
                      ? pickupPointMarker(ll.LatLng(dest.lat, dest.lng))
                      : customerHomeMarker(ll.LatLng(dest.lat, dest.lng)),
              ],
              routeGeometry: _routeGeometry,
              fitPoints: dest == null
                  ? null
                  : [_currentLocation, ll.LatLng(dest.lat, dest.lng)],
            ),
            Positioned(
              top: 48,
              right: 24,
              left: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PressScale(
                    onTap: () => setState(() => _activeView = _CourierView.home),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: C.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: Sh.xl(),
                      ),
                      child: const Icon(LucideIcons.arrowRight,
                          size: 24, color: C.slate900),
                    ),
                  ),
                  if (dest != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.slate900,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: Sh.xl(),
                      ),
                      child: Text(
                          order!.status == OrderStatus.assigned
                              ? 'الوجهة: نقطة الاستلام'
                              : 'الوجهة: العميل',
                          style: T.s(11, T.w900, C.white)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── الشريط السفلي ──

  Widget _bottomNav() {
    if (_activeView == _CourierView.map) return const SizedBox.shrink();
    final tabs = [
      (_CourierView.home, LucideIcons.home, 'الرئيسية'),
      (_CourierView.map, LucideIcons.map, 'الخريطة'),
      (_CourierView.activity, LucideIcons.history, 'سجلي'),
      (_CourierView.profile, LucideIcons.user, 'حسابي'),
    ];
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: C.white.withOpacity(0.95),
          border: Border(top: BorderSide(color: C.slate100)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(56)),
          boxShadow: Sh.xxl(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final t in tabs)
              GestureDetector(
                onTap: () => setState(() => _activeView = t.$1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
                      decoration: BoxDecoration(
                        color: _activeView == t.$1 ? C.emerald50 : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(t.$2,
                          size: 24,
                          color:
                              _activeView == t.$1 ? C.emerald600 : C.slate300),
                    ),
                    const SizedBox(height: 4),
                    Text(t.$3,
                        style: T.s(
                            11,
                            T.w900,
                            _activeView == t.$1 ? C.emerald600 : C.slate300,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
