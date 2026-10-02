// نسخة Dart من services/firebase.ts
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

FirebaseAuth get auth => FirebaseAuth.instance;
FirebaseFirestore get db => FirebaseFirestore.instance;

/// تهيئة Firebase + إعدادات Firestore (تخزين محلي مفعّل زي نسخة الويب).
Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}

enum OperationType { create, update, delete, list, get, write }

/// نفس handleFirestoreError: بيسجّل سياق الخطأ ثم يرمي الاستثناء.
Never handleFirestoreError(
    Object error, OperationType operationType, String? path) {
  final u = auth.currentUser;
  final info = {
    'error': error.toString(),
    'authInfo': {
      'userId': u?.uid,
      'email': u?.email,
      'emailVerified': u?.emailVerified,
      'isAnonymous': u?.isAnonymous,
      'providerInfo': (u?.providerData ?? [])
          .map((p) => {'providerId': p.providerId, 'email': p.email})
          .toList(),
    },
    'operationType': operationType.name,
    'path': path,
  };
  // ignore: avoid_print
  print('Firestore Security Error Context: ${jsonEncode(info)}');
  throw Exception(jsonEncode(info));
}
