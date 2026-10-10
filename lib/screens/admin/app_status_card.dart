import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/app_status_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';

/// كارت السوبر أدمن: تفعيل / تعطيل التطبيق كله (بيأثر على كل المستخدمين
/// ما عدا السوبر أدمن).
class AppStatusCard extends StatefulWidget {
  final String userId;
  const AppStatusCard({super.key, required this.userId});

  @override
  State<AppStatusCard> createState() => _AppStatusCardState();
}

class _AppStatusCardState extends State<AppStatusCard> {
  AppStatus _status = const AppStatus();
  bool _loaded = false;
  bool _busy = false;
  StreamSubscription<AppStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = appStatusStream().listen((s) {
      if (!mounted) return;
      setState(() {
        _status = s;
        _loaded = true;
      });
    }, onError: (e) {
      debugPrint('app status stream: $e');
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool enable) async {
    if (_busy) return;
    String message = _status.message;
    final ctrl = TextEditingController(text: message);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: C.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(enable ? 'تفعيل التطبيق؟' : 'تعطيل التطبيق؟',
              style: T.s(16, T.w900, C.slate900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  enable
                      ? 'التطبيق هيرجع يشتغل لكل المستخدمين.'
                      : 'كل العملاء والكباتن والمشغّلين هيشوفوا شاشة "متوقف مؤقتاً" ومش هيقدروا يستخدموا التطبيق. حساب السوبر أدمن بس هيفضل شغّال.',
                  style: T.s(12, T.w700, C.slate500, height: 1.6)),
              if (!enable) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  maxLength: 300,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: T.s(12, T.w700, C.slate900),
                  decoration: InputDecoration(
                    hintText: 'رسالة تظهر للمستخدمين (اختياري)',
                    hintStyle: T.s(12, T.w500, C.slate400),
                    filled: true,
                    fillColor: C.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('تراجع', style: T.s(13, T.w700, C.slate500))),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(enable ? 'تفعيل' : 'تعطيل',
                    style: T.s(13, T.w900,
                        enable ? C.emerald600 : C.rose600))),
          ],
        ),
      ),
    );
    message = ctrl.text;
    ctrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await setAppEnabled(
          enabled: enable,
          message: enable ? _status.message : message,
          byUid: widget.userId);
    } catch (e) {
      debugPrint('set app status failed: $e');
      if (mounted) {
        showAppAlert(context, 'تعذر تغيير حالة التطبيق، تأكد من الاتصال والصلاحيات');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status.enabled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: enabled ? C.slate100 : C.rose200),
        boxShadow: Sh.sm(),
      ),
      child: Row(
        children: [
          Switch(
            value: enabled,
            activeColor: C.emerald600,
            onChanged: (!_loaded || _busy) ? null : _toggle,
          ),
          const Spacer(),
          Flexible(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('حالة التطبيق',
                    style: T.s(15, T.w900, C.slate900)),
                const SizedBox(height: 2),
                Text(
                    enabled
                        ? 'شغّال لكل المستخدمين'
                        : 'متوقف — السوبر أدمن بس يقدر يدخل',
                    textAlign: TextAlign.right,
                    style: T.s(11, T.w700,
                        enabled ? C.emerald600 : C.rose600)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enabled ? C.emerald50 : C.rose50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.shieldAlert,
                size: 22, color: enabled ? C.emerald600 : C.rose600),
          ),
        ],
      ),
    );
  }
}
