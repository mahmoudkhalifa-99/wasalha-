// نسخة Dart من services/orderService.ts — نفس المنطق بالظبط.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/models.dart';
import '../pricing.dart' show goodsTotalOf, tripFareOf;
import 'firebase_service.dart';

String _actor(String fallback) => auth.currentUser?.uid ?? fallback;

/// Strict validation for order status transitions
const Map<OrderStatus, List<OrderStatus>> _validTransitions = {
  OrderStatus.draft: [OrderStatus.pending, OrderStatus.cancelled],
  OrderStatus.pending: [OrderStatus.assigned, OrderStatus.cancelled],
  OrderStatus.assigned: [OrderStatus.picked, OrderStatus.cancelled],
  // الواجهة بتنقل الطلب من PICKED لـ DELIVERED مباشرة (مفيش زر لـ IN_DELIVERY)
  OrderStatus.picked: [
    OrderStatus.inDelivery,
    OrderStatus.delivered,
    OrderStatus.cancelled
  ],
  OrderStatus.inDelivery: [OrderStatus.delivered, OrderStatus.cancelled],
  OrderStatus.delivered: [],
  OrderStatus.cancelled: [],
};

/// Validates if a status transition is allowed
bool isValidTransition(OrderStatus currentStatus, OrderStatus nextStatus) {
  if (currentStatus == nextStatus) return true;
  return _validTransitions[currentStatus]?.contains(nextStatus) ?? false;
}

/// Creates a new order in Firestore. [orderData] هي خريطة حقول الطلب.
Future<String> createOrder(Map<String, dynamic> orderData) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    const initialStatus = OrderStatus.pending;

    // الإجمالي = أجرة التوصيل + تمن البضاعة. بنخزّن الاتنين منفصلين عشان قبول عرض
    // (أجرة توصيل بس) ميمسحش تمن الأكل/الأدوية، وعشان القواعد تتحقق من الحساب.
    final price = (orderData['price'] as num).toDouble();
    var goods = ((orderData['goodsTotal'] as num?) ?? 0).toDouble();
    if (goods < 0) goods = 0;
    if (goods > price) goods = 0;
    final fare = price - goods;

    final newOrder = <String, dynamic>{
      ...orderData,
      'goodsTotal': goods,
      'deliveryFare': fare,
      'baseFare': fare,
      'status': initialStatus.value,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'statusHistory': [
        StatusHistoryItem(
          status: initialStatus,
          changedAt: timestamp,
          changedBy: (orderData['customerId'] as String?) ?? 'SYSTEM',
        ).toMap()
      ],
    };

    final docRef = await db
        .collection('orders')
        .add(stripFirestore(newOrder) as Map<String, dynamic>);
    return docRef.id;
  } catch (error) {
    handleFirestoreError(error, OperationType.create, 'orders');
  }
}

/// Assigns an order to a specific courier
Future<void> assignOrder(
    String orderId, String courierId, String adminId) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();

    if (!orderSnap.exists) throw Exception('Order not found');
    final order = Order.fromMap(orderSnap.data()!, orderSnap.id);

    if (order.status != OrderStatus.pending) {
      throw Exception('Order must be in PENDING status to be assigned');
    }

    final statusHistoryItem = StatusHistoryItem(
      status: OrderStatus.assigned,
      changedAt: timestamp,
      changedBy: _actor(adminId),
    );

    await orderRef.update({
      'status': OrderStatus.assigned.value,
      'assignedTo': courierId,
      'driverId': courierId, // Mapping for backward compatibility if needed
      'acceptedAt': timestamp,
      'updatedAt': timestamp,
      'statusHistory': FieldValue.arrayUnion([statusHistoryItem.toMap()]),
    });

    // Update courier workload
    final courierDocs = await db
        .collection('couriers')
        .where('userId', isEqualTo: courierId)
        .limit(1)
        .get();
    if (courierDocs.docs.isNotEmpty) {
      await courierDocs.docs.first.reference
          .update({'currentOrdersCount': FieldValue.increment(1)});
    }
  } catch (error) {
    handleFirestoreError(error, OperationType.update, 'orders/$orderId');
  }
}

