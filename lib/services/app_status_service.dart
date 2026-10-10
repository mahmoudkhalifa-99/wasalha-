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
  const AppStatus({this.enabled = true, this.message = ''});

  String get displayMessage =>
      message.trim().isEmpty ? kDefaultDisabledMessage : message.trim();

  factory AppStatus.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    if (m == null) return const AppStatus();
    return AppStatus(
      enabled: m['enabled'] != false,
      message: (m['message'] as String?) ?? '',
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
}) =>
    _ref.set({
      'enabled': enabled,
      'message': message.trim(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': byUid,
    });
