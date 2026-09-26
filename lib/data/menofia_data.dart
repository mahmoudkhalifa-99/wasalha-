// البيانات الجغرافية الكاملة لمحافظة المنوفية - منقولة بالكامل من config/constants.ts
// (MENOFIA_DATA) في النسخة الأصلية، بكل قرى كل المراكز التسعة.

class VillageData {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const VillageData({required this.id, required this.name, required this.lat, required this.lng});
}

class DistrictData {
  final String id;
  final String name;
  final List<VillageData> villages;
  const DistrictData({required this.id, required this.name, required this.villages});
}

const List<DistrictData> menofiaDistricts = [
  DistrictData(id: 'd-ashmoun', name: 'أشمون', villages: [
    VillageData(id: 'ash-city', name: 'مدينة أشمون', lat: 30.2931, lng: 30.9863),
    VillageData(id: 'v-shamma', name: 'شما', lat: 30.3340, lng: 30.9420),
    VillageData(id: 'v-tahway', name: 'طهواي', lat: 30.3420, lng: 30.8350),
    VillageData(id: 'v-samadoun', name: 'سمادون', lat: 30.2858, lng: 30.9636),
    VillageData(id: 'v-santes', name: 'سنتريس', lat: 30.3008, lng: 30.9439),
    VillageData(id: 'v-saqia', name: 'ساقية أبو شعرة', lat: 30.3256, lng: 30.9394),
    VillageData(id: 'v-sabk', name: 'سبك الأحد', lat: 30.3219, lng: 30.9981),
    VillageData(id: 'v-gris', name: 'جريس', lat: 30.3361, lng: 30.9812),
    VillageData(id: 'v-shatanouf', name: 'شطانوف', lat: 30.3297, lng: 30.9268),
    VillageData(id: 'v-darwa', name: 'دروة', lat: 30.2500, lng: 30.9800),
    VillageData(id: 'v-shanshour', name: 'شنشور', lat: 30.2799, lng: 30.9507),
    VillageData(id: 'v-talia', name: 'طليا', lat: 30.2450, lng: 30.9350),
    VillageData(id: 'v-anjab', name: 'الأنجب', lat: 30.3700, lng: 30.9900),
    VillageData(id: 'v-ramla', name: 'رملة الأنجب', lat: 30.3750, lng: 30.9850),
    VillageData(id: 'v-khadra', name: 'الخضرة', lat: 30.3200, lng: 30.9700),
    VillageData(id: 'v-el-kawady', name: 'الكوادي', lat: 30.3800, lng: 31.0000),
    VillageData(id: 'v-monsha-sultan', name: 'منشأة سلطان', lat: 30.3550, lng: 31.0100),
  ]),
  DistrictData(id: 'd-shebin', name: 'شبين الكوم', villages: [
    VillageData(id: 'shebin-city', name: 'مدينة شبين الكوم', lat: 30.5612, lng: 31.0125),
    VillageData(id: 'v-elmay', name: 'الماي', lat: 30.5200, lng: 30.9500),
    VillageData(id: 'v-elbetanoun', name: 'البتانون', lat: 30.6100, lng: 31.0500),
    VillageData(id: 'v-shanawan', name: 'شنوان', lat: 30.5100, lng: 31.0100),
    VillageData(id: 'v-milia', name: 'مليج', lat: 30.6000, lng: 31.0000),
    VillageData(id: 'v-bakhati', name: 'بخاتي', lat: 30.5800, lng: 30.9400),
    VillageData(id: 'v-shobrabas', name: 'شبرا باص', lat: 30.5400, lng: 30.9700),
    VillageData(id: 'v-el-moselha', name: 'المصيلحة', lat: 30.5400, lng: 31.0500),
    VillageData(id: 'v-zowat-el-ghazal', name: 'زاوية الغزال', lat: 30.5700, lng: 31.0300),
    VillageData(id: 'v-meet-khalaf', name: 'ميت خلف', lat: 30.5300, lng: 31.0400),
    VillageData(id: 'v-tobloha', name: 'تبلوها', lat: 30.6300, lng: 31.0200),
  ]),
  DistrictData(id: 'd-menouf', name: 'منوف', villages: [
    VillageData(id: 'menouf-city', name: 'مدينة منوف', lat: 30.4667, lng: 30.9333),
    VillageData(id: 'sers-city', name: 'سرس الليان', lat: 30.4333, lng: 30.9167),
    VillageData(id: 'v-feisha', name: 'فيشا الكبرى', lat: 30.4000, lng: 30.9667),
    VillageData(id: 'v-barahim', name: 'براهيم', lat: 30.4833, lng: 30.9500),
    VillageData(id: 'v-al-haswa', name: 'الحصوة', lat: 30.4500, lng: 30.9000),
    VillageData(id: 'v-zowat-rabein', name: 'زاوية رزين', lat: 30.4100, lng: 30.8800),
    VillageData(id: 'v-barhoum', name: 'برهيم', lat: 30.4800, lng: 30.9400),
    VillageData(id: 'v-tamalay', name: 'تتلا', lat: 30.4900, lng: 30.9100),
    VillageData(id: 'v-sanhour', name: 'سنهور', lat: 30.5100, lng: 30.9200),
    VillageData(id: 'v-deberky', name: 'دبركي', lat: 30.4200, lng: 30.9800),
  ]),
  DistrictData(id: 'd-sadat', name: 'مدينة السادات', villages: [
    VillageData(id: 'sadat-center', name: 'مركز المدينة', lat: 30.3833, lng: 30.5000),
    VillageData(id: 'v-khatatba', name: 'الخطاطبة', lat: 30.3167, lng: 30.8000),
    VillageData(id: 'v-kafr-dawood', name: 'كفر داود', lat: 30.4667, lng: 30.7333),
    VillageData(id: 'v-el-akhmas', name: 'الأخماس', lat: 30.4000, lng: 30.6000),
    VillageData(id: 'v-el-breigat', name: 'البريجات', lat: 30.3500, lng: 30.7500),
    VillageData(id: 'v-el-tahra', name: 'الطاهرة', lat: 30.4200, lng: 30.5500),
  ]),
  DistrictData(id: 'd-bagour', name: 'الباجور', villages: [
    VillageData(id: 'bagour-city', name: 'مدينة الباجور', lat: 30.4333, lng: 31.0333),
    VillageData(id: 'v-meet-afifi', name: 'ميت عفيف', lat: 30.4167, lng: 31.0667),
    VillageData(id: 'v-estra', name: 'أسطرنط', lat: 30.4500, lng: 31.0500),
    VillageData(id: 'v-behalshai', name: 'بهناي', lat: 30.4000, lng: 31.0000),
    VillageData(id: 'v-shonoha', name: 'شنوان (الباجور)', lat: 30.4400, lng: 31.0100),
    VillageData(id: 'v-el-khatatba-bagour', name: 'الخضرة (الباجور)', lat: 30.4600, lng: 31.0400),
    VillageData(id: 'v-meshirf', name: 'مشيرف', lat: 30.4200, lng: 31.0800),
    VillageData(id: 'v-feisha-soghra', name: 'فيشا الصغرى', lat: 30.4100, lng: 31.0200),
  ]),
  DistrictData(id: 'd-quesna', name: 'قويسنا', villages: [
    VillageData(id: 'quesna-city', name: 'مدينة قويسنا', lat: 30.5500, lng: 31.1333),
    VillageData(id: 'v-arab-raml', name: 'عرب الرمل', lat: 30.5167, lng: 31.1500),
    VillageData(id: 'v-meet-berra', name: 'ميت برة', lat: 30.5000, lng: 31.1167),
    VillageData(id: 'v-taha-shobra', name: 'طه شبرا', lat: 30.5833, lng: 31.1500),
    VillageData(id: 'v-ashlim', name: 'أشليم', lat: 30.5300, lng: 31.1800),
    VillageData(id: 'v-el-koramia', name: 'الكرامية', lat: 30.5600, lng: 31.1000),
    VillageData(id: 'v-shobra-qabala', name: 'شبرا قبالة', lat: 30.5400, lng: 31.1400),
    VillageData(id: 'v-meet-sirag', name: 'ميت سراج', lat: 30.5700, lng: 31.1200),
  ]),
  DistrictData(id: 'd-berket', name: 'بركة السبع', villages: [
    VillageData(id: 'berket-city', name: 'مدينة بركة السبع', lat: 30.6333, lng: 31.0833),
    VillageData(id: 'v-horin', name: 'هورين', lat: 30.6167, lng: 31.1167),
    VillageData(id: 'v-abu-mashhour', name: 'أبو مشهور', lat: 30.6667, lng: 31.1000),
    VillageData(id: 'v-toukh-dalaka', name: 'طوخ طنبشا', lat: 30.6000, lng: 31.0667),
    VillageData(id: 'v-el-ghouri', name: 'الغوري', lat: 30.6500, lng: 31.0700),
    VillageData(id: 'v-el-dabia', name: 'الضبعة', lat: 30.6200, lng: 31.1000),
    VillageData(id: 'v-kafr-el-sheikh-shehata', name: 'كفر الشيخ شحاتة', lat: 30.6400, lng: 31.0900),
  ]),
  DistrictData(id: 'd-tala', name: 'تلا', villages: [
    VillageData(id: 'tala-city', name: 'مدينة تلا', lat: 30.6833, lng: 30.9500),
    VillageData(id: 'v-babel', name: 'بابل', lat: 30.6500, lng: 30.9333),
    VillageData(id: 'v-kafr-arab', name: 'كفر العرب', lat: 30.7000, lng: 30.9667),
    VillageData(id: 'v-zenara', name: 'زنارة', lat: 30.7167, lng: 30.9167),
    VillageData(id: 'v-shobrakhalaf', name: 'شبرا خلفون', lat: 30.6700, lng: 30.9000),
    VillageData(id: 'v-el-kawady-tala', name: 'الكوادي (تلا)', lat: 30.7300, lng: 30.9400),
    VillageData(id: 'v-meet-abu-el-koum', name: 'ميت أبو الكوم', lat: 30.7500, lng: 30.9200),
  ]),
  DistrictData(id: 'd-shohadaa', name: 'الشهداء', villages: [
    VillageData(id: 'shohadaa-city', name: 'مدينة الشهداء', lat: 30.6000, lng: 30.8167),
    VillageData(id: 'v-zawyat-naura', name: 'زاوية الناعورة', lat: 30.6333, lng: 30.7833),
    VillageData(id: 'v-meet-shahala', name: 'ميت شهالة', lat: 30.5833, lng: 30.8333),
    VillageData(id: 'v-denashwai', name: 'دنشواي', lat: 30.6167, lng: 30.7500),
    VillageData(id: 'v-el-shohada-village', name: 'عزبة الشهداء', lat: 30.5900, lng: 30.8200),
    VillageData(id: 'v-kafr-el-sheikh-mansour', name: 'كفر الشيخ منصور', lat: 30.6200, lng: 30.8000),
    VillageData(id: 'v-el-atf', name: 'العطف', lat: 30.6400, lng: 30.7700),
  ]),
];

/// اسم المركز اللي بتتبعله قرية معينة (بالاسم) - مقابلة لـ getDistrictName
/// المستخدمة في لوحتي المشغّل والسائق بنسخة الويب
String districtNameByVillageName(String? villageName) {
  if (villageName == null || villageName.isEmpty) return 'المنوفية';
  for (final d in menofiaDistricts) {
    if (d.villages.any((v) => v.name == villageName)) return d.name;
  }
  return 'المنوفية';
}
