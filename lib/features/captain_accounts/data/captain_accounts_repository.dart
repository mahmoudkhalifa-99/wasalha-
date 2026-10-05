import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;

import '../../../models/models.dart' show Order, stripFirestore;
import '../domain/captain_accounts.dart';

/// بيانات كابتن للعرض في الحسابات.
class DriverInfo {
  final String id;
  final String name;
  final String phone;
  final bool suspended;

  /// النسبة المحفوظة للكابتن (بالمئة)، أو null = الافتراضية.
  final double? commissionPercent;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.suspended,
    this.commissionPercent,
  });
}

class OrdersSlice {
  final List<TripRow> rows;

  /// true = وصلنا للحد الأقصى للقراءة، فالأرقام ممكن تكون ناقصة.
  final bool capped;
  const OrdersSlice(this.rows, {this.capped = false});
}

/// قراءة بيانات حسابات الكباتن. الفترة بتتفلتر بـ `updatedAt` (استعلام
/// بحقل واحد: مفيش Composite Index مطلوب)، وباقي التجميع في التطبيق.
class CaptainAccountsRepository {
  CaptainAccountsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static const int maxOrders = 5000;

  Future<List<DriverInfo>> loadDrivers() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'DRIVER').get();
    final list = [
      for (final d in snap.docs)
        () {
          final m = d.data();
          final cp = m['commissionPercent'];
          return DriverInfo(
            id: d.id,
            name: (m['name'] as String?) ?? '',
            phone: (m['phone'] as String?) ?? '',
            suspended: (m['status'] as String?) == 'SUSPENDED',
            commissionPercent: cp is num ? cp.toDouble() : null,
          );
        }(),
    ];
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<OrdersSlice> loadOrders(DateRange range) async {
    final snap = await _db
        .collection('orders')
        .where('updatedAt', isGreaterThanOrEqualTo: range.startMs)
        .where('updatedAt', isLessThan: range.endMs)
        .orderBy('updatedAt')
        .limit(maxOrders)
        .get();
    final rows = <TripRow>[];
    for (final d in snap.docs) {
      final o = Order.fromMap(stripFirestore(d.data()) as Map<String, dynamic>, d.id);
      rows.add(TripRow(
        orderId: o.id,
        driverId: o.driverId,
        status: o.status,
        price: o.price,
        atMs: o.updatedAt,
        from: o.pickup.villageName ?? o.pickup.address,
        to: o.dropoff.villageName ?? o.dropoff.address,
      ));
    }
    return OrdersSlice(rows, capped: snap.docs.length >= maxOrders);
  }

  /// يحفظ نسبة الكابتن (بالمئة). null = يرجّعها للافتراضية.
  Future<void> savePercent(String driverId, double? percent) =>
      _db.collection('users').doc(driverId).update({
        'commissionPercent': percent == null ? FieldValue.delete() : percent,
      });
}
