import 'package:flutter/material.dart';

import '../../../core/map/geo_utils.dart';
import '../../../core/map/routing_service.dart';
import '../../../theme/app_colors.dart';
import '../controllers/tracking_controller.dart';
import '../models/tracking_models.dart';

/// كارت المعلومات تحت الخريطة: الحالة، المسافة، الوقت المتوقع، والتنبيهات.
class TrackingInfoCard extends StatelessWidget {
  const TrackingInfoCard({super.key, required this.controller});
  final TrackingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AnimatedBuilder(
      animation: Listenable.merge([
        c.status,
        c.driver,
        c.route,
        c.networkOk,
        c.routeUnavailable,
        c.routeLoading,
        c.locationIssue,
      ]),
      builder: (context, _) {
        final status = c.status.value;
        final route = c.route.value;
        final issue = c.locationIssue.value;
        final offline = !c.networkOk.value;
        final routeFailed = c.routeUnavailable.value && c.networkOk.value;
        final busy = c.routeLoading.value || status == TrackingStatus.starting;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                    ),
                  if (offline)
                    const _Banner(
                      color: C.amber100,
                      textColor: C.amber800,
                      icon: Icons.wifi_off_rounded,
                      text: 'لا يوجد اتصال بالإنترنت. بنعرض آخر مسار معروف '
                          'وهنكمّل التحديث أوتوماتيك لما النت يرجع.',
                    ),
                  if (routeFailed)
                    const _Banner(
                      color: C.amber100,
                      textColor: C.amber800,
                      icon: Icons.alt_route_rounded,
                      text: 'تعذّر حساب المسار حاليًا. هنعيد المحاولة تلقائيًا.',
                    ),
                  if (issue != null)
                    _Banner(
                      color: C.rose100,
                      textColor: C.rose700,
                      icon: Icons.location_off_rounded,
                      text: issue.message,
                      actionLabel: issue.actionLabel,
                      onAction: c.openLocationSettings,
                    ),
                  Row(
                    children: [
                      _StatusChip(status: status),
                      const Spacer(),
                      _AgeLabel(fix: c.driver.value),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: Icons.straighten_rounded,
                          label: 'المسافة',
                          value: _distanceText(c, route),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          icon: Icons.schedule_rounded,
                          label: 'الوقت المتوقع',
                          value: route == null ? '—' : formatEta(route.durationSeconds),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _distanceText(TrackingController c, RouteResult? route) {
    if (route != null) return formatDistance(route.distanceMeters);
    final straight = c.straightDistanceMeters;
    if (straight != null) return '≈ ${formatDistance(straight)}';
    return '—';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case TrackingStatus.live:
        text = 'التتبع مباشر';
        bg = C.emerald50;
        fg = C.emerald700;
      case TrackingStatus.waitingForDriver:
        text = 'في انتظار موقع السائق';
        bg = C.amber100;
        fg = C.amber800;
      case TrackingStatus.locationBlocked:
        text = 'الموقع غير متاح';
        bg = C.rose100;
        fg = C.rose700;
      case TrackingStatus.starting:
        text = 'جاري التحميل…';
        bg = C.slate100;
        fg = C.slate600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _AgeLabel extends StatelessWidget {
  const _AgeLabel({required this.fix});
  final GeoFix? fix;

  @override
  Widget build(BuildContext context) {
    final f = fix;
    if (f == null) return const SizedBox.shrink();
    final age = DateTime.now().difference(f.updatedAt);
    // أقل من دقيقتين = حديث كفاية؛ وبنتجاهل فروق ساعة الجهاز السالبة.
    if (age.inMinutes < 2) return const SizedBox.shrink();
    return Text(
      'آخر تحديث منذ ${age.inMinutes} د',
      style: const TextStyle(fontSize: 11, color: C.slate500),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.slate200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: C.emerald600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: C.slate500)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: C.slate800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}
