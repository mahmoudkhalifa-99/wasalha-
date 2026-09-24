import 'package:flutter/material.dart';
import '../../data/menofia_data.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

/// تبويب "إدارة المنوفية" - عرض مراكز وقرى المحافظة، وتحميلها لقاعدة بيانات
/// Firestore (مجموعة zones) عشان تُستخدم في تحديد مناطق التوصيل والتسعير.
class VillagesTab extends StatefulWidget {
  const VillagesTab({super.key});

  @override
  State<VillagesTab> createState() => _VillagesTabState();
}

class _VillagesTabState extends State<VillagesTab> {
  bool seedingAll = false;
  String? seedingDistrictId;
  String? addingToDistrictId;
  final newVillageCtrl = TextEditingController();
  String? editingVillageId;
  final editLatCtrl = TextEditingController();
  final editLngCtrl = TextEditingController();

  @override
  void dispose() {
    newVillageCtrl.dispose();
    editLatCtrl.dispose();
    editLngCtrl.dispose();
    super.dispose();
  }

  Future<void> _addVillage(String districtId) async {
    if (newVillageCtrl.text.trim().isEmpty) return;
    final village = Village(
      id: 'v_${DateTime.now().millisecondsSinceEpoch}',
      name: newVillageCtrl.text.trim(),
      center: const GeoPointSimple(lat: 30.556, lng: 31.008),
    );
    await FirebaseService.instance.addVillageToZone(districtId, village);
    newVillageCtrl.clear();
    setState(() => addingToDistrictId = null);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إضافة القرية بنجاح')));
    }
  }

  Future<void> _removeVillage(String districtId, Zone zone, Village v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف قرية "${v.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await FirebaseService.instance.removeVillageFromZone(districtId, zone, v);
  }

  void _startEditCoords(Village v) {
    setState(() {
      editingVillageId = v.id;
      editLatCtrl.text = v.center.lat.toString();
      editLngCtrl.text = v.center.lng.toString();
    });
  }

  Future<void> _saveCoords(String districtId, Zone zone, String villageId) async {
    final lat = double.tryParse(editLatCtrl.text.trim());
    final lng = double.tryParse(editLngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى إدخال أرقام صحيحة للإحداثيات')));
      return;
    }
    await FirebaseService.instance.updateVillageCoords(districtId, zone, villageId, lat, lng);
    setState(() => editingVillageId = null);
  }

  Future<void> _seedDistrict(DistrictData d) async {
    setState(() => seedingDistrictId = d.id);
    try {
      final villages = d.villages
          .map((v) => {
                'id': v.id,
                'name': v.name,
                'center': {'lat': v.lat, 'lng': v.lng},
              })
          .toList();
      await FirebaseService.instance.seedDistrict(d.id, d.name, villages);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم تحميل مركز ${d.name} بنجاح')));
      }
    } finally {
      if (mounted) setState(() => seedingDistrictId = null);
    }
  }

  Future<void> _seedAll() async {
    setState(() => seedingAll = true);
    try {
      for (final d in menofiaDistricts) {
        final villages = d.villages
            .map((v) => {
                  'id': v.id,
                  'name': v.name,
                  'center': {'lat': v.lat, 'lng': v.lng},
                })
            .toList();
        await FirebaseService.instance.seedDistrict(d.id, d.name, villages);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحميل كل مراكز المنوفية وقراها بنجاح')));
      }
    } finally {
      if (mounted) setState(() => seedingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Zone>>(
      stream: FirebaseService.instance.zonesStream(),
      builder: (context, snap) {
        final zones = snap.data ?? [];
        final loadedIds = zones.map((z) => z.id).toSet();
        Zone? zoneFor(String id) {
          for (final z in zones) {
            if (z.id == id) return z;
          }
          return null;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('مراكز وقرى محافظة المنوفية',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                ElevatedButton.icon(
                  onPressed: seedingAll ? null : _seedAll,
                  icon: seedingAll
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('تحميل الكل'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'كل المراكز التسعة محمّلة بقراها بالكامل (${menofiaDistricts.fold<int>(0, (s, d) => s + d.villages.length)} قرية إجمالاً)، ومركز أشمون هو المركز الأساسي للتطبيق.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...menofiaDistricts.map((d) {
              final loaded = loadedIds.contains(d.id);
              final isMain = d.id == 'd-ashmoun';
              final zone = zoneFor(d.id);
              // لو المركز محمّل فعليًا، بنعرض قراه الحية من Firestore (بما فيها
              // أي قرى مخصصة ضافها الأدمن)؛ لو لسه مش محمّل بنعرض المعاينة الثابتة
              final liveVillages = zone?.villages;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isMain ? AppColors.primary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: isMain ? Border.all(color: AppColors.primary, width: 1.5) : null,
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  title: Row(
                    children: [
                      Icon(isMain ? Icons.star : Icons.location_city,
                          color: isMain ? Colors.amber.shade700 : AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(d.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      if (loaded)
                        const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                    ],
                  ),
                  subtitle: Text('${liveVillages?.length ?? d.villages.length} قرية'),
                  children: [
                    if (liveVillages != null)
                      ...liveVillages.map((v) => editingVillageId == v.id
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: editLatCtrl,
                                          decoration: const InputDecoration(labelText: 'Lat', isDense: true),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: editLngCtrl,
                                          decoration: const InputDecoration(labelText: 'Lng', isDense: true),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _saveCoords(d.id, zone, v.id),
                                          child: const Text('حفظ الإحداثيات', style: TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setState(() => editingVillageId = null),
                                        child: const Text('إلغاء', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                              title: Text(v.name, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${v.center.lat.toStringAsFixed(3)}, ${v.center.lng.toStringAsFixed(3)}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    onPressed: () => _startEditCoords(v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    onPressed: () => _removeVillage(d.id, zone, v),
                                  ),
                                ],
                              ),
                            ))
                    else
                      ...d.villages.map((v) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                            title: Text(v.name, style: const TextStyle(fontSize: 13)),
                            trailing: Text('${v.lat.toStringAsFixed(3)}, ${v.lng.toStringAsFixed(3)}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          )),
                    if (loaded) ...[
                      if (addingToDistrictId == d.id)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newVillageCtrl,
                                  decoration: const InputDecoration(
                                      hintText: 'اسم القرية الجديدة', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _addVillage(d.id),
                                child: const Text('إضافة', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => setState(() => addingToDistrictId = d.id),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('إضافة قرية جديدة لهذا المركز', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: seedingDistrictId == d.id ? null : () => _seedDistrict(d),
                          icon: seedingDistrictId == d.id
                              ? const SizedBox(
                                  height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(loaded ? Icons.refresh : Icons.cloud_upload_outlined, size: 16),
                          label: Text(loaded ? 'إعادة تحميل هذا المركز' : 'تحميل هذا المركز'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
