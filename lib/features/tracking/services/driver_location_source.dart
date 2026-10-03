
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:latlong2/latlong.dart';

import '../../../core/map/geo_utils.dart';
import '../models/tracking_models.dart';

/// مصدر موقع السائق (جهة العميل). مجرّد عشان نقدر نبدّل Firestore بأي Backend.
abstract class DriverLocationSource {
  Stream<GeoFix> watch();
}

/// يقرأ users/{driverId}.location — نفس الشكل اللي بيكتبه التطبيق الحالي:
/// { lat, lng, updatedAt(ms) }.
class FirestoreDriverLocationSource implements DriverLocationSource {
  FirestoreDriverLocationSource(this.driverId, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String driverId;
  final FirebaseFirestore _db;

  @override
  Stream<GeoFix> watch() {
    return _db
        .collection('users')
        .doc(driverId)
        .snapshots()
        .map(_parse)
        .where((f) => f != null)
        .cast<GeoFix>()
        // وثيقة المستخدم بتتحدث لأسباب تانية (token, isOnline...) — نتجاهل
        // أي snapshot موقعه نفس اللي قبله عشان ما نعيدش حساب/Rebuild.
        .distinct((a, b) =>
            a.position == b.position && a.updatedAt == b.updatedAt);
  }

  GeoFix? _parse(DocumentSnapshot<Map<String, dynamic>> snap) {
    final loc = snap.data()?['location'];
    if (loc is! Map) return null;
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat is! num || lng is! num) return null;
    final ts = loc['updatedAt'];
    return GeoFix(
      position: LatLng(lat.toDouble(), lng.toDouble()),
      updatedAt: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : DateTime.now(),
    );
  }
}

/// جهة السائق: يبث الموقع إلى Firestore مع Throttle لتقليل تكلفة الكتابة.
///
/// تنبيه: شاشة الكابتن الحالية (courier_dashboard) بتكتب نفس الحقل. ما تشغّلش
/// الاتنين مع بعض لنفس السائق.
class DriverLocationPublisher {
  DriverLocationPublisher(
    this.driverId, {
    FirebaseFirestore? firestore,
    this.minInterval = const Duration(seconds: 5),
    this.minDistanceMeters = 15,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String driverId;
  final Duration minInterval;
  final double minDistanceMeters;
  final FirebaseFirestore _db;

  LatLng? _lastPos;
  DateTime? _lastAt;

  // كتابة واحدة في نفس الوقت: لو Firestore أوفلاين (persistence شغال) الـ Future
  // مبيكملش، فمن غير الحارس كانت الكتابات بتتراكم في الطابور وتتبعت كلها لما
  // النت يرجع. هنا بنحتفظ بآخر موقع بس.
  bool _writing = false;
  bool _closed = false;
  _LocPayload? _queued;

  void publish(GeoFix fix) {
    if (_closed) return;
    final now = DateTime.now();
    final lp = _lastPos;
    final la = _lastAt;
    if (lp != null && la != null) {
      final age = now.difference(la);
      final tooSoon = age < minInterval;
      final tooClose = distanceMeters(lp, fix.position) < minDistanceMeters;
      // لو قريب جدًا ومعدّاش وقت كفاية: تجاهل. (لو وقف فترة طويلة هنكتب برضه.)
      if (tooSoon || (tooClose && age < const Duration(seconds: 60))) {
        return;
      }
    }
    _lastPos = fix.position;
    _lastAt = now;
    final payload = _LocPayload(
        fix.position.latitude, fix.position.longitude, now.millisecondsSinceEpoch);
    if (_writing) {
      _queued = payload; // آخر موقع بس
      return;
    }
    _write(payload);
  }

  void _write(_LocPayload p) {
    _writing = true;
    _db.collection('users').doc(driverId).update({
      'location': {'lat': p.lat, 'lng': p.lng, 'updatedAt': p.ts},
    }).catchError((Object e) {
      debugPrint('driver location publish failed: $e');
    }).whenComplete(() {
      _writing = false;
      final q = _queued;
      _queued = null;
      if (q != null && !_closed) _write(q);
    });
  }

  /// يوقف أي كتابة جديدة (بيتنادى من TrackingController.dispose).
  void close() {
    _closed = true;
    _queued = null;
  }
}

class _LocPayload {
  const _LocPayload(this.lat, this.lng, this.ts);
  final double lat;
  final double lng;
  final int ts;
}
