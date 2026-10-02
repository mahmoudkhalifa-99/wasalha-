import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/app_shell.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService.init failed: $e');
  }
  // في الـ release أي خطأ في بناء الواجهة كان بيطلع شاشة رمادي بدون سبب.
  // دلوقتي بيظهر نص الخطأ عشان نعرف نصلحه.
  ErrorWidget.builder = (details) => Material(
        color: Colors.white,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Text('UI error:\n${details.exceptionAsString()}',
                style: const TextStyle(fontSize: 11, color: Colors.red)),
          ),
        ),
      );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const WasalhaApp());
}

class WasalhaApp extends StatelessWidget {
  const WasalhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وصلها',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.bgLight,
        colorScheme: ColorScheme.fromSeed(seedColor: C.brandPrimary),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: GoogleFonts.cairoTextTheme(),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: C.emerald600,
          selectionColor: C.emerald500.withOpacity(0.35),
          selectionHandleColor: C.emerald600,
        ),
      ),
      home: const AppShell(),
    );
  }
}
