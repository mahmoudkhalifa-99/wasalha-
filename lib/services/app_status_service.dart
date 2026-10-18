// تفعيل / تعطيل التطبيق كله من السوبر أدمن.
// الوثيقة: config/app = { enabled: bool, message: string, updatedAt, updatedBy }
// لو الوثيقة مش موجودة أو القراءة فشلت: التطبيق شغّال (ما نقفلش الناس بسبب عطل شبكة).
import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;

import 'firebase_service.dart';

const String kDefaultDisabledMessage =
    'التطبيق متوقف مؤقتاً. جرّب مرة تانية بعد شوية.';

class AppStatus {
  final bool enabled;
  final String message;

  /// أقل نسخة مسموحة (مثلاً "1.2.0"). فاضي = مفيش حد أدنى. النسخ الأقدم بتتطلب تحديث.
  final String minVersion;
  const AppStatus({this.enabled = true, this.message = '', this.minVersion = ''});

  /// true لو [current] أقدم من [minVersion] (مقارنة رقمية لكل جزء: 1.10.0 > 1.9.0).
  bool requiresUpdate(String current) {
    final min = minVersion.trim();
    if (min.isEmpty || current.isEmpty) return false;
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final a = parts(current), b = parts(min);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }

  String get displayMessage =>
      message.trim().isEmpty ? kDefaultDisabledMessage : message.trim();

  factory AppStatus.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    if (m == null) return const AppStatus();
    return AppStatus(
      enabled: m['enabled'] != false,
      message: (m['message'] as String?) ?? '',
      minVersion: (m['minVersion'] as String?) ?? '',
    );
  }
}

DocumentReference<Map<String, dynamic>> get _ref =>
    db.collection('config').doc('app');

Stream<AppStatus> appStatusStream() => _ref.snapshots().map(AppStatus.fromDoc);

/// السوبر أدمن بس (القواعد بتتحقق).
Future<void> setAppEnabled({
  required bool enabled,
  required String message,
  required String byUid,
  String? minVersion, // null = سيبه زي ما هو
}) =>
    _ref.set({
      'enabled': enabled,
      'message': message.trim(),
      if (minVersion != null) 'minVersion': minVersion.trim(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': byUid,
    }, SetOptions(merge: true));