/// Updates the status of an order with validation
Future<void> updateOrderStatus(
  String orderId,
  OrderStatus newStatus,
  String userId,
  UserRole userRole, {
  String? cancelReason,
}) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();

    if (!orderSnap.exists) throw Exception('Order not found');
    final order = Order.fromMap(orderSnap.data()!, orderSnap.id);

    // Access Control
    if (userRole == UserRole.customer && order.customerId != userId) {
      throw Exception('Unauthorized');
    }
    if (userRole == UserRole.driver &&
        (order.assignedTo != userId && order.driverId != userId)) {
      throw Exception('Unauthorized');
    }

    // التسليم النهائي: لازم العميل يكون أكد الاستلام الأول
    if (newStatus == OrderStatus.delivered &&
        userRole == UserRole.driver &&
        !order.customerReceived) {
      throw Exception('لازم العميل يضغط "تم الاستلام" أولاً قبل التسليم النهائي');
    }

    // Lifecycle Validation
    if (!isValidTransition(order.status, newStatus)) {
      throw Exception(
          'Invalid transition from ${order.status.value} to ${newStatus.value}');
    }

    final actor = _actor(userId);
    final statusHistoryItem = StatusHistoryItem(
      status: newStatus,
      changedAt: timestamp,
      changedBy: actor,
    );

    final updates = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': timestamp,
      'statusHistory': FieldValue.arrayUnion([statusHistoryItem.toMap()]),
      if (newStatus == OrderStatus.picked) 'pickedAt': timestamp,
      if (newStatus == OrderStatus.delivered) 'deliveredAt': timestamp,
      if (newStatus == OrderStatus.cancelled) ...{
        'cancelledAt': timestamp,
        'cancelledBy': actor,
        'cancelReason': (cancelReason ?? '').trim().isEmpty
            ? 'بدون سبب'
            : cancelReason!.trim(),
      },
    };

    // If delivered or cancelled, decrement courier workload
    if ((newStatus == OrderStatus.delivered ||
            newStatus == OrderStatus.cancelled) &&
        order.assignedTo != null) {
      final courierDocs = await db
          .collection('couriers')
          .where('userId', isEqualTo: order.assignedTo)
          .limit(1)
          .get();
      if (courierDocs.docs.isNotEmpty) {
        await courierDocs.docs.first.reference
            .update({'currentOrdersCount': FieldValue.increment(-1)});
      }
    }

    await orderRef.update(updates);
  } catch (error) {
    handleFirestoreError(error, OperationType.update, 'orders/$orderId');
  }
}

