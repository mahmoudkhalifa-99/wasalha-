// التسعير والعمولة من Firestore (config/pricing) بدل ما يكونوا مكتوبين في الكود بس.
// لو الوثيقة مش موجودة أو القراءة فشلت: بنكمّل بالقيم الافتراضية في config_constants.dart.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:flutter/foundation.dart' show debugPrint;

import '../config_constants.dart';
import 'firebase_service.dart';

StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pricingSub;

/// بيبدأ (أو يعيد) الاستماع لـ config/pricing. بيتنده بعد تسجيل الدخول (القراءة للمسجّلين).
void startPricingConfigSync() {
  _pricingSub?.cancel();
  _pricingSub = db.collection('config').doc('pricing').snapshots().listen(
    (snap) => applyPricingConfig(snap.exists ? snap.data() : null),
    onError: (e) => debugPrint('pricing config unavailable: $e'),
  );
}

void stopPricingConfigSync() {
  _pricingSub?.cancel();
  _pricingSub = null;
}

Future<void> savePricingConfig(Map<String, dynamic> values, String byUid) =>
    db.collection('config').doc('pricing').set({
      ...values,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': byUid,
    });
