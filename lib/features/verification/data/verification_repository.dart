import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order, Blob;
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/declaration.dart';
import '../domain/national_id.dart' show normalizeDigits;
import '../domain/unique_keys.dart';
import '../domain/verification_enums.dart';
import '../domain/verification_rules.dart';
import '../models/captain_verification.dart';

/// إعدادات التوثيق (config/verification).
class VerificationConfig {
  final bool enforced;
  final String termsVersion;
  const VerificationConfig({this.enforced = false, this.termsVersion = kTermsVersion});
}

/// الوصول لبيانات التوثيق. كل الحماية الحقيقية في firestore.rules/storage.rules/Functions؛
/// الكود هنا بيتبع نفس القواعد وبيسجّل سجل المراجعة.
class VerificationRepository {
  VerificationRepository({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _st = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _st;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('captain_verifications').doc(uid);

  // ───────── القراءة ─────────

  Stream<CaptainVerification?> watch(String uid) => _ref(uid).snapshots().map(
      (s) => s.exists ? CaptainVerification.fromMap(s.data()!, s.id) : null);

  Stream<VerificationConfig> watchConfig() =>
      _db.collection('config').doc('verification').snapshots().map((s) {
        final d = s.data();
        return VerificationConfig(
          enforced: d?['enforced'] == true,
          termsVersion: (d?['termsVersion'] as String?) ?? kTermsVersion,
        );
      });

  Stream<List<AuditEvent>> watchAudit(String uid) => _ref(uid)
      .collection('audit')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) AuditEvent.fromMap(d.data(), d.id)]);

  // ───────── الكابتن ─────────

  Future<void> _audit(WriteBatch b, String uid, String action, String actor,
      {String? oldStatus, String? newStatus, String? reason}) {
    b.set(_ref(uid).collection('audit').doc(), {
      'captainId': uid,
      'action': action,
      'performedBy': actor,
      'timestamp': _now(),
      if (oldStatus != null) 'oldStatus': oldStatus,
      if (newStatus != null) 'newStatus': newStatus,
      if (reason != null) 'reason': reason,
    });
    return Future.value();
  }

  /// بينشئ وثيقة التوثيق لو مش موجودة (حالة INCOMPLETE من أول مرة).
  Future<void> ensureDoc(String uid) async {
    final snap = await _ref(uid).get();
    if (snap.exists) return;
    final now = _now();
    await _ref(uid).set({
      'captainId': uid,
      'status': VerificationStatus.incomplete.value,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  /// البيانات الأساسية + الضامن. بيسجّل PROFILE_CHANGED لو اتغيّر شيء بعد الحفظ الأول.
  Future<void> saveProfile(
    String uid, {
    required String fullName,
    required String nationalId,
    required String licenseNumber,
    required String plateNumber,
    required Guarantor guarantor,
    CaptainVerification? current,
  }) async {
    await ensureDoc(uid);
    final b = _db.batch();
    b.update(_ref(uid), {
      'fullName': fullName.trim(),
      'nationalId': normalizeDigits(nationalId),
      'licenseNumber': licenseNumber.trim(),
      'plateNumber': plateNumber.trim(),
      'guarantor': guarantor.toMap(),
      'updatedAt': _now(),
    });
    final changed = current != null &&
        (current.fullName != fullName.trim() ||
            current.nationalId != normalizeDigits(nationalId) ||
            current.licenseNumber != licenseNumber.trim() ||
            current.plateNumber != plateNumber.trim() ||
            current.guarantor.nationalId != guarantor.nationalId ||
            current.guarantor.phone != guarantor.phone ||
            current.guarantor.name != guarantor.name);
    if (changed) {
      await _audit(b, uid, AuditAction.profileChanged, uid);
    }
    await b.commit();
  }

  /// يرفع نسخة جديدة من مستند (النسخ القديمة بتتحفظ). الصورة JPEG خاصة، مفيش رابط عام.
  Future<DocVersion> uploadDocument({
    required String uid,
    required DocType type,
    required Uint8List jpegBytes,
    required Map<String, dynamic> quality,
    int? expiresAt,
    String? number,
    CaptainVerification? current,
    bool verified = false,
  }) async {
    await ensureDoc(uid);
    var version = nextDocVersion(current, type);

    // Storage بيمنع الاستبدال: لو النسخة موجودة (رفع سابق نص مكتمل) نجرّب اللي بعدها.
    late Reference ref;
    for (var attempt = 0;; attempt++) {
      ref = _st.ref('captain_docs/$uid/${type.value}/v$version.jpg');
      try {
        await ref.putData(jpegBytes, SettableMetadata(contentType: 'image/jpeg'));
        break;
      } on FirebaseException catch (e) {
        if (attempt >= 2 || e.code != 'unauthorized') rethrow;
        version++;
      }
    }

    final now = _now();
    final doc = DocVersion(
      type: type,
      version: version,
      path: ref.fullPath,
      sha256: sha256Hex(jpegBytes),
      capturedAt: now,
      expiresAt: expiresAt,
      number: number,
      quality: quality,
    );
    final docs = <DocType, DocVersion>{
      ...?current?.activeDocs,
      ...?current?.pendingDocs,
      type: doc,
    };
    final checks = computeChecks(
      docs: docs,
      fullName: current?.fullName ?? '',
      nationalId: current?.nationalId ?? '',
    );
    final b = _db.batch();
    b.set(_ref(uid).collection('documents').doc('${type.value}_v$version'), doc.toMap());
    b.update(_ref(uid), {
      'pendingDocs.${type.value}': doc.toMap(),
      'checks': checks.toMap(),
      if (verified) 'renewalPending': true,
      'updatedAt': now,
    });
    await _audit(
        b, uid, version == 1 ? AuditAction.documentUploaded : AuditAction.documentReplaced, uid,
        reason: type.value);
    await b.commit();
    return doc;
  }

  /// تسجيل الموافقة على الإقرار (النسخة + الوقت + بصمة النص).
  Future<DeclarationAcceptance> acceptDeclaration(String uid) async {
    await ensureDoc(uid);
    final acc = DeclarationAcceptance.now(uid);
    final b = _db.batch();
    b.update(_ref(uid), {'declaration': acc.toMap(), 'updatedAt': _now()});
    await _audit(b, uid, AuditAction.termsAccepted, uid, reason: 'v${acc.termsVersion}');
    await b.commit();
    return acc;
  }

  /// إرسال للمراجعة. القواعد بتتأكد من اكتمال المستندات والإقرار والضامن في السيرفر.
  Future<void> submit(CaptainVerification v) async {
    final from = v.status;
    final b = _db.batch();
    b.update(_ref(v.captainId), {
      'status': VerificationStatus.pendingReview.value,
      'submittedAt': _now(),
      'updatedAt': _now(),
      'checks': computeChecks(
        docs: {...v.activeDocs, ...v.pendingDocs},
        fullName: v.fullName,
        nationalId: v.nationalId,
      ).toMap(),
    });
    await _audit(b, v.captainId, AuditAction.submitted, v.captainId,
        oldStatus: from.value, newStatus: VerificationStatus.pendingReview.value);
    await b.commit();
  }

  /// بعد تأكيد البريد: بنعدّل حقل بسيط عشان الـ Function تعيد حساب البوابة.
  Future<void> requestGateRefresh(String uid) async {
    try {
      await _ref(uid).update({'gateRefreshRequestedAt': _now()});
    } catch (_) {/* مفيش وثيقة بعد أو الحالة مش بتسمح: عادي */}
  }

  // ───────── الأدمن ─────────

  Stream<List<CaptainVerification>> watchByStatus(VerificationStatus s) => _db
      .collection('captain_verifications')
      .where('status', isEqualTo: s.value)
      .snapshots()
      .map((q) {
        final l = [for (final d in q.docs) CaptainVerification.fromMap(d.data(), d.id)];
        l.sort((a, b) => (b.submittedAt ?? b.updatedAt).compareTo(a.submittedAt ?? a.updatedAt));
        return l;
      });

  /// قراءة مستند خاص بطريقة موثّقة (مش بروابط عامة). null لو فشل.
  Future<Uint8List?> readDocBytes(String path) async {
    try {
      return await _st.ref(path).getData(10 * 1024 * 1024);
    } catch (_) {
      return null;
    }
  }

  /// تسجيل فتح ملف كابتن (مرة لكل فتح). من الكلاينت: مش مانع لأدمن بيقرأ Storage مباشرة.
  Future<void> logAccess(String captainId, String adminId) async {
    try {
      await _ref(captainId).collection('audit').add({
        'captainId': captainId,
        'action': 'DOCUMENT_ACCESSED',
        'performedBy': adminId,
        'timestamp': _now(),
      });
    } catch (_) {}
  }

  /// قرار الأدمن. السبب لازم لـ NEEDS_CORRECTION / REJECT / SUSPEND.
  Future<void> review({
    required CaptainVerification v,
    required String adminId,
    required ReviewDecision decision,
    String reason = '',
    List<DocType> correctionDocs = const [],
  }) async {
    final to = switch (decision) {
      ReviewDecision.approve => VerificationStatus.verified,
      ReviewDecision.needsCorrection => VerificationStatus.needsCorrection,
      ReviewDecision.reject => VerificationStatus.rejected,
      ReviewDecision.suspend => VerificationStatus.suspended,
      ReviewDecision.reactivate => VerificationStatus.verified,
    };
    final isRenewal = v.status == VerificationStatus.verified &&
        decision == ReviewDecision.approve;
    if (!isRenewal && !canTransition(v.status, to, Actor.admin)) {
      throw StateError('انتقال غير مسموح: ${v.status.value} → ${to.value}');
    }
    if (transitionNeedsReason(to) && reason.trim().length < 3) {
      throw ArgumentError('السبب مطلوب');
    }
    final now = _now();
    final b = _db.batch();
    final upd = <String, dynamic>{
      'status': to.value,
      'review': ReviewInfo(
        decision: decision.value,
        reason: reason.trim(),
        reviewerId: adminId,
        reviewedAt: now,
        correctionDocs: [for (final d in correctionDocs) d.value],
      ).toMap(),
      'updatedAt': now,
    };

    if (decision == ReviewDecision.approve) {
      // المرفوعات الجديدة تبقى هي المعتمدة، والقديمة تتحول SUPERSEDED (وتفضل محفوظة).
      final m = mergeApprovedDocs(v.activeDocs, v.pendingDocs);
      for (final old in m.superseded) {
        b.update(_ref(v.captainId).collection('documents').doc('${old.type.value}_v${old.version}'),
            {'status': 'SUPERSEDED', 'reviewedBy': adminId, 'reviewedAt': now});
      }
      for (final a in m.activated) {
        b.update(_ref(v.captainId).collection('documents').doc('${a.type.value}_v${a.version}'),
            {'status': 'ACTIVE', 'reviewedBy': adminId, 'reviewedAt': now});
        await _audit(b, v.captainId, AuditAction.documentApproved, adminId, reason: a.type.value);
      }
      final merged = m.active;
      upd['activeDocs'] = CaptainVerification.docsToMap(merged);
      upd['pendingDocs'] = <String, dynamic>{};
      upd['renewalPending'] = false;
    } else if (decision == ReviewDecision.needsCorrection || decision == ReviewDecision.reject) {
      for (final t in correctionDocs) {
        final p = v.pendingDocs[t];
        if (p == null) continue;
        b.update(_ref(v.captainId).collection('documents').doc('${t.value}_v${p.version}'),
            {'status': 'REJECTED', 'reviewedBy': adminId, 'reviewedAt': now});
        await _audit(b, v.captainId, AuditAction.documentRejected, adminId,
            reason: '${t.value}: ${reason.trim()}');
      }
    }
    b.update(_ref(v.captainId), upd);
    await _audit(b, v.captainId, AuditAction.verificationReviewed, adminId,
        oldStatus: v.status.value, newStatus: to.value, reason: reason.trim().isEmpty ? null : reason.trim());
    final special = switch (decision) {
      ReviewDecision.approve when !isRenewal => AuditAction.captainVerified,
      ReviewDecision.suspend => AuditAction.captainSuspended,
      ReviewDecision.reactivate => AuditAction.captainReactivated,
      _ => null,
    };
    if (special != null) {
      await _audit(b, v.captainId, special, adminId,
          oldStatus: v.status.value, newStatus: to.value, reason: reason.trim().isEmpty ? null : reason.trim());
    }
    await b.commit();
  }

  Future<void> setEnforced(bool value, String adminId) =>
      _db.collection('config').doc('verification').set({
        'enforced': value,
        'termsVersion': kTermsVersion,
        'updatedAt': _now(),
        'updatedBy': adminId,
      });

  /// مين الكابتن التاني اللي بنفس القيمة (للأدمن، من unique_keys).
  Future<String?> duplicateOwner(UniqueKeyType t, String rawValue, {required String excludeUid}) async {
    final id = uniqueKeyId(t, rawValue);
    if (id == null) return null;
    final s = await _db.collection('unique_keys').doc(id).get();
    final owner = s.data()?['captainId'] as String?;
    return owner == excludeUid ? null : owner;
  }
}