/// اعتذار الكابتن: الطلب يرجع PENDING ويتشال منه بيانات الكابتن في تحديث واحد.
Future<void> releaseOrderFromCourier(String orderId, String courierId) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final orderRef = db.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists) throw Exception('Order not found');
    final order = Order.fromMap(snap.data()!, snap.id);

    if (order.assignedTo != courierId && order.driverId != courierId) {
      throw Exception('Unauthorized');
    }
    if (order.status != OrderStatus.assigned &&
        order.status != OrderStatus.picked) {
      throw Exception('لا يمكن الاعتذار عن مشوار في هذه الحالة');
    }

    // الطلب يرجع بسعره الأصلي (أجرة التوصيل قبل العرض) + تمن البضاعة.
    final baseFare = order.baseFare ?? order.deliveryFare ?? tripFareOf(order);
    final goods = goodsTotalOf(order);

    await orderRef.update({
      'status': OrderStatus.pending.value,
      'updatedAt': timestamp,
      'deliveryFare': baseFare,
      'price': baseFare + goods,
      // طلب قديم من قبل الحقول دي: نكتبهم مرة عشان يبقى متسق بعد كده
      if (order.baseFare == null) ...{'baseFare': baseFare, 'goodsTotal': goods},
      'acceptedOfferId': FieldValue.delete(),
      if (order.customerReceived) 'customerReceived': false,
      'statusHistory': FieldValue.arrayUnion([
        StatusHistoryItem(
          status: OrderStatus.pending,
          changedAt: timestamp,
          changedBy: courierId,
        ).toMap()
      ]),
      'driverId': FieldValue.delete(),
      'driverName': FieldValue.delete(),
      'driverPhone': FieldValue.delete(),
      'driverPhoto': FieldValue.delete(),
      'acceptedAt': FieldValue.delete(),
      'assignedTo': FieldValue.delete(),
    });

    // عروض الكابتن القديمة على الطلب ده تتمسح (عشان ما يظهرش بسعر قديم).
    try {
      final stale = await db
          .collection('offers')
          .where('orderId', isEqualTo: orderId)
          .where('driverId', isEqualTo: courierId)
          .get();
      for (final d in stale.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('stale offers cleanup failed: $e');
    }

    try {
      final courierDocs = await db
          .collection('couriers')
          .where('userId', isEqualTo: courierId)
          .limit(1)
          .get();
      if (courierDocs.docs.isNotEmpty) {
        await courierDocs.docs.first.reference
            .update({'currentOrdersCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      // تحديث عداد الطلبات اتسبّب بفشل جانبي، مش بنوقف إتمام الطلب بسببه
      debugPrint('courier counter update failed: $e');
    }
  } catch (error) {
    handleFirestoreError(error, OperationType.update, 'orders/$orderId');
  }
}

/// Automatically assigns an order to the courier with the lowest workload
Future<String?> autoAssignOrder(String orderId) async {
  try {
    final querySnapshot = await db
        .collection('couriers')
        .where('isActive', isEqualTo: true)
        .orderBy('currentOrdersCount', descending: false)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return null;

    final bestCourier =
        Courier.fromMap(querySnapshot.docs.first.data(), querySnapshot.docs.first.id);
    await assignOrder(orderId, bestCourier.userId, 'SYSTEM');
    return bestCourier.userId;
  } catch (error) {
    handleFirestoreError(error, OperationType.get, 'couriers');
  }
}

/// إعادة طلب: بيعمل أوردر جديد بنفس العناوين والأصناف والمركبة، بالأجرة الأصلية
/// (baseFare) + تمن البضاعة. الكباتن بيقدّموا عروضهم من جديد زي أي طلب.
Future<String> reorderFrom(Order o, {required String customerId, required String customerPhone}) {
  final fare = o.baseFare ?? o.deliveryFare ?? tripFareOf(o);
  final goods = goodsTotalOf(o);
  return createOrder({
    'customerId': customerId,
    'customerPhone': customerPhone,
    'category': o.category.value,
    'paymentMethod': PaymentMethod.cash.value,
    'pickup': o.pickup.toMap(),
    'dropoff': o.dropoff.toMap(),
    'requestedVehicleType': o.requestedVehicleType.value,
    'price': fare + goods,
    'distance': o.distance,
    if ((o.pickupNotes ?? '').isNotEmpty) 'pickupNotes': o.pickupNotes,
    if ((o.dropoffNotes ?? '').isNotEmpty) 'dropoffNotes': o.dropoffNotes,
    if (o.restaurantId != null) 'restaurantId': o.restaurantId,
    if (o.restaurantName != null) 'restaurantName': o.restaurantName,
    if (o.foodItems != null) 'foodItems': o.foodItems!.map((e) => e.toMap()).toList(),
    if (o.goodsCost != null && o.goodsCost! > 0) 'goodsCost': o.goodsCost,
    'goodsTotal': goods,
  });
}

/// قبول عرض كابتن في عملية واحدة (transaction): الطلب لازم لسه PENDING من غير كابتن،
/// والعرض لازم يكون على نفس الطلب. السعر الجديد = أجرة العرض + تمن البضاعة (مبيمسحش
/// تمن الأكل/الأدوية). لو أي شرط فشل أو الاتصال قطع: مفيش أي تغيير يتكتب.
Future<void> acceptOffer({
  required String orderId,
  required String offerId,
  required String customerId,
}) async {
  try {
    final orderRef = db.collection('orders').doc(orderId);
    final offerRef = db.collection('offers').doc(offerId);
    await db.runTransaction((tx) async {
      final orderSnap = await tx.get(orderRef);
      final offerSnap = await tx.get(offerRef);
      if (!orderSnap.exists) throw Exception('الطلب غير موجود');
      if (!offerSnap.exists) throw Exception('العرض لم يعد متاحاً');

      final order = Order.fromMap(orderSnap.data()!, orderSnap.id);
      final offer =
          Offer.fromMap(stripFirestore(offerSnap.data()!) as Map<String, dynamic>, offerSnap.id);

      if (order.customerId != customerId) throw Exception('Unauthorized');
      if (order.status != OrderStatus.pending || order.driverId != null) {
        throw Exception('الطلب لم يعد متاحاً للقبول');
      }
      if (offer.orderId != orderId) throw Exception('العرض لا يخص هذا الطلب');

      final fare = offer.price;
      final goods = goodsTotalOf(order);
      final now = DateTime.now().millisecondsSinceEpoch;
      final legacy = order.goodsTotal == null;

      tx.update(orderRef, {
        'status': OrderStatus.assigned.value,
        'driverId': offer.driverId,
        'driverName': offer.driverName,
        'driverPhone': offer.driverPhone,
        if (offer.driverPhoto != null) 'driverPhoto': offer.driverPhoto,
        'acceptedAt': now,
        'acceptedOfferId': offerId,
        'deliveryFare': fare,
        'price': fare + goods,
        'updatedAt': now,
        if (legacy) ...{
          'goodsTotal': goods,
          'baseFare': order.price - goods,
        },
        'statusHistory': FieldValue.arrayUnion([
          StatusHistoryItem(
                  status: OrderStatus.assigned,
                  changedAt: now,
                  changedBy: customerId)
              .toMap()
        ]),
      });
    });
  } catch (error) {
    handleFirestoreError(error, OperationType.update, 'orders/$orderId');
  }
}
