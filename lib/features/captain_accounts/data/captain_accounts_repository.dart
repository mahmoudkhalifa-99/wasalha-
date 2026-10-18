import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;

import '../../../models/models.dart' show Order, stripFirestore;
import '../../../pricing.dart' show commissionBaseOf;
import '../domain/captain_accounts.dart';

/// بيانات كابتن للعرض في الحسابات.
class DriverInfo {
  final String id;
  final String name;
  final String phone;
  final bool suspended;

  /// نسبة عمولة محفوظة للكابتن (%)، أو null = الافتراضية (16%).
  final double? commissionPercent;

  /// العمولة المستحقة فعلاً (من محفظة الكابتن: بتتزوّد عند كل تسليم وبتنقص بالسداد).
  final double commissionDue;
  final double commissionPaid;

  const DriverInfo({
    this.commissionDue = 0,
    this.commissionPaid = 0,
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
            commissionDue: _num((m['wallet'] as Map?)?['commissionDue']),
            commissionPaid: _num((m['wallet'] as Map?)?['commissionPaid']),
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
        base: commissionBaseOf(o),
        atMs: o.updatedAt,
        from: o.pickup.villageName ?? o.pickup.address,
        to: o.dropoff.villageName ?? o.dropoff.address,
      ));
    }
    return OrdersSlice(rows, capped: snap.docs.length >= maxOrders);
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0;

  /// تسجيل سداد عمولة من كابتن: سجل تسوية + خصم من المستحق + معاملة + سجل مراجعة،
  /// كله في batch واحد (يا كله يتكتب يا مفيش).
  Future<void> recordSettlement({
    required String driverId,
    required double amount,
    required String adminId,
    String note = '',
  }) async {
    if (amount <= 0) throw Exception('المبلغ لازم يكون أكبر من صفر');
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    final sRef = _db.collection('settlements').doc();
    batch.set(sRef, {
      'driverId': driverId,
      'amount': amount,
      'note': note,
      'createdBy': adminId,
      'createdAt': now,
    });
    batch.update(_db.collection('users').doc(driverId), {
      'wallet.commissionDue': FieldValue.increment(-amount),
      'wallet.commissionPaid': FieldValue.increment(amount),
    });
    batch.set(_db.collection('transactions').doc('settlement_${sRef.id}'), {
      'userId': driverId,
      'type': 'CREDIT',
      'kind': 'SETTLEMENT',
      'amount': amount,
      'description': 'سداد عمولة للتطبيق${note.isEmpty ? '' : ' — $note'}',
      'createdAt': now,
      'createdBy': adminId,
    });
    batch.set(_db.collection('admin_audit').doc(), {
      'action': 'COMMISSION_SETTLEMENT',
      'targetUserId': driverId,
      'amount': amount,
      'performedBy': adminId,
      'createdAt': now,
    });
    await batch.commit();
  }

  /// يحفظ نسبة عمولة الكابتن (%). null = يرجّعها للافتراضية (16%).
  Future<void> saveCommission(String driverId, double? percent) =>
      _db.collection('users').doc(driverId).update({
        'commissionPercent': percent == null ? FieldValue.delete() : percent,
      });
}
