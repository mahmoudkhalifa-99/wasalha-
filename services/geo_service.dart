import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:flutter/foundation.dart';

import '../config_constants.dart';
import '../models/models.dart';
import 'firebase_service.dart';

/// يسمع لمجموعة `geo_config` (اللي السوبر أدمن بيعدّلها من "إدارة الجغرافيا")
/// ويحدّث `menofiaData` في الذاكرة، فأي مركز/قرية جديدة تظهر فوراً عند
/// العملاء والكباتن والمشغّل بدون تحديث للتطبيق.
///
/// - لو المجموعة فاضية أو فيه خطأ: القائمة الافتراضية المكتوبة في الكود تفضل شغالة.
/// - ترتيب المراكز: الافتراضية بترتيبها الأصلي، وبعدها المراكز الجديدة بترتيب الإضافة.
class GeoService {
  GeoService._();

  /// بيزيد مع كل تحديث، الشاشات اللي بتعرض القوائم تسمعه عشان تعيد البناء.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static final List<District> _defaults = List.unmodifiable(menofiaData);
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  static void start() {
    if (_sub != null) return;
    _sub = db.collection('geo_config').snapshots().listen((snap) {
      if (snap.docs.isEmpty) return; // نفضل على الافتراضي
      final fromDb = <District>[];
      for (final d in snap.docs) {
        try {
          final m = Map<String, dynamic>.from(stripFirestore(d.data()) as Map);
          m['id'] ??= d.id;
          if ((m['id'] as String).isEmpty) m['id'] = d.id;
          final dist = District.fromMap(m);
          if (dist.name.trim().isNotEmpty) fromDb.add(dist);
        } catch (e) {
          debugPrint('geo_config parse (${d.id}): $e');
        }
      }
      if (fromDb.isEmpty) return;
      final defaultIds = _defaults.map((e) => e.id).toList();
      int rank(District d) {
        final i = defaultIds.indexOf(d.id);
        return i >= 0 ? i : defaultIds.length;
      }

      fromDb.sort((a, b) {
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      menofiaData
        ..clear()
        ..addAll(fromDb);
      revision.value++;
    }, onError: (e) => debugPrint('geo_config listener: $e'));
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
