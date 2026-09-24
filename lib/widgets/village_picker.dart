import 'package:flutter/material.dart';
import '../data/menofia_data.dart';
export '../data/menofia_data.dart';
import '../theme/app_theme.dart';

/// يفتح شاشة اختيار قرية من قرى محافظة المنوفية (مقسّمة حسب المركز)،
/// وبيرجع الاسم + الإحداثيات + كود المركز (zoneId) لو المستخدم اختار.
Future<VillageData?> pickVillage(BuildContext context) {
  return showModalBottomSheet<VillageData>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _VillagePickerSheet(),
  );
}

class _VillagePickerSheet extends StatefulWidget {
  const _VillagePickerSheet();

  @override
  State<_VillagePickerSheet> createState() => _VillagePickerSheetState();
}

class _VillagePickerSheetState extends State<_VillagePickerSheet> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final q = search.trim();
    final filteredDistricts = menofiaDistricts
        .map((d) => MapEntry(
            d,
            q.isEmpty
                ? d.villages
                : d.villages.where((v) => v.name.contains(q)).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر قريتك أو مركزك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                autofocus: false,
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم القرية...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: filteredDistricts.map((entry) {
                    final district = entry.key;
                    final villages = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(district.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                        ...villages.map((v) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                              title: Text(v.name, style: const TextStyle(fontSize: 14)),
                              onTap: () => Navigator.pop(context, v),
                            )),
                        const Divider(height: 18),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// يرجع كود المركز (zoneId) اللي القرية تابعة له
String districtIdOfVillage(String villageId) {
  for (final d in menofiaDistricts) {
    if (d.villages.any((v) => v.id == villageId)) return d.id;
  }
  return '';
}
